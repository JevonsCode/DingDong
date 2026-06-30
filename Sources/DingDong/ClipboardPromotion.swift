import Foundation

struct ClipboardPromotionRequest: Codable, Equatable {
    var targetType: ResourceType?
    var title: String?
    var group: String?
    var tags: [String]?
    var pinned: Bool?

    func makeResource(from clipboardItem: ResourceItem, now: Date = Date()) throws -> ResourceItem {
        let type = targetType ?? .prompt
        guard type != .clipboard else {
            throw ClipboardPromotionError.invalidTargetType
        }

        let promotedTags = Self.uniqueTags((tags ?? clipboardItem.tags) + ["from-clipboard"])
        return ResourceItem(
            type: type,
            group: group,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? clipboardItem.title,
            content: clipboardItem.content,
            tags: promotedTags,
            source: "Clipboard",
            pinned: pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
    }

    private static func uniqueTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { tag in
            let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else {
                return nil
            }
            seen.insert(normalized)
            return normalized
        }
    }
}

enum ClipboardPromotionError: Error {
    case invalidTargetType
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
