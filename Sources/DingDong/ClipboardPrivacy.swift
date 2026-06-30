import Foundation

extension ResourceItem {
    var isSensitiveClipboard: Bool {
        type == .clipboard && tags.contains("sensitive")
    }
}

struct AgentClipboardVisibility {
    var includeClipboard: Bool
    var includeSensitiveClipboard: Bool

    func allows(_ item: ResourceItem) -> Bool {
        guard item.type == .clipboard else {
            return true
        }

        guard includeClipboard else {
            return false
        }

        return includeSensitiveClipboard || !item.isSensitiveClipboard
    }

    var privacyObject: [String: Any] {
        [
            "clipboardIncluded": includeClipboard,
            "sensitiveClipboardIncluded": includeSensitiveClipboard,
            "clipboardDefault": "clipboard resources are excluded unless includeClipboard=true",
            "sensitiveClipboardDefault": "sensitive clipboard records are excluded unless includeSensitiveClipboard=true"
        ]
    }
}
