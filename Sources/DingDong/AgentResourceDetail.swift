import Foundation

struct AgentResourceDetail {
    static func object(item: ResourceItem, clipboardVisibility: AgentClipboardVisibility) -> [String: Any] {
        let contentIncluded = item.type != .clipboard || clipboardVisibility.allows(item)

        return [
            "status": "ok",
            "service": "DingDong",
            "generatedAt": timestamp(Date()),
            "purpose": "Direct shared resource lookup for local AI agents",
            "privacy": privacyObject(item: item, clipboardVisibility: clipboardVisibility, contentIncluded: contentIncluded),
            "agentHints": agentHints(item: item, contentIncluded: contentIncluded),
            "item": itemObject(item, contentIncluded: contentIncluded)
        ]
    }

    private static func privacyObject(
        item: ResourceItem,
        clipboardVisibility: AgentClipboardVisibility,
        contentIncluded: Bool
    ) -> [String: Any] {
        var object = clipboardVisibility.privacyObject
        object["contentIncluded"] = contentIncluded
        object["resourceType"] = item.type.rawValue

        if item.type == .clipboard {
            object["clipboardContentIncluded"] = contentIncluded
            object["sensitive"] = item.isSensitiveClipboard
            object["note"] = contentIncluded
                ? "Clipboard content was included because includeClipboard=true and sensitivity rules allowed it."
                : "Clipboard content is hidden by default; pass includeClipboard=true, and includeSensitiveClipboard=true for sensitive clipboard records."
        } else {
            object["clipboardContentIncluded"] = false
            object["note"] = "Non-clipboard shared resources include content by default."
        }

        return object
    }

    private static func itemObject(_ item: ResourceItem, contentIncluded: Bool) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "tags": item.tags,
            "pinned": item.pinned,
            "contentCharacterCount": item.content.count,
            "createdAt": timestamp(item.createdAt),
            "updatedAt": timestamp(item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        if item.type == .clipboard {
            object["classification"] = clipboardClassification(for: item)
            object["sensitive"] = item.isSensitiveClipboard
        }

        if contentIncluded {
            object["content"] = item.content
        }

        return object
    }

    private static func agentHints(item: ResourceItem, contentIncluded: Bool) -> [String] {
        if item.type == .clipboard {
            if contentIncluded {
                return [
                    "Use clipboard content only for the current user-approved task.",
                    "Prefer promoting durable clipboard material into prompt, skill, MCP, or knowledge resources.",
                    "Call /ding when the task is done, blocked, or needs user attention."
                ]
            }

            return [
                "This clipboard record was found, but its content is hidden.",
                "Use /clipboard/restore/{id} if the user wants it back on the system clipboard.",
                "Pass includeClipboard=true only when the user explicitly wants clipboard-aware work."
            ]
        }

        return [
            "Use pinned resources first when multiple records conflict.",
            "Use /agent/context for a bounded set of related resources.",
            "Call /ding when the task is done, blocked, or needs user attention."
        ]
    }

    private static func clipboardClassification(for item: ResourceItem) -> String {
        for candidate in ["url", "command", "code", "json", "path", "email", "sensitive", "text"] where item.tags.contains(candidate) {
            return candidate
        }
        return "unknown"
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
