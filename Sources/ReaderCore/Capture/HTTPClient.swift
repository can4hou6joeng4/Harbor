import CoreFoundation
import Foundation

public struct CaptureRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]

    public init(url: URL, method: String = "GET", headers: [String: String] = [:]) {
        self.url = url
        self.method = method
        self.headers = headers
    }
}

public struct CaptureResponse: Sendable {
    public var url: URL
    public var statusCode: Int
    public var mimeType: String?
    public var textEncodingName: String?
    public var suggestedFilename: String?
    public var headers: [String: String]
    public var data: Data

    public init(
        url: URL,
        statusCode: Int = 200,
        mimeType: String? = nil,
        textEncodingName: String? = nil,
        suggestedFilename: String? = nil,
        headers: [String: String] = [:],
        data: Data
    ) {
        self.url = url
        self.statusCode = statusCode
        self.mimeType = mimeType
        self.textEncodingName = textEncodingName
        self.suggestedFilename = suggestedFilename
        self.headers = headers
        self.data = data
    }

    public func header(_ name: String) -> String? {
        headers[name.lowercased()]
    }

    public func decodedText() throws -> String {
        if
            let textEncodingName,
            let encoding = String.Encoding(ianaCharsetName: textEncodingName),
            let text = String(data: data, encoding: encoding)
        {
            return text
        }

        if
            let charset = Self.metaCharset(in: data),
            let encoding = String.Encoding(ianaCharsetName: charset),
            let text = String(data: data, encoding: encoding)
        {
            return text
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        throw HTTPClientError.decodingFailed
    }

    private static func metaCharset(in data: Data) -> String? {
        let prefix = data.prefix(4096)
        let text = String(decoding: prefix, as: UTF8.self)
        let patterns = [
            #"<meta[^>]+charset\s*=\s*["']?\s*([^"'\s>/;]+)"#,
            #"<meta[^>]+content\s*=\s*["'][^"']*charset\s*=\s*([^"'\s;]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                let matchRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }
            return String(text[matchRange])
        }
        return nil
    }
}

public protocol HTTPClient: Sendable {
    func fetch(_ request: CaptureRequest) async throws -> CaptureResponse
}

public enum HTTPClientError: LocalizedError, Sendable {
    case unsupportedResponse
    case badStatus(Int)
    case bodyTooLarge(limit: Int)
    case decodingFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .unsupportedResponse:
            return "服务器返回了无法识别的响应"
        case let .badStatus(statusCode):
            return "服务器返回 HTTP \(statusCode)"
        case let .bodyTooLarge(limit):
            return "响应体超过 \(limit / 1_048_576)MB 上限"
        case .decodingFailed:
            return "无法识别网页编码"
        case .timeout:
            return "请求超时"
        }
    }
}

public final class URLSessionHTTPClient: NSObject, HTTPClient, URLSessionTaskDelegate, @unchecked Sendable {
    private let timeout: TimeInterval
    private let maxBodySize: Int
    private let maxRedirects: Int
    private let redirectLock = NSLock()
    private var redirectCounts: [Int: Int] = [:]

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    public init(timeout: TimeInterval = 15, maxBodySize: Int = 5 * 1024 * 1024, maxRedirects: Int = 5) {
        self.timeout = timeout
        self.maxBodySize = maxBodySize
        self.maxRedirects = maxRedirects
        super.init()
    }

    public func fetch(_ request: CaptureRequest) async throws -> CaptureResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.setValue("ReaderMacApp/1.0 (Macintosh; macOS)", forHTTPHeaderField: "User-Agent")
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw HTTPClientError.timeout
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.unsupportedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) || httpResponse.statusCode == 304 else {
            throw HTTPClientError.badStatus(httpResponse.statusCode)
        }
        guard data.count <= maxBodySize else {
            throw HTTPClientError.bodyTooLarge(limit: maxBodySize)
        }

        return CaptureResponse(
            url: httpResponse.url ?? request.url,
            statusCode: httpResponse.statusCode,
            mimeType: httpResponse.mimeType,
            textEncodingName: httpResponse.textEncodingName,
            suggestedFilename: httpResponse.suggestedFilename,
            headers: Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                guard let key = key as? String else { return nil }
                return (key.lowercased(), "\(value)")
            }),
            data: data
        )
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        redirectLock.lock()
        let nextCount = redirectCounts[task.taskIdentifier, default: 0] + 1
        redirectCounts[task.taskIdentifier] = nextCount
        redirectLock.unlock()

        completionHandler(nextCount <= maxRedirects ? request : nil)
    }
}

private extension String.Encoding {
    init?(ianaCharsetName: String) {
        let encoding = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        guard encoding != kCFStringEncodingInvalidId else { return nil }
        self = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(encoding))
    }
}
