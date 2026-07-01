import Foundation
import AppKit
import Testing
@testable import DingDong

@MainActor
struct StatusControllerTests {
    @Test func emptyLibraryStartsWithoutDefaultResources() throws {
        let store = InMemoryResourceStore()
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )
        let resources = try store.list(type: nil, query: nil, limit: nil)

        #expect(resources.isEmpty)
        #expect(controller.resourceOverview.prompts == 0)
        #expect(controller.resourceOverview.skills == 0)
        #expect(controller.resourceOverview.mcp == 0)
        #expect(controller.resourceOverview.knowledge == 0)
    }

    @Test func nonEmptyLibraryDoesNotAutoSeedDefaults() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "User prompt", content: "Keep this")
        ])
        _ = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )
        let resources = try store.list(type: nil, query: nil, limit: nil)

        #expect(resources.map(\.title) == ["User prompt"])
    }

    @Test func apiTriggeredDingsIncrementUnreadCountAndCanClear() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.trigger(DingRequest(message: "API done", source: "Codex", sound: .muted), recordsEvent: false)
        controller.trigger(DingRequest(message: "Needs review", source: "Claude", sound: .muted), recordsEvent: false)

        #expect(controller.unreadDingCount == 2)
        #expect(controller.isFlashing == false)

        controller.clearUnreadDingCount()

        #expect(controller.unreadDingCount == 0)
        #expect(controller.isFlashing == false)
    }

    @Test func manualDingsDoNotIncrementUnreadCount() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.trigger(DingRequest(message: "Manual test", source: "DingDong", sound: .muted), recordsEvent: true)

        #expect(controller.unreadDingCount == 0)
    }

    @Test func openClipboardListSelectsClipboardTabWithoutShowingWindow() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.setActiveTab(.library)
        controller.openClipboardList(activateWindow: false)

        #expect(controller.activeTab == .clipboard)
    }

    @Test func clipboardHotKeyOpensClipboardTabWhenMonitoringIsOff() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.setActiveTab(.library)
        let didOpen = controller.handleClipboardHotKey()

        #expect(didOpen == true)
        #expect(controller.isClipboardMonitoring == false)
        #expect(controller.activeTab == .clipboard)
    }

    @Test func clipboardHotKeyOpensClipboardTabWhenMonitoringIsOn() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.setActiveTab(.library)
        controller.setClipboardMonitoring(true)
        let didOpen = controller.handleClipboardHotKey()
        controller.setClipboardMonitoring(false)

        #expect(didOpen == true)
        #expect(controller.activeTab == .clipboard)
    }

    @Test func clipboardHotKeyStateCanReportConflict() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )

        controller.setClipboardHotKeyState(.failed(-9878))

        #expect(controller.clipboardHotKeyState.displayText(language: .english) == "⌘⇧V unavailable")
        #expect(controller.clipboardHotKeyState.displayText(language: .chinese) == "⌘⇧V 被占用")
        #expect(GlobalHotKeyState.registered.displayText(language: .english) == "⌘⇧V ready")
        #expect(GlobalHotKeyState.registered.displayText(language: .chinese) == "⌘⇧V 就绪")
    }

    @Test func clipboardSmartFilterUsesClassificationTags() {
        let url = ResourceItem(type: .clipboard, title: "URL", content: "https://example.com", tags: ["clipboard", "url"])
        let command = ResourceItem(type: .clipboard, title: "Command", content: "curl -sS", tags: ["clipboard", "command"])
        let sensitive = ResourceItem(type: .clipboard, title: "Secret", content: "token=sk-secret", tags: ["clipboard", "sensitive"])
        let plain = ResourceItem(type: .clipboard, title: "Text", content: "hello", tags: ["clipboard", "text"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [url, command, sensitive, plain]),
            createsStatusItem: false
        )

        controller.setClipboardFilter(.url)
        #expect(controller.clipboardItems.map(\.title) == ["URL"])

        controller.setClipboardFilter(.command)
        #expect(controller.clipboardItems.map(\.title) == ["Command"])

        controller.setClipboardFilter(.sensitive)
        #expect(controller.clipboardItems.map(\.title) == ["Secret"])

        controller.setClipboardFilter(.all)
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["URL", "Command", "Secret", "Text"]))
    }

    @Test func clipboardSmartFilterIncludesImageAndFileCategories() {
        let image = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Image",
            content: "/tmp/reference.png",
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )
        let file = ResourceItem(
            type: .clipboard,
            group: "Files",
            title: "PDF",
            content: "/tmp/reference.pdf",
            tags: ["clipboard", "file", "file-url", "ext:pdf"]
        )
        let plain = ResourceItem(type: .clipboard, title: "Text", content: "hello", tags: ["clipboard", "text"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [image, file, plain]),
            createsStatusItem: false
        )

        controller.setClipboardFilter(.image)
        #expect(controller.clipboardItems.map(\.title) == ["Image"])

        controller.setClipboardFilter(.file)
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["Image", "PDF"]))
    }

    @Test func clipboardGroupFilterUsesClipboardGroups() {
        let url = ResourceItem(type: .clipboard, group: "URLs", title: "URL", content: "https://example.com", tags: ["clipboard", "url"])
        let command = ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -sS", tags: ["clipboard", "command"])
        let deploy = ResourceItem(type: .clipboard, group: "Commands", title: "Deploy", content: "make deploy", tags: ["clipboard", "command"])
        let note = ResourceItem(type: .clipboard, group: "Notes", title: "Note", content: "hello", tags: ["clipboard", "text"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [url, command, deploy, note]),
            createsStatusItem: false
        )

        controller.setClipboardGroup("commands")
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["Command", "Deploy"]))

        controller.setClipboardFilter(.url)
        #expect(controller.clipboardItems.isEmpty)

        controller.setClipboardFilter(.command)
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["Command", "Deploy"]))

        controller.setClipboardGroup(nil)
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["Command", "Deploy"]))

        controller.setClipboardFilter(.all)
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["URL", "Command", "Deploy", "Note"]))
    }

    @Test func defaultClipboardGroupStaysAfterCustomGroupsWhenReordered() {
        let defaultItem = ResourceItem(type: .clipboard, group: "Clipboard", title: "Default", content: "default", tags: ["clipboard", "text"])
        let command = ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -sS", tags: ["clipboard", "command"])
        let image = ResourceItem(type: .clipboard, group: "Images", title: "Image", content: "/tmp/image.png", tags: ["clipboard", "image"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [defaultItem, command, image]),
            createsStatusItem: false
        )

        controller.moveClipboardGroup("Clipboard", before: "Commands")

        #expect(controller.clipboardOverview.groups.map(\.name).last == "Clipboard")
    }

    @Test func clipboardOverviewTracksGlobalClipboardCounts() {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "URLs", title: "URL", content: "https://example.com", tags: ["clipboard", "url"], pinned: true),
            ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -sS", tags: ["clipboard", "command"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Secret", content: "token=sk-secret", tags: ["clipboard", "sensitive"]),
            ResourceItem(type: .prompt, title: "Prompt", content: "Not clipboard")
        ])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )

        controller.setClipboardFilter(.url)

        #expect(controller.clipboardItems.map(\.title) == ["URL"])
        #expect(controller.clipboardOverview.total == 3)
        #expect(controller.clipboardOverview.pinned == 1)
        #expect(controller.clipboardOverview.urls == 1)
        #expect(controller.clipboardOverview.commands == 1)
        #expect(controller.clipboardOverview.sensitive == 1)
    }

    @Test func clipboardCopilotSummarizesAgentUsefulCandidatesAndFocusesThem() {
        let command = ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -sS", tags: ["clipboard", "command"])
        let snippet = ResourceItem(type: .clipboard, group: "Commands", title: "Snippet", content: "make deploy", tags: ["clipboard", "command", "alias:deploy"], pinned: true)
        let sensitive = ResourceItem(type: .clipboard, group: "Secrets", title: "Secret", content: "token=sk-secret", tags: ["clipboard", "sensitive"])
        let unrelated = ResourceItem(type: .prompt, title: "Prompt", content: "Not clipboard")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [command, snippet, sensitive, unrelated]),
            createsStatusItem: false
        )

        #expect(controller.clipboardCopilot.total == 3)
        #expect(controller.clipboardCopilot.usefulCandidates == 1)
        #expect(controller.clipboardCopilot.snippetCandidates == 1)
        #expect(controller.clipboardCopilot.hiddenSensitive == 1)
        #expect(controller.clipboardCopilot.topGroup == "Commands")
        #expect(controller.clipboardCopilot.preferredFilter == .command)

        controller.focusClipboardCopilotCandidates()

        #expect(controller.activeTab == .clipboard)
        #expect(controller.selectedClipboardFilter == .command)
        #expect(controller.selectedClipboardGroup == "Commands")
        #expect(Set(controller.clipboardItems.map(\.title)) == Set(["Command", "Snippet"]))
    }

    @Test func clipboardCopilotCommandsAreCopiedWithoutContentByDefault() {
        let command = ResourceItem(type: .clipboard, group: "Release", title: "Command", content: "make release", tags: ["clipboard", "command"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [command]),
            createsStatusItem: false
        )

        controller.copyClipboardDigestCommand(task: "")
        let digestCommand = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(digestCommand.contains("/clipboard/digest?task=Release"))
        #expect(digestCommand.contains("includeContent=false"))

        controller.copyClipboardInsightsCommand()
        let insightsCommand = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(insightsCommand.contains("/clipboard/insights?limit=8"))
    }

    @Test func clipboardSnippetShortcutsPreferPinnedAliases() {
        let older = Date().addingTimeInterval(-600)
        let newer = Date()
        let unpinnedDeploy = ResourceItem(
            type: .clipboard,
            group: "Commands",
            title: "Recent deploy",
            content: "make deploy",
            tags: ["clipboard", "command", "alias:deploy"],
            updatedAt: newer
        )
        let pinnedDeploy = ResourceItem(
            type: .clipboard,
            group: "Commands",
            title: "Pinned deploy",
            content: "deploy --safe",
            tags: ["clipboard", "command", "alias:deploy"],
            pinned: true,
            updatedAt: older
        )
        let review = ResourceItem(
            type: .clipboard,
            group: "Text",
            title: "Review note",
            content: "review checklist",
            tags: ["clipboard", "text", "alias:Review"],
            updatedAt: newer
        )
        let plain = ResourceItem(type: .clipboard, title: "Plain", content: "hello", tags: ["clipboard", "text"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [unpinnedDeploy, pinnedDeploy, review, plain]),
            createsStatusItem: false
        )

        #expect(controller.clipboardSnippets.map(\.alias) == ["deploy", "review"])
        #expect(controller.clipboardSnippets.first?.item.title == "Pinned deploy")
        #expect(!controller.clipboardSnippets.contains { $0.item.title == "Plain" })
    }

    @Test func promoteClipboardToPromptSwitchesToLibrary() {
        let clipboard = ResourceItem(type: .clipboard, title: "Prompt seed", content: "Use this prompt", tags: ["clipboard", "text"])
        let store = InMemoryResourceStore(items: [clipboard])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )

        controller.promoteClipboardToPrompt(clipboard)

        #expect(controller.activeTab == .library)
        #expect(controller.selectedResourceType == .prompt)
        #expect(controller.searchText == "Prompt seed")
        #expect(controller.resources.map(\.title) == ["Prompt seed"])
    }

    @Test func restoreClipboardItemWritesContentToPasteboard() {
        let clipboard = ResourceItem(type: .clipboard, title: "Saved command", content: "curl -sS http://127.0.0.1:8765/health", tags: ["clipboard", "command"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [clipboard]),
            createsStatusItem: false
        )
        controller.setLanguage(.english)

        controller.restoreClipboardItem(clipboard)

        #expect(NSPasteboard.general.string(forType: .string) == clipboard.content)
        #expect(controller.lastMessage == "Restored Saved command to clipboard")
    }

    @Test func restoreClipboardPathTextDoesNotWriteFileURLToPasteboard() {
        let path = "/Users/temptrip/workspace/backup/backup-code/locale-station/packages/server/src/templates/activityCoupon.art"
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Paths",
            title: "Path: activityCoupon.art",
            content: path,
            tags: ["clipboard", "path"]
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [clipboard]),
            createsStatusItem: false
        )

        controller.restoreClipboardItem(clipboard)

        let urls = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        #expect(NSPasteboard.general.string(forType: .string) == path)
        #expect(urls?.isEmpty ?? true)
    }

    @Test func restoreClipboardImageFileWritesFileURLToPasteboard() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-clipboard-test-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: fileURL)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Image: \(fileURL.lastPathComponent)",
            content: fileURL.path,
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [clipboard]),
            createsStatusItem: false
        )

        controller.restoreClipboardItem(clipboard)

        let urls = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        #expect(urls?.map(\.path) == [fileURL.path])
    }

    @Test func restoreClipboardItemFromQuickActionWritesContentToPasteboard() {
        let clipboard = ResourceItem(type: .clipboard, title: "Clicked note", content: "clicked clipboard detail", tags: ["clipboard", "text"])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [clipboard]),
            createsStatusItem: false
        )

        let didRestore = controller.restoreClipboardItemFromQuickAction(clipboard)

        #expect(didRestore)
        #expect(NSPasteboard.general.string(forType: .string) == clipboard.content)
    }

    @Test func restoreVisibleClipboardItemUsesVisibleShortcutItems() {
        let baseDate = Date()
        let oldest = ResourceItem(
            type: .clipboard,
            title: "Oldest",
            content: "visible first item",
            updatedAt: baseDate.addingTimeInterval(-20)
        )
        let middle = ResourceItem(
            type: .clipboard,
            title: "Middle",
            content: "visible second item",
            updatedAt: baseDate.addingTimeInterval(-10)
        )
        let newest = ResourceItem(
            type: .clipboard,
            title: "Newest",
            content: "absolute first item",
            updatedAt: baseDate
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [oldest, middle, newest]),
            createsStatusItem: false
        )

        controller.openClipboardList(activateWindow: false)
        #expect(controller.clipboardItems.map(\.title) == ["Newest", "Middle", "Oldest"])

        controller.updateVisibleClipboardShortcutItems([oldest, middle])
        let didRestore = controller.restoreVisibleClipboardItem(at: 1)

        #expect(didRestore)
        #expect(NSPasteboard.general.string(forType: .string) == oldest.content)
    }

    @Test func clipboardContextActionsUpdateArchiveAndSaveResources() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Untitled clip", content: "durable clipboard text", tags: ["clipboard", "text"])
        let store = InMemoryResourceStore(items: [clipboard])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )

        controller.updateClipboardTitle(clipboard, title: "Named clip")
        var updatedClipboard = try #require(store.list(type: .clipboard, query: nil, limit: nil).first)
        #expect(updatedClipboard.title == "Named clip")

        controller.archiveClipboardItem(updatedClipboard)
        updatedClipboard = try #require(store.list(type: .clipboard, query: nil, limit: nil).first)
        #expect(updatedClipboard.group == "Archive")
        #expect(updatedClipboard.tags.contains("archived"))

        controller.archiveClipboardItem(updatedClipboard, group: "Project Drafts")
        updatedClipboard = try #require(store.list(type: .clipboard, query: nil, limit: nil).first)
        #expect(updatedClipboard.group == "Project Drafts")
        #expect(updatedClipboard.tags.filter { $0 == "archived" }.count == 1)

        controller.saveClipboardItem(updatedClipboard, as: .knowledge)
        let savedKnowledge = try #require(store.list(type: .knowledge, query: nil, limit: nil).first)
        #expect(savedKnowledge.title == updatedClipboard.title)
        #expect(savedKnowledge.content == updatedClipboard.content)
        #expect(savedKnowledge.tags.contains("from-clipboard"))
    }

    @Test func clipboardArchiveGroupsOnlyIncludeArchivedGroups() {
        let unarchivedCommand = ResourceItem(
            type: .clipboard,
            group: "Commands",
            title: "Command",
            content: "curl -sS",
            tags: ["clipboard", "command"]
        )
        let archivedDraft = ResourceItem(
            type: .clipboard,
            group: "Project Drafts",
            title: "Draft",
            content: "note",
            tags: ["clipboard", "text", "archived"]
        )
        let defaultArchive = ResourceItem(
            type: .clipboard,
            group: "Archive",
            title: "Default",
            content: "old",
            tags: ["clipboard", "text", "archived"]
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [unarchivedCommand, archivedDraft, defaultArchive]),
            createsStatusItem: false
        )

        #expect(controller.clipboardArchiveGroups() == ["Project Drafts"])
    }

    @Test func restoreVisibleClipboardItemUsesCurrentClipboardOrder() {
        let older = ResourceItem(
            type: .clipboard,
            title: "Older",
            content: "older clipboard",
            tags: ["clipboard", "text"],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = ResourceItem(
            type: .clipboard,
            title: "Newer",
            content: "newer clipboard",
            tags: ["clipboard", "text"],
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [older, newer]),
            createsStatusItem: false
        )

        controller.openClipboardList(activateWindow: false)
        let didRestore = controller.restoreVisibleClipboardItem(at: 1)

        #expect(didRestore)
        #expect(NSPasteboard.general.string(forType: .string) == newer.content)
    }

    @Test func restoreVisibleClipboardItemFromShortcutRestoresCurrentClipboardOrder() {
        let older = ResourceItem(
            type: .clipboard,
            title: "Older",
            content: "older shortcut clipboard",
            tags: ["clipboard", "text"],
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = ResourceItem(
            type: .clipboard,
            title: "Newer",
            content: "newer shortcut clipboard",
            tags: ["clipboard", "text"],
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [older, newer]),
            createsStatusItem: false
        )

        controller.openClipboardList(activateWindow: false)
        let didRestore = controller.restoreVisibleClipboardItemFromShortcut(at: 1)

        #expect(didRestore)
        #expect(NSPasteboard.general.string(forType: .string) == newer.content)
    }

    @Test func copyResourceIDWritesUUIDToPasteboard() {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Use this")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [item]),
            createsStatusItem: false
        )
        controller.setLanguage(.english)

        controller.copyResourceID(item)

        #expect(NSPasteboard.general.string(forType: .string) == item.id.uuidString)
        #expect(controller.lastMessage == "Copied Copy ID")
    }

    @Test func addResourceRejectsOversizedContent() throws {
        let store = InMemoryResourceStore()
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )
        controller.setLanguage(.english)
        let oversized = String(repeating: "A", count: ResourceLimits.maxResourceContentCharacters + 1)

        let didSave = controller.addResource(
            type: .prompt,
            title: "Too large",
            content: oversized,
            group: "Prompts",
            tagsText: "",
            pinned: false
        )

        #expect(didSave == false)
        #expect(controller.lastMessage == "Content exceeds \(ResourceLimits.maxResourceContentCharacters) characters")
        #expect(try store.list(type: .prompt, query: "Too large", limit: nil).isEmpty)
    }

    @Test func languagePreferenceUpdatesIdleMessages() throws {
        let suiteName = "dingdong-language-preference-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let appPreferences = AppPreferences(defaults: defaults)

        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            appPreferences: appPreferences,
            createsStatusItem: false
        )

        controller.setLanguage(.chinese)

        #expect(controller.language == .chinese)
        #expect(controller.lastMessage == "等待 Agent 信号")
        #expect(controller.lastTriggerText == "暂无触发")

        controller.setServerState(.running(port: 8765))
        #expect(controller.serverState.displayText(language: controller.language) == "API 正在监听 127.0.0.1:8765")
    }

    @Test func localizedStatusMessagesUseSelectedLanguage() throws {
        let store = InMemoryResourceStore()
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )
        controller.setLanguage(.chinese)
        let countBefore = try store.list(type: .prompt, query: nil, limit: nil).count

        let didSave = controller.addResource(
            type: .prompt,
            title: "",
            content: "",
            group: "Prompts",
            tagsText: "",
            pinned: false
        )

        #expect(didSave == false)
        #expect(controller.lastMessage == "标题和内容必填")
        #expect(try store.list(type: .prompt, query: nil, limit: nil).count == countBefore)
    }

    @Test func resourceOverviewTracksGlobalCompanionCounts() throws {
        let handoff = try AgentHandoffRequest(
            title: "Resume work",
            summary: "Continue the next step.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: true
        ).makeResource()
        let memory = try AgentMemoryRequest(
            title: "Review preference",
            content: "Prefer compact review findings.",
            task: "review",
            kind: "preference",
            source: "Codex",
            tags: nil,
            pinned: false
        ).makeResource()
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Prompt", content: "Use this", pinned: true),
            ResourceItem(type: .clipboard, title: "Clip", content: "Copied text"),
            handoff,
            memory
        ])
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: store,
            createsStatusItem: false
        )

        controller.selectResourceType(.prompt)

        #expect(controller.resources.count == 1)
        #expect(controller.resourceOverview.total == 4)
        #expect(controller.resourceOverview.pinned == 2)
        #expect(controller.resourceOverview.handoffs == 1)
        #expect(controller.resourceOverview.memories == 1)
        #expect(controller.resourceOverview.clipboard == 1)
        #expect(controller.memoryItems.map(\.title) == ["Review preference"])
    }

    @Test func companionReadinessSummarizesLocalAgentCapabilities() throws {
        let handoff = try AgentHandoffRequest(
            title: "Resume work",
            summary: "Continue the next step.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: false
        ).makeResource()
        let memory = try AgentMemoryRequest(
            title: "Review preference",
            content: "Prefer compact review findings.",
            task: "review",
            kind: "preference",
            source: "Codex",
            tags: nil,
            pinned: false
        ).makeResource()
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Working", capabilities: ["code"]))
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [
                ResourceItem(type: .prompt, title: "Prompt", content: "Use this"),
                ResourceItem(type: .skill, title: "Skill", content: "Use this"),
                ResourceItem(type: .mcp, title: "MCP", content: "Use this"),
                ResourceItem(type: .knowledge, title: "Knowledge", content: "Use this"),
                ResourceItem(type: .clipboard, title: "Clip", content: "Copied text"),
                handoff,
                memory
            ]),
            agentPresenceStore: presence,
            createsStatusItem: false
        )

        #expect(controller.companionReadiness.resourceCount == 7)
        #expect(controller.companionReadiness.promptCount == 1)
        #expect(controller.companionReadiness.skillCount == 1)
        #expect(controller.companionReadiness.mcpCount == 1)
        #expect(controller.companionReadiness.knowledgeCount == 3)
        #expect(controller.companionReadiness.memoryCount == 1)
        #expect(controller.companionReadiness.clipboardCount == 1)
        #expect(controller.companionReadiness.openHandoffCount == 1)
        #expect(controller.companionReadiness.activeAgentCount == 1)
        #expect(controller.companionReadiness.score == 100)
        #expect(controller.companionReadiness.state == .ready)
    }

    @Test func companionStartupAndToolkitCommandsCanBeCopied() {
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            createsStatusItem: false
        )
        controller.setLanguage(.english)

        controller.copyAgentStartupCommand(task: "release review")
        let startup = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(startup.contains("/agent/startup?task=release%20review"))
        #expect(controller.lastMessage == "Copied Agent Startup")

        controller.copyAgentToolkitCommand()
        let toolkit = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(toolkit.contains("/agent/toolkit"))
        #expect(controller.lastMessage == "Copied Agent Toolkit")

        controller.copyAgentWorkbenchCommand(task: "release review")
        let workbench = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(workbench.contains("/agent/workbench?task=release%20review"))
        #expect(controller.lastMessage == "Copied Agent Workbench")
    }

    @Test func libraryGroupFilterCombinesWithResourceType() {
        let promptReview = ResourceItem(type: .prompt, group: "Review", title: "Prompt review", content: "Use this")
        let promptWriting = ResourceItem(type: .prompt, group: "Writing", title: "Prompt writing", content: "Use this")
        let skillReview = ResourceItem(type: .skill, group: "Review", title: "Skill review", content: "Use this")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [promptReview, promptWriting, skillReview]),
            createsStatusItem: false
        )

        controller.selectResourceType(.prompt)
        #expect(Set(controller.libraryGroupSummaries.map(\.group)) == Set(["Review", "Writing"]))

        controller.selectResourceGroup("Review")
        #expect(controller.selectedResourceGroup == "Review")
        #expect(controller.resources.map(\.title) == ["Prompt review"])

        controller.selectResourceType(.skill)
        #expect(controller.selectedResourceGroup == nil)
        #expect(controller.resources.map(\.title) == ["Skill review"])
        #expect(Set(controller.libraryGroupSummaries.map(\.group)) == Set(["Review"]))
    }

    @Test func handoffInboxTracksOpenAndBlockedHandoffs() throws {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_600)
        let open = try AgentHandoffRequest(
            title: "Open work",
            summary: "Continue implementation.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: false
        ).makeResource(now: newer)
        let blocked = try AgentHandoffRequest(
            title: "Blocked work",
            summary: "Needs user input.",
            nextSteps: nil,
            blockers: ["Missing account"],
            artifacts: nil,
            source: "Cursor",
            status: "blocked",
            tags: nil,
            pinned: false
        ).makeResource(now: older)
        let done = try AgentHandoffRequest(
            title: "Done work",
            summary: "Already finished.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Claude",
            status: "done",
            tags: nil,
            pinned: false
        ).makeResource(now: newer)
        let unrelated = ResourceItem(type: .knowledge, group: "Knowledge", title: "Handoff word", content: "handoff")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [open, blocked, done, unrelated]),
            createsStatusItem: false
        )

        #expect(controller.handoffInboxStatusCounts["open"] == 1)
        #expect(controller.handoffInboxStatusCounts["blocked"] == 1)
        #expect(controller.handoffInboxStatusCounts["done"] == 1)
        #expect(controller.handoffInboxItems.map(\.title) == ["Blocked work", "Open work"])
        #expect(controller.handoffStatus(for: controller.handoffInboxItems[0]) == "blocked")
    }

    @Test func activeSessionInboxTracksPinnedActiveSessionsAndCanOpenLibrary() throws {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_600)
        let pinned = try AgentSessionRequest(
            task: "Review API",
            title: "Pinned active session",
            summary: "Keep the API route current.",
            currentStep: "Run focused tests",
            nextActions: nil,
            resourceIDs: nil,
            source: "Codex",
            status: "active",
            tags: nil,
            pinned: true
        ).makeResource(now: older)
        let recent = try AgentSessionRequest(
            task: "Review UI",
            title: "Recent active session",
            summary: "Check the Today panel.",
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Claude",
            status: "active",
            tags: nil,
            pinned: false
        ).makeResource(now: newer)
        let done = try AgentSessionRequest(
            task: "Review done",
            title: "Done session",
            summary: "Finished.",
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Cursor",
            status: "done",
            tags: nil,
            pinned: false
        ).makeResource(now: newer)
        let unrelated = ResourceItem(type: .knowledge, group: "Knowledge", title: "Session word", content: "session")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [recent, unrelated, done, pinned]),
            createsStatusItem: false
        )

        #expect(controller.activeSessionItems.map(\.title) == ["Pinned active session", "Recent active session"])
        #expect(controller.sessionStatus(for: controller.activeSessionItems[0]) == "active")

        controller.openSessionLibrary()

        #expect(controller.activeTab == .library)
        #expect(controller.selectedResourceType == .knowledge)
        #expect(controller.selectedResourceGroup == AgentSessionRequest.group)
        #expect(controller.searchText == "session")
        #expect(Set(controller.resources.map(\.title)) == Set(["Pinned active session", "Recent active session", "Done session"]))
    }

    @Test func openHandoffLibrarySelectsKnowledgeHandoffSearch() throws {
        let handoff = try AgentHandoffRequest(
            title: "Resume work",
            summary: "Continue later.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: false
        ).makeResource()
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [handoff]),
            createsStatusItem: false
        )

        controller.openHandoffLibrary()

        #expect(controller.activeTab == .library)
        #expect(controller.selectedResourceType == .knowledge)
        #expect(controller.selectedResourceGroup == AgentHandoffRequest.group)
        #expect(controller.searchText == "handoff")
        #expect(controller.resources.map(\.title) == ["Resume work"])
    }

    @Test func memoryInboxTracksRecentPinnedMemoriesAndCanOpenLibrary() throws {
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_600)
        let pinned = try AgentMemoryRequest(
            title: "Pinned rule",
            content: "Always check current app behavior.",
            task: "testing",
            kind: "rule",
            source: "Codex",
            tags: nil,
            pinned: true
        ).makeResource(now: older)
        let recent = try AgentMemoryRequest(
            title: "Recent lesson",
            content: "Use the memory API for durable preferences.",
            task: "agent memory",
            kind: "lesson",
            source: "Claude",
            tags: nil,
            pinned: false
        ).makeResource(now: newer)
        let unrelated = ResourceItem(type: .knowledge, group: "Knowledge", title: "Plain note", content: "Not memory")
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(items: [recent, unrelated, pinned]),
            createsStatusItem: false
        )

        #expect(controller.resourceOverview.memories == 2)
        #expect(controller.memoryItems.map(\.title) == ["Pinned rule", "Recent lesson"])

        controller.openMemoryLibrary()

        #expect(controller.activeTab == .library)
        #expect(controller.selectedResourceType == .knowledge)
        #expect(controller.selectedResourceGroup == AgentMemoryRequest.group)
        #expect(controller.searchText == "memory")
        #expect(Set(controller.resources.map(\.title)) == Set(["Pinned rule", "Recent lesson"]))
    }

    @Test func refreshResourcesLoadsActiveAgentPresence() throws {
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Working", capabilities: ["code"]))
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            agentPresenceStore: presence,
            createsStatusItem: false
        )

        controller.refreshResources()

        #expect(controller.activeAgentPresences.map(\.source) == ["Codex"])
        #expect(controller.activeAgentPresences.first?.task == "Working")
    }

    @Test func launchAtLoginToggleUsesInjectedManager() {
        let launchAtLoginManager = StubLaunchAtLoginManager(isEnabled: false)
        let controller = StatusController(
            soundPlayer: SoundPlayer(),
            resourceStore: InMemoryResourceStore(),
            launchAtLoginManager: launchAtLoginManager,
            createsStatusItem: false
        )

        #expect(controller.launchAtLoginEnabled == false)

        controller.setLaunchAtLoginEnabled(true)

        #expect(launchAtLoginManager.requestedStates == [true])
        #expect(controller.launchAtLoginEnabled == true)
    }
}

@MainActor
private final class StubLaunchAtLoginManager: LaunchAtLoginManaging {
    private(set) var requestedStates: [Bool] = []
    private var enabled: Bool

    var isEnabled: Bool {
        enabled
    }

    init(isEnabled: Bool) {
        enabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) throws {
        requestedStates.append(enabled)
        self.enabled = enabled
    }
}
