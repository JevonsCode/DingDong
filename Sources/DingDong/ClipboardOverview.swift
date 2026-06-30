import Foundation

struct ClipboardOverview: Equatable {
    var total = 0
    var pinned = 0
    var urls = 0
    var commands = 0
    var code = 0
    var json = 0
    var paths = 0
    var email = 0
    var sensitive = 0
    var text = 0
    var groups: [ClipboardBucket] = []
    var topTags: [ClipboardBucket] = []

    init(items: [ResourceItem] = []) {
        let clipboardItems = items.filter { $0.type == .clipboard }
        total = clipboardItems.count
        pinned = clipboardItems.filter(\.pinned).count
        urls = Self.count(clipboardItems, tag: "url")
        commands = Self.count(clipboardItems, tag: "command")
        code = Self.count(clipboardItems, tag: "code")
        json = Self.count(clipboardItems, tag: "json")
        paths = Self.count(clipboardItems, tag: "path")
        email = Self.count(clipboardItems, tag: "email")
        sensitive = Self.count(clipboardItems, tag: "sensitive")
        text = Self.count(clipboardItems, tag: "text")
        groups = Self.buckets(clipboardItems.map(\.group), limit: 8)
        topTags = Self.buckets(clipboardItems.flatMap(\.tags).filter { $0 != "clipboard" }, limit: 12)
    }

    var object: [String: Any] {
        [
            "total": total,
            "pinned": pinned,
            "classificationCounts": [
                "url": urls,
                "command": commands,
                "code": code,
                "json": json,
                "path": paths,
                "email": email,
                "sensitive": sensitive,
                "text": text
            ],
            "groups": groups.map(\.object),
            "topTags": topTags.map(\.object),
            "privacy": [
                "contentIncluded": false,
                "sensitiveContentIncluded": false,
                "note": "Overview returns counts only; use /agent/context with explicit flags for clipboard content."
            ],
            "agentHints": [
                "Use classification counts before deciding whether clipboard context is needed.",
                "Use /library?type=clipboard&q=tag or /agent/context?q=tag&includeClipboard=true for bounded content.",
                "Sensitive clipboard content still requires includeSensitiveClipboard=true."
            ]
        ]
    }

    private static func count(_ items: [ResourceItem], tag: String) -> Int {
        items.filter { $0.tags.contains(tag) }.count
    }

    private static func buckets(_ values: [String], limit: Int) -> [ClipboardBucket] {
        var counts: [String: Int] = [:]
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }
            counts[trimmed, default: 0] += 1
        }

        return counts
            .map { ClipboardBucket(name: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count {
                    return lhs.count > rhs.count
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct ClipboardBucket: Equatable {
    var name: String
    var count: Int

    var object: [String: Any] {
        [
            "name": name,
            "count": count
        ]
    }
}
