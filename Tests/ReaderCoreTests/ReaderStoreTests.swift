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
}
