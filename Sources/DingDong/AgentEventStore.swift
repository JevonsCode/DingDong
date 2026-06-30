import Foundation

struct AgentEvent: Equatable, Identifiable {
    var id: UUID
    var message: String
    var source: String
    var sound: DingSound
    var createdAt: Date

    init(id: UUID = UUID(), request: DingRequest, createdAt: Date = Date()) {
        self.id = id
        self.message = request.message
        self.source = request.source ?? "Agent"
        self.sound = request.sound
        self.createdAt = createdAt
    }
}

final class AgentEventStore: @unchecked Sendable {
    static let maxEvents = 50

    private let queue = DispatchQueue(label: "dingdong.agent-events")
    private var events: [AgentEvent] = []

    @discardableResult
    func record(_ request: DingRequest, createdAt: Date = Date()) -> AgentEvent {
        queue.sync {
            let event = AgentEvent(request: request, createdAt: createdAt)
            events.insert(event, at: 0)
            if events.count > Self.maxEvents {
                events = Array(events.prefix(Self.maxEvents))
            }
            return event
        }
    }

    func list(limit: Int? = nil) -> [AgentEvent] {
        queue.sync {
            let cappedLimit = limit.map { max(0, min($0, Self.maxEvents)) }
            return cappedLimit.map { Array(events.prefix($0)) } ?? events
        }
    }
}
