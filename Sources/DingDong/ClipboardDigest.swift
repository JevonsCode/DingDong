import Foundation

struct ClipboardDigest {
    static let defaultLimit = 8
    static let maxLimit = 30
    static let excerptLimit = 420

    static func object(
        items: [ResourceItem],
        task: String,
        requestedLimit: Int?,
        includeContent: Bool,
        includeSensitiveClipboard: Bool
    ) -> [String: Any] {
        let limit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let clipboardItems = items.filter { $0.type == .clipboard }
        let matches = matchingItems(clipboardItems, task: task)
        let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : matches.filter(\.isSensitiveClipboard).count
        let visibleItems = includeSensitiveClipboard ? matches : matches.filter { !$0.isSensitiveClipboard }
        let returnedItems = Array(visibleItems.prefix(limit))

        return [
            "status": "ok",
            "service": "DingDong",
            "generatedAt": timestamp(Date()),
            "purpose": "Task-scoped clipboard digest for local AI agents, with content hidden by default.",
            "task": task,
            "privacy": [
                "contentIncluded": includeContent,
                "sensitiveClipboardIncluded": includeSensitiveClipboard,
                "hiddenSensitiveItems": hiddenSensitiveCount,
                "default": "clipboard digest returns metadata only unless includeContent=true",
                "sensitiveDefault": "sensitive clipboard records are hidden unless includeSensitiveClipboard=true"
            ],
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItemsMax": limit,
                "maxItems": maxLimit,
                "contentExcerptCharacters": excerptLimit
            ],
            "counts": [
                "totalClipboard": clipboardItems.count,
                "matched": matches.count,
                "visible": visibleItems.count,
                "returned": returnedItems.count,
                "hiddenSensitive": hiddenSensitiveCount
            ],
            "byGroup": groupSummaries(visibleItems),
            "byClassification": classificationCounts(visibleItems),
            "candidates": returnedItems.map { candidateObject($0, includeContent: includeContent) },
            "agentActions": agentActions(for: returnedItems, task: task)
        ]
    }

    private static func matchingItems(_ items: [ResourceItem], task: String) -> [ResourceItem] {
        let tokens = searchTokens(task)
        guard !tokens.isEmpty else {
            return items
        }

        return items.filter { item in
            let haystack = ([item.title, item.group, item.content] + item.tags)
                .joined(separator: " ")
                .lowercased()
            return tokens.contains { haystack.contains($0) }
        }
    }

    private static func candidateObject(_ item: ResourceItem, includeContent: Bool) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "title": item.title,
            "group": item.group,
            "classification": classification(for: item),
            "tags": item.tags,
            "aliases": aliases(for: item),
            "pinned": item.pinned,
            "sensitive": item.isSensitiveClipboard,
            "contentCharacterCount": item.content.count,
            "updatedAt": timestamp(item.updatedAt),
            "suggestedActions": suggestedActions(for: item)
        ]

        if let source = item.source {
            object["source"] = source
        }

        if includeContent {
            object["contentExcerpt"] = excerpt(item.content)
            object["content"] = item.content
        }

        return object
    }

    private static func groupSummaries(_ items: [ResourceItem]) -> [[String: Any]] {
        let grouped = Dictionary(grouping: items, by: \.group)
        return grouped
            .map { group, items in
                [
                    "group": group,
                    "count": items.count,
                    "pinned": items.filter(\.pinned).count,
                    "classifications": classificationCounts(items)
                ] as [String: Any]
            }
            .sorted { lhs, rhs in
                let lhsCount = lhs["count"] as? Int ?? 0
                let rhsCount = rhs["count"] as? Int ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return (lhs["group"] as? String ?? "") < (rhs["group"] as? String ?? "")
            }
    }

    private static func classificationCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[classification(for: item), default: 0] += 1
        }
        return counts
    }

    private static func agentActions(for items: [ResourceItem], task: String) -> [String] {
        var actions: [String] = [
            "GET /clipboard/history?q=\(encoded(task))&limit=20",
            "GET /clipboard/groups"
        ]

        for item in items.prefix(5) {
            if isPromoteCandidate(item) {
                actions.append("POST /clipboard/promote/\(item.id.uuidString)")
            }

            for alias in aliases(for: item) {
                actions.append("POST /clipboard/snippet/\(alias)/restore")
            }

            if item.pinned {
                actions.append("POST /clipboard/restore/\(item.id.uuidString)")
            }
        }

        return unique(actions)
    }

    private static func suggestedActions(for item: ResourceItem) -> [String] {
        var actions = ["PATCH /clipboard/\(item.id.uuidString)"]

        if isPromoteCandidate(item) {
            actions.append("POST /clipboard/promote/\(item.id.uuidString)")
        }

        for alias in aliases(for: item) {
            actions.append("POST /clipboard/snippet/\(alias)/restore")
        }

        if item.pinned {
            actions.append("POST /clipboard/restore/\(item.id.uuidString)")
        }

        return unique(actions)
    }

    private static func isPromoteCandidate(_ item: ResourceItem) -> Bool {
        let usefulTags: Set<String> = ["command", "code", "json", "url", "path", "text"]
        return item.tags.contains { usefulTags.contains($0) }
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

    private static func searchTokens(_ query: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        let tokens = query
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        return Array(NSOrderedSet(array: tokens)) as? [String] ?? []
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    private static func encoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
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
