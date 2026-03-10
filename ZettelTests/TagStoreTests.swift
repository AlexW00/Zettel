import Foundation
import Testing
@testable import Zettel

@MainActor
struct TagStoreTests {
    @Test
    func updateBuildsUsageCountsAndSortedTags() async {
        let store = TagStore()
        let notes = [
            Note(title: "One #Swift", content: "Body #Testing"),
            Note(title: "Two #swift", content: "Body #apple"),
            Note(title: "Three", content: "#swift")
        ]

        store.updateTagsImmediately(from: notes)
        await store.waitForPendingUpdates()

        #expect(store.getUsageCount(for: "swift") == 3)
        #expect(store.getUsageCount(for: "testing") == 1)
        #expect(store.sortedTags.map(\.id) == ["swift", "apple", "testing"])
    }

    @Test
    func autocompleteCanExcludeCurrentlyEditedTag() async {
        let store = TagStore()
        let notes = [
            Note(title: "One", content: "#swift #swiftui #server")
        ]

        store.updateTagsImmediately(from: notes)
        await store.waitForPendingUpdates()

        let text = "working on #swift"
        let range = NSRange(location: 11, length: 6)
        let matches = store.getMatchingTags(for: "sw", excludingCurrentTag: range, fromText: text)

        #expect(matches.map(\.id) == ["swiftui"])
    }

    @Test
    func filteringHelpersSupportAnyAndAllTagQueries() async {
        let store = TagStore()
        let note1 = Note(title: "One #swift", content: "#testing")
        let note2 = Note(title: "Two #swift", content: "#apple")
        let note3 = Note(title: "Three", content: "#apple")
        let notes = [note1, note2, note3]

        store.updateTagsImmediately(from: notes)
        await store.waitForPendingUpdates()

        #expect(store.getNotesWithTag("swift", from: notes).count == 2)
        #expect(store.getNotesWithAnyTag(["testing", "apple"], from: notes).count == 3)
        #expect(store.getNotesWithAllTags(["swift", "apple"], from: notes).map(\.title) == ["Two #swift"])
    }
}
