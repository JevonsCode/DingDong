import Foundation

struct AgentWorkbench {
    static let defaultLimit = 8
    static let maxLimit = 20
    static let excerptLimit = 360

    static func object(
        resources: [ResourceItem],
        activeAgents: [AgentPresenceRecord],
        task: String?,
        requestedLimit: Int?
    ) -> [String: Any] {
        let limit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let cleanedTask = task?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let sessions = resources.filter { $0.group == AgentSessionRequest.group }
        let handoffs = resources.filter { $0.group == AgentHandoffRequest.group }
        let memories = resources.filter { $0.group == AgentMemoryRequest.group }
        let matchingSessions = filtered(sessions, task: cleanedTask)
        let matchingHandoffs = filtered(handoffs, task: cleanedTask)
        let matchingMemories = filtered(memories, task: cleanedTask)
        let activeSessions = matchingSessions.filter { status(from: $0) == "active" }
        let openHandoffs = matchingHandoffs.filter { ["open", "blocked"].contains(status(from: $0)) }
        let relevantMemories = matchingMemories
        let workItems = sorted(activeSessions + openHandoffs)

        return [
            "status": "ok",
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "Lightweight workbench for local AI agents to choose resumable work, context, and next API calls.",
            "task": cleanedTask ?? "",
            "privacy": [
                "clipboardContentIncluded": false,
                "sensitiveClipboardIncluded": false,
                "default": "agent workbench never returns clipboard content; use clipboard insights or digest routes explicitly"
            ],
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItemsMax": limit,
                "maxItems": maxLimit,
                "contentExcerptCharacters": excerptLimit
            ],
            "counts": [
                "sessions": sessions.count,
                "handoffs": handoffs.count,
                "memories": memories.count,
                "activeAgents": activeAgents.count,
                "matchingSessions": matchingSessions.count,
                "matchingHandoffs": matchingHandoffs.count,
                "matchingMemories": matchingMemories.count,
                "workItems": workItems.count
            ],
            "activeAgents": activeAgents.prefix(limit).map(activeAgentObject),
            "workItems": sorted(workItems).prefix(limit).map { workItemObject($0, kind: kind(for: $0)) },
            "activeSessions": sorted(activeSessions).prefix(limit).map { workItemObject($0, kind: "session") },
            "openHandoffs": sorted(openHandoffs).prefix(limit).map { workItemObject($0, kind: "handoff") },
            "relevantMemories": sorted(relevantMemories).prefix(limit).map { workItemObject($0, kind: "memory") },
            "commandIDs": commandIDs,
            "nextActions": nextActions(task: cleanedTask)
        ]
    }

    static var commandIDs: [String] {
        [
            "agent-workbench",
            "agent-presence",
            "list-sessions",
            "update-session",
            "list-handoffs",
            "update-handoff",
            "list-memories",
            "agent-prepare",
            "ding-complete"
        ]
    }

    private static func filtered(_ items: [ResourceItem], task: String?) -> [ResourceItem] {
        guard let task else {
            return sorted(items)
        }

        let tokens = searchTokens(task)
        guard !tokens.isEmpty else {
            return sorted(items)
        }

        return sorted(items.filter { item in
            let haystack = ([item.title, item.group, item.content] + item.tags)
                .joined(separator: " ")
                .lowercased()
            return tokens.contains { haystack.contains($0) }
        })
    }

    private static func sorted(_ items: [ResourceItem]) -> [ResourceItem] {
        items.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    private static func workItemObject(_ item: ResourceItem, kind: String) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "kind": kind,
            "title": item.title,
            "group": item.group,
            "status": status(from: item),
            "tags": item.tags,
            "pinned": item.pinned,
            "contentExcerpt": excerpt(item.content),
            "contentCharacterCount": item.content.count,
            "updatedAt": timestamp(item.updatedAt),
            "nextAction": nextAction(for: item, kind: kind)
        ]

        if kind == "memory" {
            object["memoryKind"] = AgentMemoryRequest.kind(from: item)
        }

        if let source = item.source {
            object["source"] = source
        }

        return object
    }

    private static func activeAgentObject(_ record: AgentPresenceRecord) -> [String: Any] {
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

    private static func kind(for item: ResourceItem) -> String {
        switch item.group {
        case AgentSessionRequest.group:
            "session"
        case AgentHandoffRequest.group:
            "handoff"
        case AgentMemoryRequest.group:
            "memory"
        default:
            "resource"
        }
    }

    private static func status(from item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    private static func nextAction(for item: ResourceItem, kind: String) -> String {
        switch kind {
        case "session":
            "Resume or update with PATCH /agent/session/\(item.id.uuidString)."
        case "handoff":
            "Review and update with PATCH /agent/handoff/\(item.id.uuidString)."
        case "memory":
            "Apply this memory before choosing prompts, tools, or code changes."
        default:
            "Open this resource through /agent/resource/\(item.id.uuidString)."
        }
    }

    private static func nextActions(task: String?) -> [String] {
        let encodedTask = (task ?? "TASK").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "TASK"
        return [
            "Register current work with POST /agent/presence.",
            "Use workItems before creating a new session so agents do not duplicate resumable work.",
            "Use activeSessions for in-progress collaboration and openHandoffs for resumable queued work.",
            "Use relevantMemories as durable preferences or project rules for this task.",
            "Fetch /agent/prepare?task=\(encodedTask)&limit=8 when broader resource recommendations are needed.",
            "Update the selected session or handoff before calling /ding."
        ]
    }

    private static func searchTokens(_ query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = query
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        return Array(NSOrderedSet(array: tokens)) as? [String] ?? []
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
