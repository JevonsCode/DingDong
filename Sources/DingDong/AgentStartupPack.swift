import Foundation

struct AgentStartupPack {
    static let defaultContextLimit = 12
    static let maxContextLimit = 30

    static func object(
        resources: [ResourceItem],
        matchingResources: [ResourceItem],
        events: [AgentEvent],
        activeAgents: [AgentPresenceRecord],
        query: String?,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        requestedLimit: Int?
    ) -> [String: Any] {
        let contextLimit = requestedLimit.map { min(max(0, $0), maxContextLimit) } ?? defaultContextLimit
        let context = AgentContextPack.object(
            resources: matchingResources,
            query: query,
            type: type,
            clipboardVisibility: clipboardVisibility,
            requestedLimit: contextLimit
        )
        let brief = AgentBrief.object(
            resources: resources,
            events: events,
            activeAgents: activeAgents,
            clipboardVisibility: clipboardVisibility
        )

        return [
            "status": "ok",
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "One-call startup pack for local AI agents sharing this Mac companion.",
            "query": query ?? "",
            "type": type?.rawValue ?? "all",
            "privacy": clipboardVisibility.privacyObject,
            "limits": [
                "contextItemsDefault": defaultContextLimit,
                "contextItemsMax": maxContextLimit,
                "requestedContextItems": requestedLimit ?? defaultContextLimit
            ],
            "brief": brief,
            "context": context,
            "commandIDs": [
                "agent-startup",
                "agent-presence",
                "agent-context",
                "recommend-resources",
                "save-bundle",
                "save-handoff",
                "ding-complete"
            ],
            "nextActions": [
                "Register presence with /agent/presence if this pack was fetched manually.",
                "Use context.items before reading full resource content.",
                "Use /library with a resource id or q filter when a full body is needed.",
                "Use /knowledge/index before reading saved local knowledge folders.",
                "Use /agent/bundle to save a reusable bundle of the resources that mattered for this task.",
                "Save reusable findings with /library and resumable state with /agent/handoff.",
                "Call /ding only once for a user-visible task: immediately before the final answer, when the whole task is complete, blocked, or waiting for user attention. Do not call it for intermediate steps or partial subtasks."
            ],
            "copyablePrompt": copyablePrompt(query: query)
        ]
    }

    private static func copyablePrompt(query: String?) -> String {
        let task = query?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            .flatMap { $0.isEmpty ? nil : $0 } ?? "TASK"
        return """
        Start by fetching DingDong's shared local startup pack:
        curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/startup?task=\(task)&limit=12'

        Use the returned brief, context items, and nextActions before choosing prompts, skills, MCP references, knowledge paths, or handoff notes.
        Clipboard content is private by default; request includeClipboard=true only when the user explicitly asks for clipboard-aware work.
        """
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
