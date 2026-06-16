import Foundation

public final class AnthropicService: AIService, @unchecked Sendable {
    public static let oneMillionContextBeta = "context-1m-2025-08-07"

    private let client: any AIClient
    private let keyStore: any APIKeyStoring
    private let settings: AISettings
    private let endpointOverride: URL?
    private let maxRetries: Int
    private let sleeper: @Sendable (TimeInterval) async throws -> Void

    public init(
        client: any AIClient = URLSessionAIClient(),
        keyStore: any APIKeyStoring = APIKeyStore(),
        settings: AISettings = AISettings(),
        endpoint: URL? = nil,
        maxRetries: Int = 3,
        sleeper: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.client = client
        self.keyStore = keyStore
        self.settings = settings
        self.endpointOverride = endpoint
        self.maxRetries = maxRetries
        self.sleeper = sleeper
    }

    public var isConfigured: Bool {
        settings.isEnabled && keyStore.hasAPIKey && currentEndpoint != nil
    }

    public func validateConnection() async throws -> AIConnectionTestResult {
        let model = resolvedModel()
        let request = try authorizedRequest(body: Prompts.connectionTestRequestBody(model: model.value), model: model)
        let startedAt = Date()
        _ = try await sendWithRetry(request)
        return AIConnectionTestResult(model: model.value, elapsedMilliseconds: Self.elapsedMilliseconds(since: startedAt))
    }

    public func summarize(_ item: ReaderItem) async throws -> ReaderSummary {
        let model = resolvedModel()
        let request = try authorizedRequest(body: Prompts.summaryRequestBody(for: item, model: model.value), model: model)
        let response = try await sendWithRetry(request)
        return try Self.decodeSummary(from: response.data)
    }

    public func translate(_ item: ReaderItem, to language: String) async throws -> [String: String] {
        let model = resolvedModel()
        let request = try authorizedRequest(body: Prompts.translationRequestBody(for: item, targetLanguage: language, model: model.value), model: model)
        let response = try await sendWithRetry(request)
        return try Self.decodeTranslations(from: response.data)
    }

    public func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> {
        do {
            let model = resolvedModel()
            let request = try authorizedRequest(body: Prompts.chatRequestBody(messages: messages, item: item, model: model.value), model: model)
            return streamWithRetry(request)
        } catch {
            return failedStream(error)
        }
    }

    public func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error> {
        do {
            let model = resolvedModel()
            let request = try authorizedRequest(body: Prompts.remixRequestBody(type: type, items: items, model: model.value), model: model)
            return streamWithRetry(request)
        } catch {
            return failedStream(error)
        }
    }

    static func decodeSummary(from data: Data) throws -> ReaderSummary {
        let decoder = JSONDecoder()
        if let summary = try? decoder.decode(ReaderSummary.self, from: data) {
            return summary
        }

        let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let summaryData = text.data(using: .utf8) else {
            throw AIError.emptyResponse
        }
        do {
            return try decoder.decode(ReaderSummary.self, from: summaryData)
        } catch {
            throw AIError.decodingFailed
        }
    }

    static func decodeTranslations(from data: Data) throws -> [String: String] {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(TranslationPayload.self, from: data) {
            return payload.dictionary
        }

        let response = try decoder.decode(AnthropicMessageResponse.self, from: data)
        let text = response.content
            .filter { $0.type == "text" }
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let translationData = text.data(using: .utf8) else {
            throw AIError.emptyResponse
        }
        do {
            return try decoder.decode(TranslationPayload.self, from: translationData).dictionary
        } catch {
            throw AIError.decodingFailed
        }
    }

    static func messagesEndpoint(from baseURL: URL?) -> URL? {
        guard let baseURL else { return nil }
        let absolute = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: absolute) else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("v1/messages") {
            return components.url
        }
        if path.hasSuffix("v1") {
            components.path = "/" + [path, "messages"].filter { !$0.isEmpty }.joined(separator: "/")
        } else {
            components.path = "/" + [path, "v1", "messages"].filter { !$0.isEmpty }.joined(separator: "/")
        }
        return components.url
    }

    static func normalizedModel(_ rawValue: String, additionalBeta: String) -> AnthropicResolvedModel {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = "[1m]"
        let hasOneMillionContext = trimmed.lowercased().hasSuffix(suffix)
        let model = hasOneMillionContext ? String(trimmed.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
        var betaValues = betaList(from: additionalBeta)
        if hasOneMillionContext && !betaValues.contains(oneMillionContextBeta) {
            betaValues.insert(oneMillionContextBeta, at: 0)
        }
        return AnthropicResolvedModel(value: model, betaValues: betaValues)
    }

    private static func betaList(from value: String) -> [String] {
        var seen = Set<String>()
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { beta in
                guard !seen.contains(beta) else { return false }
                seen.insert(beta)
                return true
            }
    }

    private var currentEndpoint: URL? {
        endpointOverride ?? Self.messagesEndpoint(from: settings.configuration(for: .anthropic).baseURL)
    }

    private func resolvedModel() -> AnthropicResolvedModel {
        Self.normalizedModel(settings.anthropicModelString, additionalBeta: settings.anthropicBeta)
    }

    private func authorizedRequest(body: Data, model: AnthropicResolvedModel) throws -> AIHTTPRequest {
        guard settings.isEnabled else {
            throw AIError.notConfigured
        }
        guard let endpoint = currentEndpoint else {
            throw AIError.notConfigured
        }
        guard
            let key = try keyStore.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw AIError.notConfigured
        }

        var headers = [
            "content-type": "application/json",
            "anthropic-version": "2023-06-01"
        ]
        switch settings.anthropicAuthMode {
        case .apiKey:
            headers["x-api-key"] = key
        case .authToken:
            headers["authorization"] = "Bearer \(key)"
        }
        if !model.betaValues.isEmpty {
            headers["anthropic-beta"] = model.betaValues.joined(separator: ",")
        }

        return AIHTTPRequest(url: endpoint, method: "POST", headers: headers, body: body)
    }

    private func sendWithRetry(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        var attempt = 0

        while true {
            let response: AIHTTPResponse
            do {
                response = try await client.send(request)
            } catch is CancellationError {
                throw AIError.cancelled
            } catch let error as AIError {
                guard shouldRetry(error, attempt: attempt) else { throw error }
                try await wait(beforeRetrying: error, attempt: attempt)
                attempt += 1
                continue
            } catch {
                let aiError = AIError.transport(error.localizedDescription)
                guard shouldRetry(aiError, attempt: attempt) else { throw aiError }
                try await wait(beforeRetrying: aiError, attempt: attempt)
                attempt += 1
                continue
            }

            guard (200..<300).contains(response.statusCode) else {
                let aiError = AIError.httpStatus(response.statusCode, retryAfterHeader: response.header("retry-after"), responseData: response.data)
                guard shouldRetry(aiError, attempt: attempt) else { throw aiError }
                try await wait(beforeRetrying: aiError, attempt: attempt)
                attempt += 1
                continue
            }

            return response
        }
    }

    private func shouldRetry(_ error: AIError, attempt: Int) -> Bool {
        error.isRetriable && attempt < maxRetries
    }

    private func wait(beforeRetrying error: AIError, attempt: Int) async throws {
        try Task.checkCancellation()
        try await sleeper(retryDelay(for: error, attempt: attempt))
    }

    private func retryDelay(for error: AIError, attempt: Int) -> TimeInterval {
        if case let .rateLimited(retryAfter) = error, let retryAfter {
            return max(0, retryAfter)
        }
        let base = min(pow(2, Double(attempt)), 8)
        return base + Double.random(in: 0...0.25)
    }

    private func streamWithRetry(_ request: AIHTTPRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var attempt = 0

                while true {
                    var didYield = false
                    do {
                        for try await token in client.stream(request) {
                            didYield = true
                            continuation.yield(token)
                        }
                        continuation.finish()
                        return
                    } catch is CancellationError {
                        continuation.finish(throwing: AIError.cancelled)
                        return
                    } catch let error as AIError {
                        guard !didYield, !Task.isCancelled, shouldRetry(error, attempt: attempt) else {
                            continuation.finish(throwing: error)
                            return
                        }
                        do {
                            try await wait(beforeRetrying: error, attempt: attempt)
                        } catch is CancellationError {
                            continuation.finish(throwing: AIError.cancelled)
                            return
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                        attempt += 1
                    } catch {
                        let aiError = AIError.transport(error.localizedDescription)
                        guard !didYield, !Task.isCancelled, shouldRetry(aiError, attempt: attempt) else {
                            continuation.finish(throwing: aiError)
                            return
                        }
                        do {
                            try await wait(beforeRetrying: aiError, attempt: attempt)
                        } catch is CancellationError {
                            continuation.finish(throwing: AIError.cancelled)
                            return
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                        attempt += 1
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func failedStream(_ error: Error) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }

    private static func elapsedMilliseconds(since startedAt: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
    }
}

private struct AnthropicMessageResponse: Decodable {
    var content: [Content]

    struct Content: Decodable {
        var type: String
        var text: String?
    }
}

public struct AnthropicResolvedModel: Equatable, Sendable {
    public var value: String
    public var betaValues: [String]

    public init(value: String, betaValues: [String]) {
        self.value = value
        self.betaValues = betaValues
    }
}

private struct TranslationPayload: Decodable {
    var translations: [Translation]

    var dictionary: [String: String] {
        translations.reduce(into: [:]) { result, translation in
            result[translation.id] = translation.text
        }
    }

    struct Translation: Decodable {
        var id: String
        var text: String
    }
}
