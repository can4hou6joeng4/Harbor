import Foundation

public enum AIError: Error, Equatable, LocalizedError, Sendable {
    case notConfigured
    case invalidAPIKey
    case forbidden
    case badRequest
    case requestTooLarge
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int)
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
            return "API Key 无效,请在设置中重新填写"
        case .forbidden:
            return "当前 API Key 没有访问权限"
        case .badRequest:
            return "AI 请求格式有误"
        case .requestTooLarge:
            return "正文过长,无法完成本次 AI 处理"
        case .rateLimited:
            return "Anthropic 当前限流,稍后再试"
        case let .serverError(statusCode):
            return "Anthropic 服务暂时不可用(HTTP \(statusCode))"
        case .overloaded:
            return "Anthropic 当前过载,稍后再试"
        case .decodingFailed:
            return "AI 返回格式无法解析"
        case .emptyResponse:
            return "AI 没有返回内容"
        case .invalidResponse:
            return "AI 返回了无法识别的响应"
        case .transport:
            return "AI 网络请求失败"
        case .cancelled:
            return "AI 请求已取消"
        case let .featureUnavailable(message):
            return message
        }
    }

    var isRetriable: Bool {
        switch self {
        case .rateLimited, .serverError, .overloaded, .transport:
            return true
        case .notConfigured, .invalidAPIKey, .forbidden, .badRequest, .requestTooLarge,
             .decodingFailed, .emptyResponse, .invalidResponse, .cancelled, .featureUnavailable:
            return false
        }
    }

    static func httpStatus(_ statusCode: Int, retryAfterHeader: String?) -> AIError {
        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .invalidAPIKey
        case 403:
            return .forbidden
        case 413:
            return .requestTooLarge
        case 429:
            return .rateLimited(retryAfter: retryAfterHeader.flatMap(TimeInterval.init))
        case 529:
            return .overloaded
        case 500..<600:
            return .serverError(statusCode: statusCode)
        default:
            return .serverError(statusCode: statusCode)
        }
    }
}
