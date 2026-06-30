import Foundation

struct AgentResourceResolve {
    static func object(
        resources: [ResourceItem],
        query: String,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility
    ) -> [String: Any]? {
        let visibleResources = resources.filter(clipboardVisibility.allows)
        let typedResources = type.map { selectedType in
            visibleResources.filter { $0.type == selectedType }
        } ?? visibleResources

        guard let match = typedResources
            .compactMap({ scoredResource($0, query: query) })
            .sorted(by: sortMatches)
            .first else {
            return nil
        }

        var object = AgentResourceDetail.object(item: match.item, clipboardVisibility: clipboardVisibility)
        object["purpose"] = "Resolved best matching shared resource for a local AI agent task"
        object["query"] = query
        object["type"] = type?.rawValue ?? "all"
        object["resolution"] = [
            "matched": true,
            "score": match.score,
            "reasons": match.reasons,
            "searchedResources": typedResources.count,
            "nextAction": nextAction(for: match.item)
        ]
        return object
    }

    private static func scoredResource(_ item: ResourceItem, query: String) -> ScoredAgentResource? {
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

        return ScoredAgentResource(item: item, score: score, reasons: uniqueReasons(reasons))
    }

    private static func sortMatches(_ lhs: ScoredAgentResource, _ rhs: ScoredAgentResource) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        if lhs.item.pinned != rhs.item.pinned {
            return lhs.item.pinned && !rhs.item.pinned
        }

        return lhs.item.updatedAt > rhs.item.updatedAt
    }

    private static func nextAction(for item: ResourceItem) -> String {
        switch item.type {
        case .prompt:
            "Use the returned prompt content as task guidance."
        case .skill:
            "Open or reference this skill resource before acting."
        case .mcp:
            "Use this MCP reference when a matching server or tool is needed."
        case .knowledge:
            "Call /knowledge/index?id=\(item.id.uuidString) before reading the saved directory."
        case .clipboard:
            "Use clipboard content only when the user explicitly asked for clipboard-aware work."
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
}

private struct ScoredAgentResource {
    var item: ResourceItem
    var score: Int
    var reasons: [String]
}
