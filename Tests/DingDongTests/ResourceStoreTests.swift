import Foundation
import Testing
@testable import DingDong

struct ResourceStoreTests {
    @Test func itemUsesDefaultGroupForType() {
        let item = ResourceItem(type: .prompt, title: "T", content: "C")

        #expect(item.group == "Prompts")
    }

    @Test func defaultClipboardRetentionKeepsThousandItemsForThreeMonths() {
        let defaultsName = "dingdong-resource-retention-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsName)!
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let policy = ResourceStore.clipboardRetentionPolicy(defaults: defaults)

        #expect(policy.maxItems == 1000)
        #expect(policy.maxAgeDays == 90)
    }

    @Test func jsonStorePersistsAndFiltersResources() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-resource-tests-\(UUID().uuidString)", isDirectory: true)
        let store = ResourceStore(fileURL: directory.appendingPathComponent("library.json"))
        let prompt = ResourceItem(type: .prompt, title: "Prompt", content: "Use this", tags: [" ai ", ""])
        let mcp = ResourceItem(type: .mcp, title: "Server", content: "npx server", pinned: true)

        try store.add(prompt)
        try store.add(mcp)

        let prompts = try store.list(type: .prompt)
        let all = try store.list()

        #expect(prompts.map(\.title) == ["Prompt"])
        #expect(prompts.first?.tags == ["ai"])
        #expect(all.first?.title == "Server")
    }

    @Test func createRequestBuildsResourceItem() {
        let request = ResourceCreateRequest(
            type: .skill,
            group: nil,
            title: "  Skill repo  ",
            content: "https://example.com/skills.git",
            tags: ["repo"],
            source: "Codex",
            pinned: true
        )

        let item = request.makeItem(now: Date(timeIntervalSince1970: 10))

        #expect(item.type == .skill)
        #expect(item.group == "Skills")
        #expect(item.title == "Skill repo")
        #expect(item.pinned == true)
        #expect(item.createdAt == Date(timeIntervalSince1970: 10))
    }

    @Test func listSupportsQueryAndLimit() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Review prompt", content: "Check regressions", tags: ["code"]),
            ResourceItem(type: .knowledge, title: "Travel notes", content: "Personal notes", tags: ["docs"]),
            ResourceItem(type: .mcp, title: "Review MCP", content: "Server config", tags: ["tooling"])
        ])

        let results = try store.list(type: nil, query: "review", limit: 1)

        #expect(results.count == 1)
        #expect(results.first?.title.lowercased().contains("review") == true)
    }

    @Test func clipboardRecordsAreCappedToRecentItems() throws {
        let store = InMemoryResourceStore()
        let baseDate = Date().addingTimeInterval(-TimeInterval(ResourceStore.maxClipboardItems + 3))

        for index in 0..<(ResourceStore.maxClipboardItems + 3) {
            try store.add(ResourceItem(
                type: .clipboard,
                title: "Clip \(index)",
                content: "Clipboard content \(index)",
                createdAt: baseDate.addingTimeInterval(TimeInterval(index)),
                updatedAt: baseDate.addingTimeInterval(TimeInterval(index))
            ))
        }

        let clips = try store.list(type: .clipboard, query: nil, limit: nil)

        #expect(clips.count == ResourceStore.maxClipboardItems)
        #expect(clips.first?.title == "Clip \(ResourceStore.maxClipboardItems + 2)")
        #expect(!clips.contains { $0.title == "Clip 0" })
    }

    @Test func clipboardRecordsRespectRetentionDays() throws {
        let store = InMemoryResourceStore(
            clipboardRetentionPolicy: ClipboardRetentionPolicy(maxItems: 200, maxAgeDays: 7)
        )
        let recentDate = Date()
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: recentDate) ?? recentDate

        try store.add(ResourceItem(
            type: .clipboard,
            title: "Old clip",
            content: "Old clipboard content",
            createdAt: oldDate,
            updatedAt: oldDate
        ))
        try store.add(ResourceItem(
            type: .clipboard,
            title: "Recent clip",
            content: "Recent clipboard content",
            createdAt: recentDate,
            updatedAt: recentDate
        ))

        let clips = try store.list(type: .clipboard, query: nil, limit: nil)

        #expect(clips.map(\.title) == ["Recent clip"])
    }

    @Test func setPinnedUpdatesResourceAndSorting() throws {
        let first = ResourceItem(type: .prompt, title: "First", content: "A")
        let second = ResourceItem(type: .prompt, title: "Second", content: "B")
        let store = InMemoryResourceStore(items: [first, second])

        let updated = try store.setPinned(id: first.id, pinned: true)
        let prompts = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(updated?.pinned == true)
        #expect(prompts.first?.id == first.id)
    }

    @Test func updateChangesEditableResourceFields() throws {
        let item = ResourceItem(type: .prompt, title: "Old", content: "Old body", tags: ["old"])
        let store = InMemoryResourceStore(items: [item])

        let updated = try store.update(id: item.id, changes: ResourceUpdateRequest(
            type: .knowledge,
            group: "",
            title: "New",
            content: "New body",
            tags: ["new", " ai "],
            source: "Codex",
            pinned: true
        ))

        #expect(updated?.type == .knowledge)
        #expect(updated?.group == "Knowledge")
        #expect(updated?.title == "New")
        #expect(updated?.content == "New body")
        #expect(updated?.tags == ["new", "ai"])
        #expect(updated?.source == "Codex")
        #expect(updated?.pinned == true)
    }

    @Test func deleteRemovesResourceByID() throws {
        let keep = ResourceItem(type: .knowledge, title: "Keep", content: "A")
        let remove = ResourceItem(type: .knowledge, title: "Remove", content: "B")
        let store = InMemoryResourceStore(items: [keep, remove])

        let didDelete = try store.delete(id: remove.id)
        let knowledge = try store.list(type: .knowledge, query: nil, limit: nil)

        #expect(didDelete == true)
        #expect(knowledge.map(\.id) == [keep.id])
    }

    @Test func missingResourceMutationsReturnNilOrFalse() throws {
        let store = InMemoryResourceStore()

        let updated = try store.setPinned(id: UUID(), pinned: true)
        let deleted = try store.delete(id: UUID())

        #expect(updated == nil)
        #expect(deleted == false)
    }
}
