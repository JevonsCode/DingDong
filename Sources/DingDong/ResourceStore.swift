import Foundation

protocol ResourceStoreProtocol {
    func list(type: ResourceType?, query: String?, limit: Int?) throws -> [ResourceItem]
    @discardableResult
    func add(_ item: ResourceItem) throws -> ResourceItem
    @discardableResult
    func update(id: UUID, changes: ResourceUpdateRequest) throws -> ResourceItem?
    @discardableResult
    func setPinned(id: UUID, pinned: Bool) throws -> ResourceItem?
    @discardableResult
    func delete(id: UUID) throws -> Bool
}

final class ResourceStore: ResourceStoreProtocol {
    static let maxClipboardItems = ClipboardRetentionPolicy.defaultMaxItems

    private let fileURL: URL
    private let queue = DispatchQueue(label: "dingdong.resource-store")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = ResourceStore.defaultFileURL()) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func list(type: ResourceType? = nil, query: String? = nil, limit: Int? = nil) throws -> [ResourceItem] {
        try queue.sync {
            let items = try loadItems()
            var filtered = type.map { selectedType in
                items.filter { $0.type == selectedType }
            } ?? items

            if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                let lowercasedQuery = query.lowercased()
                filtered = filtered.filter { item in
                    item.title.lowercased().contains(lowercasedQuery)
                        || item.content.lowercased().contains(lowercasedQuery)
                        || item.group.lowercased().contains(lowercasedQuery)
                        || item.tags.contains { $0.lowercased().contains(lowercasedQuery) }
                }
            }

            let sorted = filtered.sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }
                return lhs.updatedAt > rhs.updatedAt
            }

            return limit.map { Array(sorted.prefix(max(0, $0))) } ?? sorted
        }
    }

    @discardableResult
    func add(_ item: ResourceItem) throws -> ResourceItem {
        try queue.sync {
            var items = try loadItems()
            items.append(item)
            items = Self.trimClipboardItems(items, policy: Self.clipboardRetentionPolicy())
            try saveItems(items)
            return item
        }
    }

    @discardableResult
    func setPinned(id: UUID, pinned: Bool) throws -> ResourceItem? {
        try update(id: id, changes: ResourceUpdateRequest(pinned: pinned))
    }

    @discardableResult
    func update(id: UUID, changes: ResourceUpdateRequest) throws -> ResourceItem? {
        try queue.sync {
            var items = try loadItems()
            guard let index = items.firstIndex(where: { $0.id == id }) else {
                return nil
            }

            items[index] = Self.updatedItem(items[index], changes: changes)
            try saveItems(items)
            return items[index]
        }
    }

    @discardableResult
    func delete(id: UUID) throws -> Bool {
        try queue.sync {
            var items = try loadItems()
            let originalCount = items.count
            items.removeAll { $0.id == id }

            guard items.count != originalCount else {
                return false
            }

            try saveItems(items)
            return true
        }
    }

    static func clipboardRetentionPolicy(defaults: UserDefaults = .standard) -> ClipboardRetentionPolicy {
        let rawMaxItems = defaults.object(forKey: ClipboardRetentionPolicy.maxItemsKey) == nil
            ? nil
            : defaults.integer(forKey: ClipboardRetentionPolicy.maxItemsKey)
        let rawMaxAgeDays = defaults.object(forKey: ClipboardRetentionPolicy.maxAgeDaysKey) == nil
            ? nil
            : defaults.integer(forKey: ClipboardRetentionPolicy.maxAgeDaysKey)
        return ClipboardRetentionPolicy(
            maxItems: rawMaxItems ?? ClipboardRetentionPolicy.defaultMaxItems,
            maxAgeDays: rawMaxAgeDays ?? ClipboardRetentionPolicy.defaultMaxAgeDays
        )
    }

    static func saveClipboardRetentionPolicy(_ policy: ClipboardRetentionPolicy, defaults: UserDefaults = .standard) {
        let sanitized = policy.sanitized()
        defaults.set(sanitized.maxItems, forKey: ClipboardRetentionPolicy.maxItemsKey)
        defaults.set(sanitized.maxAgeDays, forKey: ClipboardRetentionPolicy.maxAgeDaysKey)
    }

    static func trimClipboardItems(
        _ items: [ResourceItem],
        policy: ClipboardRetentionPolicy,
        now: Date = Date()
    ) -> [ResourceItem] {
        let clipboardItems = items
            .filter { $0.type == .clipboard }
            .sorted { $0.updatedAt > $1.updatedAt }

        guard !clipboardItems.isEmpty else {
            return items
        }

        let sanitizedPolicy = policy.sanitized()
        let cutoffDate = sanitizedPolicy.cutoffDate(relativeTo: now)
        let keptIDs = Set(
            clipboardItems
                .filter { $0.updatedAt >= cutoffDate }
                .prefix(sanitizedPolicy.maxItems)
                .map(\.id)
        )
        return items.filter { item in
            item.type != .clipboard || keptIDs.contains(item.id)
        }
    }

    private static func updatedItem(_ item: ResourceItem, changes: ResourceUpdateRequest) -> ResourceItem {
        let type = changes.type ?? item.type
        return ResourceItem(
            id: item.id,
            type: type,
            group: changes.group ?? item.group,
            title: changes.title ?? item.title,
            content: changes.content ?? item.content,
            tags: changes.tags ?? item.tags,
            source: changes.source ?? item.source,
            pinned: changes.pinned ?? item.pinned,
            createdAt: item.createdAt,
            updatedAt: Date()
        )
    }

    private func loadItems() throws -> [ResourceItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            return []
        }

        return try decoder.decode([ResourceItem].self, from: data)
    }

    private func saveItems(_ items: [ResourceItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("DingDong", isDirectory: true)
            .appendingPathComponent("resource-library.json")
    }
}

struct ClipboardRetentionPolicy: Equatable {
    static let defaultMaxItems = 200
    static let minMaxItems = 20
    static let maxMaxItems = 1000
    static let defaultMaxAgeDays = 30
    static let minMaxAgeDays = 1
    static let maxMaxAgeDays = 365
    static let maxItemsKey = "dingdong.clipboard.maxItems"
    static let maxAgeDaysKey = "dingdong.clipboard.maxAgeDays"

    var maxItems: Int
    var maxAgeDays: Int

    func sanitized() -> ClipboardRetentionPolicy {
        ClipboardRetentionPolicy(
            maxItems: Self.clampedMaxItems(maxItems),
            maxAgeDays: Self.clampedMaxAgeDays(maxAgeDays)
        )
    }

    func cutoffDate(relativeTo date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -sanitized().maxAgeDays, to: date) ?? date
    }

    static func clampedMaxItems(_ value: Int) -> Int {
        min(max(value, minMaxItems), maxMaxItems)
    }

    static func clampedMaxAgeDays(_ value: Int) -> Int {
        min(max(value, minMaxAgeDays), maxMaxAgeDays)
    }
}

final class InMemoryResourceStore: ResourceStoreProtocol {
    private var items: [ResourceItem]
    private let clipboardRetentionPolicy: ClipboardRetentionPolicy

    init(
        items: [ResourceItem] = [],
        clipboardRetentionPolicy: ClipboardRetentionPolicy = ClipboardRetentionPolicy(
            maxItems: ClipboardRetentionPolicy.defaultMaxItems,
            maxAgeDays: ClipboardRetentionPolicy.defaultMaxAgeDays
        )
    ) {
        self.clipboardRetentionPolicy = clipboardRetentionPolicy.sanitized()
        self.items = ResourceStore.trimClipboardItems(items, policy: self.clipboardRetentionPolicy)
    }

    func list(type: ResourceType? = nil, query: String? = nil, limit: Int? = nil) throws -> [ResourceItem] {
        var filtered = type.map { selectedType in
            items.filter { $0.type == selectedType }
        } ?? items

        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            filtered = filtered.filter { item in
                item.title.lowercased().contains(lowercasedQuery)
                    || item.content.lowercased().contains(lowercasedQuery)
                    || item.group.lowercased().contains(lowercasedQuery)
                    || item.tags.contains { $0.lowercased().contains(lowercasedQuery) }
            }
        }

        let sorted = filtered.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned {
                return lhs.pinned && !rhs.pinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }

        return limit.map { Array(sorted.prefix(max(0, $0))) } ?? sorted
    }

    @discardableResult
    func add(_ item: ResourceItem) throws -> ResourceItem {
        items.append(item)
        items = trimClipboardItems(items)
        return item
    }

    @discardableResult
    func setPinned(id: UUID, pinned: Bool) throws -> ResourceItem? {
        try update(id: id, changes: ResourceUpdateRequest(pinned: pinned))
    }

    @discardableResult
    func update(id: UUID, changes: ResourceUpdateRequest) throws -> ResourceItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let type = changes.type ?? items[index].type
        items[index] = ResourceItem(
            id: items[index].id,
            type: type,
            group: changes.group ?? items[index].group,
            title: changes.title ?? items[index].title,
            content: changes.content ?? items[index].content,
            tags: changes.tags ?? items[index].tags,
            source: changes.source ?? items[index].source,
            pinned: changes.pinned ?? items[index].pinned,
            createdAt: items[index].createdAt,
            updatedAt: Date()
        )
        return items[index]
    }

    @discardableResult
    func delete(id: UUID) throws -> Bool {
        let originalCount = items.count
        items.removeAll { $0.id == id }
        return items.count != originalCount
    }

    private func trimClipboardItems(_ items: [ResourceItem]) -> [ResourceItem] {
        ResourceStore.trimClipboardItems(items, policy: clipboardRetentionPolicy)
    }
}
