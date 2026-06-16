import Foundation

public struct AIConnectionTestResult: Equatable, Sendable {
    public var model: String
    public var elapsedMilliseconds: Int

    public init(model: String, elapsedMilliseconds: Int) {
        self.model = model
        self.elapsedMilliseconds = elapsedMilliseconds
    }
}

public protocol AIService: Sendable {
    var isConfigured: Bool { get }

    func validateConnection() async throws -> AIConnectionTestResult
    func summarize(_ item: ReaderItem) async throws -> ReaderSummary
    func translate(_ item: ReaderItem, to language: String) async throws -> [String: String]
    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error>
    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error>
}
