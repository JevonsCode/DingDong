import Foundation

struct AgentContextPack {
    static let defaultLimit = 30
    static let maxLimit = 80
    static let contentExcerptLimit = 1_200

    static func object(
        resources: [ResourceItem],
        query: String?,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        requestedLimit: Int?
    ) -> [String: Any] {
        let appliedLimit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let visibleResources = resources.filter(clipboardVisibility.allows)
        let returnedResources = Array(visibleResources.prefix(appliedLimit))

        return [
            "status": "ok",
            "service": "DingDong",
            "generatedAt": timestamp(Date()),
            "purpose": "Shared local context for AI agents on this Mac",
            "query": query ?? "",
            "type": type?.rawValue ?? "all",
            "privacy": clipboardVisibility.privacyObject,
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItems": returnedResources.count,
                "maxItems": maxLimit,
                "contentExcerptCharacters": contentExcerptLimit
            ],
            "counts": [
                "totalMatching": resources.count,
                "visibleMatching": visibleResources.count,
                "byType": countsByType(visibleResources)
            ],
            "agentHints": [
                "Use pinned resources first.",
                "Use /library with type and q filters when a full resource body is needed.",
                "Use /knowledge/index with a knowledge resource id before reading local project folders.",
                "Call /ding when the task is done, blocked, or needs user attention."
            ],
            "items": returnedResources.map(resourceObject)
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

    private static func countsByType(_ resources: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for type in ResourceType.allCases {
            counts[type.rawValue] = resources.filter { $0.type == type }.count
        }
        return counts
    }

    private static func excerpt(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > contentExcerptLimit else {
            return trimmed
        }

        return String(trimmed.prefix(contentExcerptLimit)) + "\n[truncated]"
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
