import Foundation

struct AgentMemoryRequest: Codable, Equatable {
    var title: String
    var content: String
    var task: String?
    var kind: String?
    var source: String?
    var tags: [String]?
    var pinned: Bool?

    static let group = "Agent Memories"

    func makeResource(now: Date = Date()) throws -> ResourceItem {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, !cleanedContent.isEmpty else {
            throw AgentMemoryError.missingRequiredFields
        }

        let cleanedKind = kind?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "note"
        let cleanedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Agent"
        let cleanedTask = task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        var rawTags = ["memory", "kind:\(Self.slug(cleanedKind))", "source:\(cleanedSource.lowercased())"]
        if let cleanedTask {
            rawTags.append("task:\(Self.slug(cleanedTask))")
        }
        rawTags.append(contentsOf: tags ?? [])
        let memoryTags = Self.uniqueTags(rawTags)

        return ResourceItem(
            type: .knowledge,
            group: Self.group,
            title: cleanedTitle,
            content: markdown(title: cleanedTitle, content: cleanedContent, kind: cleanedKind, source: cleanedSource, task: cleanedTask),
            tags: memoryTags,
            source: cleanedSource,
            pinned: pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
    }

    static func slug(_ value: String) -> String {
        let separators = CharacterSet.alphanumerics.inverted
        return value
            .lowercased()
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    static func kind(from item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("kind:") }?
            .dropFirst("kind:".count)
            .description
            .nilIfEmpty ?? "note"
    }

    private func markdown(title: String, content: String, kind: String, source: String, task: String?) -> String {
        var lines = [
            "# \(title)",
            "",
            "- Kind: \(kind)",
            "- Source: \(source)"
        ]

        if let task {
            lines.append("- Task: \(task)")
        }

        lines.append("")
        lines.append("## Memory")
        lines.append(content)

        return lines.joined(separator: "\n")
    }

    private static func uniqueTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}

enum AgentMemoryError: Error {
    case missingRequiredFields
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
