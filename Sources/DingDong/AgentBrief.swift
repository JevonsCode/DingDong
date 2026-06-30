import Foundation

struct AgentBrief {
    static let pinnedLimit = 12
    static let groupLimit = 18
    static let eventLimit = 6
    static let excerptLimit = 280

    static func object(
        resources: [ResourceItem],
        events: [AgentEvent],
        activeAgents: [AgentPresenceRecord] = [],
        clipboardVisibility: AgentClipboardVisibility
    ) -> [String: Any] {
        let visibleResources = resources.filter(clipboardVisibility.allows)
        let pinnedResources = visibleResources.filter(\.pinned).prefix(pinnedLimit)
        let groups = LibraryGroupSummary.summaries(from: visibleResources).prefix(groupLimit)
        let recentEvents = events.prefix(eventLimit)

        return [
            "status": "ok",
            "service": "DingDong",
            "generatedAt": timestamp(Date()),
            "purpose": "Fast startup brief for local AI agents using this Mac companion",
            "privacy": clipboardVisibility.privacyObject,
            "counts": [
                "resources": resources.count,
                "visibleResources": visibleResources.count,
                "byType": countsByType(resources)
            ],
            "groups": groups.map(groupObject),
            "pinned": pinnedResources.map(resourceObject),
            "activeAgents": activeAgents.map(agentPresenceObject),
            "recentAgentEvents": recentEvents.map(eventObject),
            "templateIDs": AgentCommandTemplate.defaults.map(\.id),
            "suggestedFlow": [
                "Call /library/groups to choose a resource area.",
                "Call /agent/context with q/type filters for relevant excerpts.",
                "Call /library with a selected id, type, or q when full content is needed.",
                "Call /knowledge/index before reading a saved local knowledge directory.",
                "Call /agent/handoff when work should be resumed by another local agent.",
                "Call /ding when work is complete, blocked, or needs user attention."
            ]
        ]
    }

    private static func resourceObject(_ item: ResourceItem) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "tags": item.tags,
            "pinned": item.pinned,
            "contentExcerpt": excerpt(item.content),
            "contentCharacterCount": item.content.count,
            "updatedAt": timestamp(item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        return object
    }

    private static func groupObject(_ summary: LibraryGroupSummary) -> [String: Any] {
        [
            "type": summary.type.rawValue,
            "group": summary.group,
            "count": summary.count,
            "pinnedCount": summary.pinnedCount,
            "latestUpdatedAt": timestamp(summary.latestUpdatedAt)
        ]
    }

    private static func eventObject(_ event: AgentEvent) -> [String: Any] {
        [
            "id": event.id.uuidString,
            "message": event.message,
            "source": event.source,
            "sound": event.sound.rawValue,
            "createdAt": timestamp(event.createdAt)
        ]
    }

    private static func agentPresenceObject(_ record: AgentPresenceRecord) -> [String: Any] {
        var object: [String: Any] = [
            "source": record.source,
            "status": record.status,
            "capabilities": record.capabilities,
            "updatedAt": timestamp(record.updatedAt)
        ]

        if let task = record.task {
            object["task"] = task
        }

        return object
    }

    private static func countsByType(_ resources: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for type in ResourceType.allCases {
            counts[type.rawValue] = resources.filter { $0.type == type }.count
        }
        return counts
    }

    private static func excerpt(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > excerptLimit else {
            return trimmed
        }

        return String(trimmed.prefix(excerptLimit)) + "\n[truncated]"
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
