import Foundation

enum ResourceLimitError: Error, Equatable {
    case contentTooLarge(maxCharacters: Int)
}

enum ResourceLimits {
    static let maxResourceContentCharacters = 100_000
    static let maxClipboardContentCharacters = 20_000

    static func maxContentCharacters(for type: ResourceType) -> Int {
        switch type {
        case .clipboard:
            maxClipboardContentCharacters
        case .prompt, .skill, .mcp, .knowledge:
            maxResourceContentCharacters
        }
    }

    static func validateContent(_ content: String, type: ResourceType) throws {
        let maxCharacters = maxContentCharacters(for: type)
        guard content.count <= maxCharacters else {
            throw ResourceLimitError.contentTooLarge(maxCharacters: maxCharacters)
        }
    }
}
