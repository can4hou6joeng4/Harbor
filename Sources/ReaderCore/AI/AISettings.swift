import Foundation

public enum AIProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case anthropic
    case openAI
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .anthropic:
            return "Anthropic"
        case .openAI:
            return "OpenAI"
        case .custom:
            return "自定义"
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .anthropic:
            return "输入 Anthropic API Key"
        case .openAI:
            return "输入 OpenAI API Key"
        case .custom:
            return "输入自定义 Provider API Key"
        }
    }
}

public enum AnthropicModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case opus = "claude-opus-4-8"
    case sonnet = "claude-sonnet-4-6"
    case haiku = "claude-haiku-4-5"
    case fable = "claude-fable-5"

    public static let `default`: AnthropicModel = .opus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .opus:
            return "Opus 4.8"
        case .sonnet:
            return "Sonnet 4.6"
        case .haiku:
            return "Haiku 4.5"
        case .fable:
            return "Fable 5"
        }
    }

    public var costHint: String {
        switch self {
        case .opus:
            return "默认质量"
        case .sonnet:
            return "更快更省"
        case .haiku:
            return "最省"
        case .fable:
            return "最强"
        }
    }
}

public enum OpenAIModel: String, CaseIterable, Codable, Identifiable, Sendable {
    case gpt41 = "gpt-4.1"
    case gpt41Mini = "gpt-4.1-mini"
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"

    public static let `default`: OpenAIModel = .gpt41Mini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gpt41:
            return "GPT-4.1"
        case .gpt41Mini:
            return "GPT-4.1 mini"
        case .gpt4o:
            return "GPT-4o"
        case .gpt4oMini:
            return "GPT-4o mini"
        }
    }

    public var costHint: String {
        switch self {
        case .gpt41:
            return "高质量"
        case .gpt41Mini:
            return "默认均衡"
        case .gpt4o:
            return "多模态旗舰"
        case .gpt4oMini:
            return "更快更省"
        }
    }
}

public enum AnthropicAuthMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case apiKey
    case authToken

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .apiKey:
            return "API Key"
        case .authToken:
            return "Auth Token"
        }
    }
}

public struct AIProviderConfiguration: Equatable, Sendable {
    public var provider: AIProvider
    public var displayName: String
    public var baseURL: URL?
    public var model: String

    public init(provider: AIProvider, displayName: String, baseURL: URL?, model: String) {
        self.provider = provider
        self.displayName = displayName
        self.baseURL = baseURL
        self.model = model
    }
}

public final class AISettings: @unchecked Sendable {
    private enum Key {
        static let isEnabled = "ReaderAI.isEnabled"
        static let selectedProvider = "ReaderAI.selectedProvider"
        static let selectedModel = "ReaderAI.selectedModel"
        static let anthropicBaseURL = "ReaderAI.anthropicBaseURL"
        static let anthropicAuthMode = "ReaderAI.anthropicAuthMode"
        static let anthropicCustomModel = "ReaderAI.anthropicCustomModel"
        static let anthropicBeta = "ReaderAI.anthropicBeta"
        static let selectedOpenAIModel = "ReaderAI.selectedOpenAIModel"
        static let customProviderName = "ReaderAI.customProviderName"
        static let customBaseURL = "ReaderAI.customBaseURL"
        static let customModel = "ReaderAI.customModel"
    }

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public var isEnabled: Bool {
        get {
            withLock {
                userDefaults.object(forKey: Key.isEnabled) as? Bool ?? false
            }
        }
        set {
            withLock {
                userDefaults.set(newValue, forKey: Key.isEnabled)
            }
        }
    }

    public var selectedModel: AnthropicModel {
        get {
            withLock {
                guard
                    let rawValue = userDefaults.string(forKey: Key.selectedModel),
                    let model = AnthropicModel(rawValue: rawValue)
                else {
                    return .default
                }
                return model
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.rawValue, forKey: Key.selectedModel)
            }
        }
    }

    public var anthropicBaseURLString: String {
        get {
            withLock {
                userDefaults.string(forKey: Key.anthropicBaseURL) ?? ""
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.anthropicBaseURL)
            }
        }
    }

    public var anthropicAuthMode: AnthropicAuthMode {
        get {
            withLock {
                guard
                    let rawValue = userDefaults.string(forKey: Key.anthropicAuthMode),
                    let mode = AnthropicAuthMode(rawValue: rawValue)
                else {
                    return .apiKey
                }
                return mode
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.rawValue, forKey: Key.anthropicAuthMode)
            }
        }
    }

    public var anthropicCustomModel: String {
        get {
            withLock {
                userDefaults.string(forKey: Key.anthropicCustomModel) ?? ""
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.anthropicCustomModel)
            }
        }
    }

    public var anthropicBeta: String {
        get {
            withLock {
                userDefaults.string(forKey: Key.anthropicBeta) ?? ""
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.anthropicBeta)
            }
        }
    }

    public var selectedProvider: AIProvider {
        get {
            withLock {
                guard
                    let rawValue = userDefaults.string(forKey: Key.selectedProvider),
                    let provider = AIProvider(rawValue: rawValue)
                else {
                    return .anthropic
                }
                return provider
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.rawValue, forKey: Key.selectedProvider)
            }
        }
    }

    public var selectedOpenAIModel: OpenAIModel {
        get {
            withLock {
                guard
                    let rawValue = userDefaults.string(forKey: Key.selectedOpenAIModel),
                    let model = OpenAIModel(rawValue: rawValue)
                else {
                    return .default
                }
                return model
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.rawValue, forKey: Key.selectedOpenAIModel)
            }
        }
    }

    public var customProviderName: String {
        get {
            withLock {
                let value = userDefaults.string(forKey: Key.customProviderName) ?? ""
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "自定义 Provider" : value
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.customProviderName)
            }
        }
    }

    public var customBaseURLString: String {
        get {
            withLock {
                userDefaults.string(forKey: Key.customBaseURL) ?? ""
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.customBaseURL)
            }
        }
    }

    public var customModel: String {
        get {
            withLock {
                let value = userDefaults.string(forKey: Key.customModel) ?? ""
                return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gpt-4.1-mini" : value
            }
        }
        set {
            withLock {
                userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.customModel)
            }
        }
    }

    public var currentProviderConfiguration: AIProviderConfiguration {
        configuration(for: selectedProvider)
    }

    public func configuration(for provider: AIProvider) -> AIProviderConfiguration {
        switch provider {
        case .anthropic:
            return AIProviderConfiguration(provider: provider, displayName: provider.displayName, baseURL: Self.anthropicBaseURL(from: anthropicBaseURLString), model: anthropicModelString)
        case .openAI:
            return AIProviderConfiguration(provider: provider, displayName: provider.displayName, baseURL: URL(string: "https://api.openai.com"), model: selectedOpenAIModel.rawValue)
        case .custom:
            return AIProviderConfiguration(provider: provider, displayName: customProviderName, baseURL: Self.normalizedBaseURL(from: customBaseURLString), model: customModel)
        }
    }

    public var anthropicModelString: String {
        let trimmed = anthropicCustomModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? selectedModel.rawValue : trimmed
    }

    public static func anthropicBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return URL(string: "https://api.anthropic.com")
        }
        return normalizedBaseURL(from: trimmed)
    }

    public static func normalizedBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host?.isEmpty == false
        else {
            return nil
        }
        return url
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
