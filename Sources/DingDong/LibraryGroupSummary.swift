import Foundation

struct LibraryGroupSummary: Equatable {
    var type: ResourceType
    var group: String
    var count: Int
    var pinnedCount: Int
    var latestUpdatedAt: Date

    var filterID: String {
        "\(type.rawValue):\(group)"
    }

    static func summaries(from items: [ResourceItem]) -> [LibraryGroupSummary] {
        var buckets: [GroupKey: [ResourceItem]] = [:]

        for item in items {
            buckets[GroupKey(type: item.type, group: item.group), default: []].append(item)
        }

        return buckets.map { key, groupItems in
            LibraryGroupSummary(
                type: key.type,
                group: key.group,
                count: groupItems.count,
                pinnedCount: groupItems.filter(\.pinned).count,
                latestUpdatedAt: groupItems.map(\.updatedAt).max() ?? Date(timeIntervalSince1970: 0)
            )
        }
        .sorted { lhs, rhs in
            let lhsIndex = ResourceType.allCases.firstIndex(of: lhs.type) ?? .max
            let rhsIndex = ResourceType.allCases.firstIndex(of: rhs.type) ?? .max

            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }

            if lhs.pinnedCount != rhs.pinnedCount {
                return lhs.pinnedCount > rhs.pinnedCount
            }

            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }

            if lhs.latestUpdatedAt != rhs.latestUpdatedAt {
                return lhs.latestUpdatedAt > rhs.latestUpdatedAt
            }

            return lhs.group.localizedCaseInsensitiveCompare(rhs.group) == .orderedAscending
        }
    }
}

private struct GroupKey: Hashable {
    var type: ResourceType
    var group: String
}
