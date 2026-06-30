import Foundation

struct AgentRecommendation {
    static let defaultLimit = 8
    static let maxLimit = 20
    static let excerptLimit = 520

    static func object(
        resources: [ResourceItem],
        query: String,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        requestedLimit: Int?
    ) -> [String: Any] {
        let appliedLimit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let visibleResources = resources.filter(clipboardVisibility.allows)
        let typedResources = type.map { selectedType in
            visibleResources.filter { $0.type == selectedType }
        } ?? visibleResources
        let matches = typedResources
            .compactMap { scoredResource($0, query: query) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                if lhs.item.pinned != rhs.item.pinned {
                    return lhs.item.pinned && !rhs.item.pinned
                }

                return lhs.item.updatedAt > rhs.item.updatedAt
            }
        let returnedMatches = Array(matches.prefix(appliedLimit))

        return [
            "status": "ok",
            "service": "DingDong",
            "query": query,
            "type": type?.rawValue ?? "all",
            "generatedAt": timestamp(Date()),
            "privacy": clipboardVisibility.privacyObject,
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItems": returnedMatches.count,
                "maxItems": maxLimit,
                "contentExcerptCharacters": excerptLimit
            ],
            "counts": [
                "searchedResources": typedResources.count,
                "matchingResources": matches.count
            ],
            "recommendations": returnedMatches.map(recommendationObject),
            "nextSteps": [
                "Use /library with the returned id or query when full content is needed.",
                "Use /agent/context with q/type filters to fetch a broader bounded context pack.",
                "Use /knowledge/index for recommended knowledge directories before reading local files.",
                "Pin high-value resources so future recommendations rank them higher."
            ]
        ]
    }

    private static func scoredResource(_ item: ResourceItem, query: String) -> ScoredResource? {
        let tokens = searchTokens(query)
        guard !tokens.isEmpty else {
            return nil
        }

        let lowerQuery = query.lowercased()
        let title = item.title.lowercased()
        let group = item.group.lowercased()
        let content = item.content.lowercased()
        let tags = item.tags.map { $0.lowercased() }
        var score = item.pinned ? 5 : 0
        var reasons: [String] = []

        if title.contains(lowerQuery) {
            score += 20
            reasons.append("title phrase")
        }

        if content.contains(lowerQuery) {
            score += 6
            reasons.append("content phrase")
        }

        for token in tokens {
            if title.contains(token) {
                score += 10
                reasons.append("title:\(token)")
            }

            if tags.contains(where: { $0.contains(token) }) {
                score += 8
                reasons.append("tag:\(token)")
            }

            if group.contains(token) {
                score += 5
                reasons.append("group:\(token)")
            }

            if content.contains(token) {
                score += 2
                reasons.append("content:\(token)")
            }
        }

        guard score > (item.pinned ? 5 : 0) else {
            return nil
        }

        return ScoredResource(item: item, score: score, reasons: uniqueReasons(reasons))
    }

    private static func recommendationObject(_ scored: ScoredResource) -> [String: Any] {
        let item = scored.item
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "tags": item.tags,
            "pinned": item.pinned,
            "score": scored.score,
            "reasons": scored.reasons,
            "nextAction": nextAction(for: item),
            "contentExcerpt": excerpt(item.content),
            "contentCharacterCount": item.content.count,
            "updatedAt": timestamp(item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        return object
    }

    private static func nextAction(for item: ResourceItem) -> String {
        switch item.type {
        case .prompt:
            "Use this prompt as task guidance."
        case .skill:
            "Open or reference this skill repository before acting."
        case .mcp:
            "Use this MCP reference when a tool/server is needed."
        case .knowledge:
            "Call /knowledge/index?id=\(item.id.uuidString) before reading the saved directory."
        case .clipboard:
            "Promote or copy this clipboard record only if the user intended it."
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

    private static func uniqueReasons(_ reasons: [String]) -> [String] {
        var seen: Set<String> = []
        return reasons.filter { seen.insert($0).inserted }
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

private struct ScoredResource {
    var item: ResourceItem
    var score: Int
    var reasons: [String]
}
