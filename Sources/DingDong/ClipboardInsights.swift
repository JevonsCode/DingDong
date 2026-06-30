import Foundation

struct ClipboardInsights {
    static let defaultLimit = 8
    static let maxLimit = 20

    static func object(
        items: [ResourceItem],
        requestedLimit: Int?,
        includeSensitiveClipboard: Bool
    ) -> [String: Any] {
        let limit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let clipboardItems = items.filter { $0.type == .clipboard }
        let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : clipboardItems.filter(\.isSensitiveClipboard).count
        let visibleItems = includeSensitiveClipboard ? clipboardItems : clipboardItems.filter { !$0.isSensitiveClipboard }
        let snippetCandidates = visibleItems.filter { !aliases(for: $0).isEmpty }
        let promoteCandidates = visibleItems.filter(isPromoteCandidate)

        return [
            "status": "ok",
            "service": "DingDong",
            "generatedAt": timestamp(Date()),
            "filter": [
                "limit": limit,
                "includeSensitiveClipboard": includeSensitiveClipboard
            ],
            "privacy": [
                "contentIncluded": false,
                "sensitiveClipboardIncluded": includeSensitiveClipboard,
                "hiddenSensitiveItems": hiddenSensitiveCount,
                "default": "clipboard insights return metadata and recommendations only",
                "sensitiveDefault": "sensitive clipboard records are hidden unless includeSensitiveClipboard=true"
            ],
            "overview": ClipboardOverview(items: clipboardItems).object,
            "counts": [
                "total": clipboardItems.count,
                "visible": visibleItems.count,
                "pinned": visibleItems.filter(\.pinned).count,
                "snippetCandidates": snippetCandidates.count,
                "promoteCandidates": promoteCandidates.count
            ],
            "recommendations": recommendations(for: visibleItems, hiddenSensitiveCount: hiddenSensitiveCount),
            "snippetCandidates": snippetCandidates.prefix(limit).map(candidateObject),
            "promoteCandidates": promoteCandidates.prefix(limit).map(candidateObject)
        ]
    }

    private static func isPromoteCandidate(_ item: ResourceItem) -> Bool {
        let usefulTags: Set<String> = ["command", "code", "json", "url", "path", "text"]
        return !item.pinned && item.tags.contains { usefulTags.contains($0) }
    }

    private static func candidateObject(_ item: ResourceItem) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "title": item.title,
            "group": item.group,
            "classification": classification(for: item),
            "tags": item.tags,
            "aliases": aliases(for: item),
            "pinned": item.pinned,
            "contentCharacterCount": item.content.count,
            "updatedAt": timestamp(item.updatedAt),
            "suggestedActions": suggestedActions(for: item)
        ]

        if let source = item.source {
            object["source"] = source
        }

        return object
    }

    private static func recommendations(for items: [ResourceItem], hiddenSensitiveCount: Int) -> [[String: Any]] {
        var output: [[String: Any]] = []
        let commandCount = items.filter { $0.tags.contains("command") }.count
        let urlCount = items.filter { $0.tags.contains("url") }.count
        let codeCount = items.filter { $0.tags.contains("code") }.count
        let aliasCount = items.filter { !aliases(for: $0).isEmpty }.count
        let unpinnedUsefulCount = items.filter(isPromoteCandidate).count

        if commandCount > 0 {
            output.append([
                "id": "alias-frequent-commands",
                "title": "Create aliases for repeat commands",
                "reason": "\(commandCount) command clipboard records can become reusable alias:name snippets.",
                "action": "PATCH /clipboard/{id} with tags including alias:name"
            ])
        }

        if urlCount > 0 {
            output.append([
                "id": "group-research-links",
                "title": "Group research links",
                "reason": "\(urlCount) URL records can be grouped for task research handoff.",
                "action": "PATCH /clipboard/{id} with a project group"
            ])
        }

        if codeCount > 0 || unpinnedUsefulCount > 0 {
            output.append([
                "id": "promote-agent-context",
                "title": "Promote durable agent context",
                "reason": "\(unpinnedUsefulCount) useful clipboard records can become prompts, skills, MCP notes, or knowledge.",
                "action": "POST /clipboard/promote/{id}"
            ])
        }

        if aliasCount > 0 {
            output.append([
                "id": "restore-snippets",
                "title": "Reuse saved snippets",
                "reason": "\(aliasCount) records already have alias:name tags.",
                "action": "POST /clipboard/snippet/{alias}/restore"
            ])
        }

        if hiddenSensitiveCount > 0 {
            output.append([
                "id": "review-sensitive",
                "title": "Review sensitive clipboard records",
                "reason": "\(hiddenSensitiveCount) sensitive records are hidden from this response.",
                "action": "GET /clipboard/history?filter=sensitive with explicit user approval"
            ])
        }

        return output
    }

    private static func suggestedActions(for item: ResourceItem) -> [String] {
        var actions = ["PATCH /clipboard/{id}"]

        if !aliases(for: item).isEmpty {
            actions.append("POST /clipboard/snippet/{alias}/restore")
        }

        if isPromoteCandidate(item) {
            actions.append("POST /clipboard/promote/{id}")
        }

        if item.pinned {
            actions.append("POST /clipboard/restore/{id}")
        }

        return actions
    }

    private static func classification(for item: ResourceItem) -> String {
        for filter in ClipboardSmartFilter.allCases where filter != .all {
            if let tagQuery = filter.tagQuery, item.tags.contains(tagQuery) {
                return filter.rawValue
            }
        }
        return "text"
    }

    private static func aliases(for item: ResourceItem) -> [String] {
        item.tags.compactMap { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("alias:") else {
                return nil
            }
            let alias = String(trimmed.dropFirst("alias:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return alias.isEmpty ? nil : alias
        }
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
