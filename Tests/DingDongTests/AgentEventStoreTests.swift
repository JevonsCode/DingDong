import Foundation
import Testing
@testable import DingDong

struct AgentEventStoreTests {
    @Test func recordsRecentEventsNewestFirst() {
        let store = AgentEventStore()
        store.record(DingRequest(message: "First", source: "A"), createdAt: Date(timeIntervalSince1970: 1))
        store.record(DingRequest(message: "Second", source: "B"), createdAt: Date(timeIntervalSince1970: 2))

        let events = store.list()

        #expect(events.map(\.message) == ["Second", "First"])
        #expect(events.first?.source == "B")
    }

    @Test func capsEventsToMaxCount() {
        let store = AgentEventStore()

        for index in 0..<(AgentEventStore.maxEvents + 3) {
            store.record(DingRequest(message: "Event \(index)", source: "Agent"))
        }

        let events = store.list()

        #expect(events.count == AgentEventStore.maxEvents)
        #expect(!events.contains { $0.message == "Event 0" })
    }
}
