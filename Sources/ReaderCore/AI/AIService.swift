import Foundation

public protocol AIService: Sendable {
    var isConfigured: Bool { get }

    func validateConnection() async throws
    func summarize(_ item: ReaderItem) async throws -> ReaderSummary
    func translate(_ item: ReaderItem, to language: String) async throws -> [String: String]
    func chat(messages: [ChatMessage], about item: ReaderItem?) -> AsyncThrowingStream<String, Error>
    func remix(type: String, items: [ReaderItem]) -> AsyncThrowingStream<String, Error>
}
