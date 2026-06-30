import Foundation
import Testing
@testable import DingDong

struct AgentPresenceStoreTests {
    @Test func upsertsAgentBySource() throws {
        let store = AgentPresenceStore()
        try store.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Review", capabilities: ["code"]), now: Date(timeIntervalSince1970: 1))
        try store.upsert(AgentPresenceRequest(source: "Codex", status: "blocked", task: "Needs input", capabilities: ["tests"]), now: Date(timeIntervalSince1970: 2))

        let records = store.list(activeWithin: nil)

        #expect(records.count == 1)
        #expect(records.first?.source == "Codex")
        #expect(records.first?.status == "blocked")
        #expect(records.first?.task == "Needs input")
        #expect(records.first?.capabilities == ["tests"])
    }

    @Test func listFiltersStaleAgentsAndCapsLimit() throws {
        let store = AgentPresenceStore()
        try store.upsert(AgentPresenceRequest(source: "Old", status: nil, task: nil, capabilities: nil), now: Date(timeIntervalSince1970: 1))
        try store.upsert(AgentPresenceRequest(source: "Fresh", status: nil, task: nil, capabilities: nil), now: Date(timeIntervalSince1970: 20))
        try store.upsert(AgentPresenceRequest(source: "New", status: nil, task: nil, capabilities: nil), now: Date(timeIntervalSince1970: 30))

        let records = store.list(activeWithin: 15, limit: 1, now: Date(timeIntervalSince1970: 31))

        #expect(records.map(\.source) == ["New"])
    }

    @Test func rejectsBlankSource() throws {
        let store = AgentPresenceStore()

        #expect(throws: AgentPresenceError.missingSource) {
            try store.upsert(AgentPresenceRequest(source: " ", status: nil, task: nil, capabilities: nil))
        }
    }
}
