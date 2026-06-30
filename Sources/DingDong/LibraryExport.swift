import Foundation

struct LibraryExport {
    static let schemaVersion = 1
    static let defaultLimit = 200
    static let maxLimit = 500

    static func object(
        resources: [ResourceItem],
        type: ResourceType?,
        query: String?,
        requestedLimit: Int?,
        clipboardVisibility: AgentClipboardVisibility
    ) -> [String: Any] {
        let appliedLimit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let visibleResources = resources.filter(clipboardVisibility.allows)
        let returnedResources = Array(visibleResources.prefix(appliedLimit))
        let hiddenClipboardCount = resources.filter { $0.type == .clipboard && !clipboardVisibility.allows($0) }.count

        return [
            "status": "ok",
            "service": "DingDong",
            "schemaVersion": schemaVersion,
            "generatedAt": timestamp(Date()),
            "filter": [
                "type": type?.rawValue ?? "all",
                "q": query ?? "",
                "limit": appliedLimit
            ],
            "privacy": [
                "clipboardIncluded": clipboardVisibility.includeClipboard,
                "sensitiveClipboardIncluded": clipboardVisibility.includeSensitiveClipboard,
                "hiddenClipboardItems": hiddenClipboardCount,
                "default": "clipboard resources are excluded unless includeClipboard=true",
                "sensitiveDefault": "sensitive clipboard records are excluded unless includeSensitiveClipboard=true"
            ],
            "counts": [
                "matched": resources.count,
                "visible": visibleResources.count,
                "returned": returnedResources.count,
                "byType": countsByType(visibleResources)
            ],
            "limits": [
                "defaultItems": defaultLimit,
                "maxItems": maxLimit,
                "resourceContentCharacters": ResourceLimits.maxResourceContentCharacters,
                "clipboardContentCharacters": ResourceLimits.maxClipboardContentCharacters
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
            "content": item.content,
            "tags": item.tags,
            "pinned": item.pinned,
            "createdAt": timestamp(item.createdAt),
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

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
