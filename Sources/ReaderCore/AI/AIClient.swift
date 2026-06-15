import Foundation

public struct AIHTTPRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: URL, method: String = "POST", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct AIHTTPResponse: Sendable {
    public var statusCode: Int
    public var headers: [String: String]
    public var data: Data

    public init(statusCode: Int, headers: [String: String] = [:], data: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }

    public func header(_ name: String) -> String? {
        headers.first { key, _ in key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

public protocol AIClient: Sendable {
    func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse
    func stream(_ request: AIHTTPRequest) -> AsyncThrowingStream<String, Error>
}

public final class URLSessionAIClient: AIClient, @unchecked Sendable {
    private let session: URLSession

    public init(timeout: TimeInterval = 60) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: AIHTTPRequest) async throws -> AIHTTPResponse {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest(from: request))
        } catch let error as URLError where error.code == .timedOut {
            throw AIError.transport("timeout")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }
        return AIHTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: Self.headers(from: httpResponse),
            data: data
        )
    }

    public func stream(_ request: AIHTTPRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: urlRequest(from: request))
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw AIError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        throw AIError.httpStatus(httpResponse.statusCode, retryAfterHeader: Self.headers(from: httpResponse)["retry-after"])
                    }

                    var parser = AnthropicSSEParser()
                    for try await line in bytes.lines {
                        for text in try parser.consume(line) {
                            continuation.yield(text)
                        }
                    }
                    for text in try parser.finish() {
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func urlRequest(from request: AIHTTPRequest) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        return urlRequest
    }

    private static func headers(from response: HTTPURLResponse) -> [String: String] {
        Dictionary(uniqueKeysWithValues: response.allHeaderFields.compactMap { key, value in
            guard let key = key as? String else { return nil }
            return (key.lowercased(), "\(value)")
        })
    }
}

public struct AnthropicSSEParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []

    public init() {}

    public mutating func consume(_ line: String) throws -> [String] {
        let normalized = line.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try flush()
        }
        if normalized.hasPrefix(":") {
            return []
        }
        if normalized.hasPrefix("event:") {
            eventName = normalized.dropFirst("event:".count).trimmingCharacters(in: .whitespaces)
            return []
        }
        if normalized.hasPrefix("data:") {
            var value = normalized.dropFirst("data:".count)
            if value.first == " " {
                value = value.dropFirst()
            }
            dataLines.append(String(value))
        }
        return []
    }

    public mutating func finish() throws -> [String] {
        try flush()
    }

    private mutating func flush() throws -> [String] {
        defer {
            eventName = nil
            dataLines.removeAll()
        }
        guard !dataLines.isEmpty else { return [] }
        let payload = dataLines.joined(separator: "\n")
        if payload == "[DONE]" {
            return []
        }
        guard let data = payload.data(using: .utf8) else {
            throw AIError.decodingFailed
        }
        let event = try JSONDecoder().decode(AnthropicStreamPayload.self, from: data)
        if event.type == "error" {
            throw AIError.transport(event.error?.message ?? "stream error")
        }
        guard
            (eventName == nil || eventName == "content_block_delta" || event.type == eventName),
            event.type == "content_block_delta",
            event.delta?.type == "text_delta",
            let text = event.delta?.text
        else {
            return []
        }
        return [text]
    }
}

private struct AnthropicStreamPayload: Decodable {
    var type: String
    var delta: Delta?
    var error: StreamError?

    struct Delta: Decodable {
        var type: String?
        var text: String?
    }

    struct StreamError: Decodable {
        var type: String?
        var message: String?
    }
}
