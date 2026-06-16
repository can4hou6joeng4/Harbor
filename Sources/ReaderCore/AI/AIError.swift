import Foundation

public enum AIError: Error, Equatable, LocalizedError, Sendable {
    case notConfigured
    case invalidAPIKey
    case forbidden
    case gatewayRejected
    case badRequest
    case requestTooLarge
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
    case gatewayUnavailable
    case overloaded
    case decodingFailed
    case emptyResponse
    case invalidResponse
    case transport(String)
    case cancelled
    case featureUnavailable(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "请先在设置中连接 AI"
        case .invalidAPIKey:
            return "鉴权失败,请检查 Token / Key"
        case .forbidden:
            return "当前 API Key 没有访问权限"
        case .gatewayRejected:
            return "网关拒绝访问(可能被 Cloudflare 拦截或客户端不被允许)"
        case .badRequest:
            return "AI 请求格式有误"
        case .requestTooLarge:
            return "正文过长,无法完成本次 AI 处理"
        case .rateLimited:
            return "请求过于频繁,请稍后"
        case let .serverError(statusCode):
            return "AI 服务暂时不可用(HTTP \(statusCode))"
        case .gatewayUnavailable:
            return "网关暂不可用,请稍后重试"
        case .overloaded:
            return "AI 服务当前过载,稍后再试"
        case .decodingFailed:
            return "AI 返回格式无法解析"
        case .emptyResponse:
            return "AI 没有返回内容"
        case .invalidResponse:
            return "AI 返回了无法识别的响应"
        case let .transport(message):
            return "无法连接到端点(\(message))"
        case .cancelled:
            return "AI 请求已取消"
        case let .featureUnavailable(message):
            return message
        }
    }

    var isRetriable: Bool {
        switch self {
        case .rateLimited, .serverError, .gatewayUnavailable, .overloaded, .transport:
            return true
        case .notConfigured, .invalidAPIKey, .forbidden, .gatewayRejected, .badRequest, .requestTooLarge,
             .decodingFailed, .emptyResponse, .invalidResponse, .cancelled, .featureUnavailable:
            return false
        }
    }

    static func httpStatus(_ statusCode: Int, retryAfterHeader: String?, responseData: Data = Data()) -> AIError {
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .invalidAPIKey
        case 403:
            if responseLooksLikeCloudflareBlock(responseData) {
                return .gatewayRejected
            }
            return .forbidden
        case 413:
            return .requestTooLarge
        case 429:
            return .rateLimited(retryAfter: retryAfterHeader.flatMap(TimeInterval.init))
        case 503:
            return .gatewayUnavailable
        case 529:
            return .overloaded
        case 500..<600:
            return .serverError(statusCode: statusCode)
        default:
            return .serverError(statusCode: statusCode)
        }
    }

    private static func responseLooksLikeCloudflareBlock(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return text.contains("error code: 1010")
            || text.contains("error code 1010")
            || (text.contains("cloudflare") && (text.contains("<html") || text.contains("just a moment")))
    }
}
