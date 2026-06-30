import Foundation
import Testing
@testable import DingDong

struct ClipboardPromotionTests {
    @Test func promotionCreatesPromptFromClipboardByDefault() throws {
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Commands",
            title: "Command: curl -sS",
            content: "curl -sS http://127.0.0.1:8765/health",
            tags: ["clipboard", "command", "curl"]
        )

        let promoted = try ClipboardPromotionRequest().makeResource(from: clipboard, now: Date(timeIntervalSince1970: 10))

        #expect(promoted.type == .prompt)
        #expect(promoted.group == "Prompts")
        #expect(promoted.title == clipboard.title)
        #expect(promoted.content == clipboard.content)
        #expect(promoted.tags == ["clipboard", "command", "curl", "from-clipboard"])
        #expect(promoted.source == "Clipboard")
        #expect(promoted.createdAt == Date(timeIntervalSince1970: 10))
    }

    @Test func promotionRejectsClipboardTarget() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Clip", content: "Body")

        #expect(throws: ClipboardPromotionError.invalidTargetType) {
            try ClipboardPromotionRequest(targetType: .clipboard).makeResource(from: clipboard)
        }
    }
}
