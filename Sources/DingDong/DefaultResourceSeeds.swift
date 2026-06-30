import Foundation

struct DefaultResourceSeedResult {
    var inserted: [ResourceItem]
    var skipped: [ResourceItem]

    var object: [String: Any] {
        [
            "inserted": inserted.count,
            "skipped": skipped.count,
            "items": inserted.map(ResourceSeedJSON.object)
        ]
    }
}

enum DefaultResourceSeeds {
    static var items: [ResourceItem] {
        []
    }

    static func missingSeeds(existing: [ResourceItem]) -> [ResourceItem] {
        let existingKeys = Set(existing.map(seedKey))
        return items.filter { !existingKeys.contains(seedKey($0)) }
    }

    static func install(into store: ResourceStoreProtocol, onlyIfEmpty: Bool) throws -> DefaultResourceSeedResult {
        let existing = try store.list(type: nil, query: nil, limit: nil)
        if onlyIfEmpty, !existing.isEmpty {
            return DefaultResourceSeedResult(inserted: [], skipped: items)
        }

        let missing = missingSeeds(existing: existing)
        var inserted: [ResourceItem] = []
        for item in missing {
            inserted.append(try store.add(item))
        }

        let insertedKeys = Set(inserted.map(seedKey))
        let skipped = items.filter { !insertedKeys.contains(seedKey($0)) }
        return DefaultResourceSeedResult(inserted: inserted, skipped: skipped)
    }

    private static func seedKey(_ item: ResourceItem) -> String {
        "\(item.type.rawValue)|\(item.group.lowercased())|\(item.title.lowercased())"
    }
}

private enum ResourceSeedJSON {
    static func object(_ item: ResourceItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "tags": item.tags,
            "pinned": item.pinned
        ]
    }
}
