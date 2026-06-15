import Foundation

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

public final class AISettings: @unchecked Sendable {
    private enum Key {
        static let isEnabled = "ReaderAI.isEnabled"
        static let selectedModel = "ReaderAI.selectedModel"
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

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
