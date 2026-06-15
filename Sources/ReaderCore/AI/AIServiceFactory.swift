import Foundation

public protocol AIServiceMaking: Sendable {
    func makeService(
        configuration: AIProviderConfiguration,
        settings: AISettings,
        keyStore: any APIKeyStoring
    ) -> any AIService
}

public struct DefaultAIServiceFactory: AIServiceMaking {
    public init() {}

    public func makeService(
        configuration: AIProviderConfiguration,
        settings: AISettings,
        keyStore: any APIKeyStoring
    ) -> any AIService {
        switch configuration.provider {
        case .anthropic:
            return AnthropicService(keyStore: keyStore, settings: settings)
        case .openAI, .custom:
            return OpenAICompatibleService(configuration: configuration, keyStore: keyStore, settings: settings)
        }
    }
}
