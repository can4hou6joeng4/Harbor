import Foundation

public final class OpenAICompatibleService: AIService, @unchecked Sendable {
    private let client: any AIClient
    private let configuration: AIProviderConfiguration
    private let keyStore: any APIKeyStoring
    private let settings: AISettings
    private let maxRetries: Int
    private let sleeper: @Sendable (TimeInterval) async throws -> Void

    public init(
        client: any AIClient = URLSessionAIClient(),
        configuration: AIProviderConfiguration,
        keyStore: any APIKeyStoring,
        settings: AISettings = AISettings(),
        maxRetries: Int = 3,
        sleeper: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.client = client
        self.configuration = configuration
        self.keyStore = keyStore
        self.settings = settings
        self.maxRetries = maxRetries
        self.sleeper = sleeper
    }

    public var isConfigured: Bool {
        settings.isEnabled && keyStore.hasAPIKey && Self.chatCompletionsEndpoint(from: configuration.baseURL) != nil
    }

    public func validateConnection() async throws {
        let request = try authorizedRequest(body: Prompts.openAIConnectionTestRequestBody(model: configuration.model))
        _ = try await sendWithRetry(request)
    }

    public func summarize(_ item: ReaderItem) async throws -> ReaderSummary {
        let request = try authorizedRequest(body: Prompts.openAISummaryRequestBody(for: item, model: configuration.model))
        let response = try await sendWithRetry(request)
        return try Self.decodeSummary(from: response.data)
    }

    public func translate(_ item: ReaderItem, to language: String) async throws -> [String: String] {
        let request = try authorizedRequest(body: Prompts.openAITranslationRequestBody(for: item, targetLanguage: language, model: configuration.model))
        let response = try await sendWithRetry(request)
        return try Self.decodeTranslations(from: response.data)
    }

    public func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error> {
        do {
            let request = try authorizedRequest(
                body: Prompts.openAIChatRequestBody(messages: messages, item: item, model: configuration.model),
                stream: true
            )
            return streamWithRetry(request)
        } catch {
            return failedStream(error)
        }
    }

    public func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error> {
        do {
            let request = try authorizedRequest(
                body: Prompts.openAIRemixRequestBody(type: type, items: items, model: configuration.model),
                stream: true
            )
            return streamWithRetry(request)
        } catch {
            return failedStream(error)
        }
    }

    static func chatCompletionsEndpoint(from baseURL: URL?) -> URL? {
        guard let baseURL else { return nil }
        let absolute = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: absolute) else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if path.hasSuffix("chat/completions") {
            return components.url
        }
        if path.hasSuffix("v1") {
            components.path = "/" + [path, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/")
        } else {
            components.path = "/" + [path, "v1", "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/")
        }
        return components.url
    }

    static func decodeSummary(from data: Data) throws -> ReaderSummary {
        let decoder = JSONDecoder()
        if let summary = try? decoder.decode(ReaderSummary.self, from: data) {
            return summary
        }
        let text = try decodeMessageContent(from: data)
        guard let summaryData = text.data(using: .utf8) else {
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
        let text = try decodeMessageContent(from: data)
        guard let translationData = text.data(using: .utf8) else {
            throw AIError.emptyResponse
        }
        do {
            return try decoder.decode(TranslationPayload.self, from: translationData).dictionary
        } catch {
            throw AIError.decodingFailed
        }
    }

    private static func decodeMessageContent(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(OpenAIChatCompletionResponse.self, from: data)
        let text = response.choices
            .compactMap(\.message.content)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = stripJSONFence(from: text)
        guard !stripped.isEmpty else {
            throw AIError.emptyResponse
        }
        return stripped
    }

    private static func stripJSONFence(from text: String) -> String {
        var stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.hasPrefix("```") else { return stripped }
        let lines = stripped.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return stripped }
        stripped = lines.dropFirst().joined(separator: "\n")
        if stripped.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("```") {
            var tail = stripped.components(separatedBy: .newlines)
            _ = tail.popLast()
            stripped = tail.joined(separator: "\n")
        }
        return stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func authorizedRequest(body: Data, stream: Bool = false) throws -> AIHTTPRequest {
        guard settings.isEnabled else {
            throw AIError.notConfigured
        }
        guard let endpoint = Self.chatCompletionsEndpoint(from: configuration.baseURL) else {
            throw AIError.notConfigured
        }
        guard
            let key = try keyStore.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty
        else {
            throw AIError.notConfigured
        }

        return AIHTTPRequest(
            url: endpoint,
            method: "POST",
            headers: [
                "content-type": "application/json",
                "authorization": "Bearer \(key)"
            ],
            body: body,
            streamFormat: stream ? .openAICompatible : .anthropic
        )
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
                let aiError = AIError.httpStatus(response.statusCode, retryAfterHeader: response.header("retry-after"))
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
}

private struct OpenAIChatCompletionResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: Message
    }

    struct Message: Decodable {
        var content: String?
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
