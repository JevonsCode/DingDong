import Foundation

struct SystemStatus {
    static func object(
        resources: [ResourceItem],
        recentEvents: [AgentEvent],
        activeAgents: [AgentPresenceRecord],
        clipboardMonitoringEnabled: Bool,
        apiEndpoint: AgentAPIEndpoint = AgentAPIEndpoint()
    ) -> [String: Any] {
        [
            "status": "ok",
            "service": "DingDong",
            "baseURL": apiEndpoint.baseURL,
            "generatedAt": timestamp(Date()),
            "runtime": apiEndpoint.runtimeObject.merging([
                "clipboardMonitoringEnabled": clipboardMonitoringEnabled
            ]) { current, _ in current },
            "counts": [
                "resources": resources.count,
                "pinnedResources": resources.filter(\.pinned).count,
                "recentAgentEvents": recentEvents.count,
                "activeAgents": activeAgents.count,
                "byType": countsByType(resources)
            ],
            "clipboard": ClipboardOverview(items: resources).object,
            "limits": [
                "clipboardHistory": ResourceStore.clipboardRetentionPolicy().maxItems,
                "clipboardRetentionDays": ResourceStore.clipboardRetentionPolicy().maxAgeDays,
                "resourceContentCharacters": ResourceLimits.maxResourceContentCharacters,
                "clipboardContentCharacters": ResourceLimits.maxClipboardContentCharacters,
                "agentEvents": AgentEventStore.maxEvents,
                "activeAgents": AgentPresenceStore.maxAgents,
                "knowledgeIndexFiles": KnowledgeIndexer.defaultMaxFiles,
                "libraryImportItems": LibraryImporter.maxLimit
            ],
            "performance": [
                "status": "lightweight",
                "resourceRead": "single bounded local JSON read",
                "clipboardMonitoring": clipboardMonitoringEnabled ? "enabled low-frequency polling" : "disabled",
                "knowledgeIndexing": "on-demand only",
                "network": "loopback only"
            ],
            "recommendedAgentFlow": [
                "Call /system/status before large imports or knowledge indexing.",
                "Use /agent/startup for one-call task context.",
                "Use /clipboard/history or /clipboard/snippets before requesting clipboard content.",
                "Call /ding only once for a user-visible task: immediately before the final answer, when the whole task is complete, blocked, or waiting for user attention. Do not call it for intermediate steps or partial subtasks."
            ]
        ]
    }

    private static func countsByType(_ resources: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for type in ResourceType.allCases {
            counts[type.rawValue] = resources.filter { $0.type == type }.count
        }
        return counts
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
