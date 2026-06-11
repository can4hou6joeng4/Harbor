import XCTest
@testable import ReaderCore

@MainActor
final class ReaderStoreTests: XCTestCase {
    func testUnreadViewOnlyShowsUnreadItems() {
        let store = ReaderStore()

        store.selectView("unread")

        XCTAssertFalse(store.visibleItems.isEmpty)
        XCTAssertTrue(store.visibleItems.allSatisfy(\.isUnread))
    }

    func testSelectingItemMarksItRead() {
        let store = ReaderStore()
        let unread = store.items.first { $0.isUnread }
        XCTAssertNotNil(unread)

        store.selectItem(unread!.id)

        XCTAssertFalse(store.items.first { $0.id == unread!.id }!.isUnread)
    }

    func testSearchMatchesTagNames() {
        let store = ReaderStore()
        store.selectView("all")
        store.query = "深度长文"

        XCTAssertTrue(store.visibleItems.contains { $0.id == "a1" })
    }

    func testAddingMarkdownItemSelectsNewInboxItem() {
        let store = ReaderStore()

        store.addItem(
            from: AddContentDraft(
                mode: "md",
                title: "测试笔记",
                markdown: "正文",
                tagIDs: ["t-eff"],
                folderID: "fo-life"
            )
        )

        XCTAssertEqual(store.selectedItem?.title, "测试笔记")
        XCTAssertEqual(store.activeViewID, "inbox")
        XCTAssertEqual(store.items.first?.kind, .markdown)
    }

    func testSetProgressClampsToReadableRange() {
        let store = ReaderStore()

        store.setProgress("a1", progress: 1.7)
        XCTAssertEqual(store.items.first { $0.id == "a1" }?.progress, 1)

        store.setProgress("a1", progress: -0.5)
        XCTAssertEqual(store.items.first { $0.id == "a1" }?.progress, 0)
    }

    func testReadingOffsetIsMemoryOnlyAndNonNegative() {
        let store = ReaderStore()

        store.setReadingOffset("a1", offset: 420.5)
        XCTAssertEqual(store.readingOffset(for: "a1"), 420.5)

        store.setReadingOffset("a1", offset: -80)
        XCTAssertEqual(store.readingOffset(for: "a1"), 0)
        XCTAssertEqual(store.readingOffset(for: "missing"), 0)
    }

    func testAddHighlightReplacesExistingQuoteAndStoresNote() {
        let store = ReaderStore()

        store.addHighlight(itemID: "a1", quote: "  An agent is just a loop  ")
        store.addHighlight(itemID: "a1", quote: "An agent is just a loop", note: "循环观点")

        let highlights = store.items.first { $0.id == "a1" }?.highlights ?? []
        let matching = highlights.filter { $0.quote == "An agent is just a loop" }

        XCTAssertEqual(matching.count, 1)
        XCTAssertEqual(matching.first?.note, "循环观点")
    }

    func testSelectionTranslateOpensTranslateTabWithContext() {
        let store = ReaderStore()
        store.aiPanelOpen = false
        store.aiTab = .summary

        store.translateSelection("  Local-first software  ")

        XCTAssertTrue(store.aiPanelOpen)
        XCTAssertEqual(store.aiTab, .translate)
        XCTAssertEqual(store.pendingTranslationText, "Local-first software")
    }

    func testSelectionAskOpensChatWithSelectedText() {
        let store = ReaderStore()
        store.aiPanelOpen = false
        store.aiTab = .summary
        let initialCount = store.chatMessages.count

        store.askAboutSelection("验证机制")

        XCTAssertTrue(store.aiPanelOpen)
        XCTAssertEqual(store.aiTab, .chat)
        XCTAssertEqual(store.chatMessages.count, initialCount + 1)
        XCTAssertEqual(store.chatMessages.last?.role, .user)
        XCTAssertTrue(store.chatMessages.last?.text.contains("验证机制") == true)
    }
}
