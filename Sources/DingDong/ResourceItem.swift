import Foundation

enum ResourceType: String, Codable, CaseIterable, Equatable, Hashable {
    case prompt
    case skill
    case mcp
    case knowledge
    case clipboard

    var defaultGroup: String {
        switch self {
        case .prompt:
            "Prompts"
        case .skill:
            "Skills"
        case .mcp:
            "MCP"
        case .knowledge:
            "Knowledge"
        case .clipboard:
            "Clipboard"
        }
    }
}

struct ResourceItem: Codable, Equatable, Identifiable {
    var id: UUID
    var type: ResourceType
    var group: String
    var title: String
    var content: String
    var tags: [String]
    var source: String?
    var pinned: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        type: ResourceType,
        group: String? = nil,
        title: String,
        content: String,
        tags: [String] = [],
        source: String? = nil,
        pinned: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.group = group?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? type.defaultGroup
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content
        self.tags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.source = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.pinned = pinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ResourceCreateRequest: Codable, Equatable {
    var type: ResourceType
    var group: String?
    var title: String
    var content: String
    var tags: [String]?
    var source: String?
    var pinned: Bool?

    func makeItem(now: Date = Date()) -> ResourceItem {
        ResourceItem(
            type: type,
            group: group,
            title: title,
            content: content,
            tags: tags ?? [],
            source: source,
            pinned: pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
    }
}

struct ResourceUpdateRequest: Codable, Equatable {
    var type: ResourceType? = nil
    var group: String? = nil
    var title: String? = nil
    var content: String? = nil
    var tags: [String]? = nil
    var source: String? = nil
    var pinned: Bool? = nil

    var hasChanges: Bool {
        type != nil
            || group != nil
            || title != nil
            || content != nil
            || tags != nil
            || source != nil
            || pinned != nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
