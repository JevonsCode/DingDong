import Foundation

struct AgentPreparePack {
    static let defaultLimit = 8
    static let maxLimit = 20

    static func object(
        resources: [ResourceItem],
        events: [AgentEvent],
        activeAgents: [AgentPresenceRecord],
        task: String,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        clipboardInsightsIncludeSensitive: Bool,
        clipboardMonitoringEnabled: Bool,
        requestedLimit: Int?
    ) -> [String: Any] {
        let limit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let matchingResources = filtered(resources: resources, query: task, type: type)

        return [
            "status": "ok",
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "One-call preparation pack for local AI agents before starting a task.",
            "task": task,
            "type": type?.rawValue ?? "all",
            "privacy": [
                "clipboardContentIncluded": clipboardVisibility.includeClipboard,
                "sensitiveClipboardContentIncluded": clipboardVisibility.includeSensitiveClipboard,
                "clipboardInsightsSensitiveMetadataIncluded": clipboardInsightsIncludeSensitive,
                "default": "clipboard content is excluded; clipboard insights are metadata-only"
            ],
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItemsMax": limit
            ],
            "statusSummary": SystemStatus.object(
                resources: resources,
                recentEvents: events,
                activeAgents: activeAgents,
                clipboardMonitoringEnabled: clipboardMonitoringEnabled
            ),
            "startup": AgentStartupPack.object(
                resources: resources,
                matchingResources: matchingResources,
                events: events,
                activeAgents: activeAgents,
                query: task,
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: limit
            ),
            "recommendations": AgentRecommendation.object(
                resources: resources,
                query: task,
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: limit
            ),
            "clipboardInsights": ClipboardInsights.object(
                items: resources,
                requestedLimit: limit,
                includeSensitiveClipboard: clipboardInsightsIncludeSensitive
            ),
            "commandIDs": commandIDs,
            "nextActions": nextActions(task: task)
        ]
    }

    static var commandIDs: [String] {
        [
            "agent-prepare",
            "agent-presence",
            "recommend-resources",
            "clipboard-insights",
            "agent-context",
            "save-bundle",
            "save-handoff",
            "ding-complete"
        ]
    }

    private static func filtered(resources: [ResourceItem], query: String, type: ResourceType?) -> [ResourceItem] {
        let tokens = searchTokens(query)
        let typed = type.map { selectedType in resources.filter { $0.type == selectedType } } ?? resources
        guard !tokens.isEmpty else {
            return typed
        }

        return typed.filter { item in
            let haystack = ([item.title, item.group, item.content] + item.tags)
                .joined(separator: " ")
                .lowercased()
            return tokens.contains { haystack.contains($0) }
        }
    }

    private static func nextActions(task: String) -> [String] {
        let encodedTask = task.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? task
        return [
            "POST /agent/presence with the current agent name and task.",
            "Use recommendations.recommendations before reading full resource bodies.",
            "Use clipboardInsights before requesting clipboard content.",
            "Use /agent/context?q=\(encodedTask)&limit=12 for bounded excerpts if more context is needed.",
            "Save durable findings with /agent/bundle or /library.",
            "Leave resumable state with /agent/handoff.",
            "Call /ding when the task is complete, blocked, or needs user attention."
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

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
