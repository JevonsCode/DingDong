import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import Darwin
import QuartzCore
import SwiftUI

enum ServerState: Equatable {
    case running(port: UInt16)
    case failed(String)

    func displayText(language: AppLanguage) -> String {
        switch self {
        case .running(let port):
            language.message(.apiListening, value: "\(port)")
        case .failed(let message):
            language.message(.apiFailed, value: message)
        }
    }
}

struct ResourceOverview: Equatable {
    var total = 0
    var pinned = 0
    var handoffs = 0
    var memories = 0
    var prompts = 0
    var skills = 0
    var mcp = 0
    var knowledge = 0
    var clipboard = 0

    init(items: [ResourceItem] = []) {
        total = items.count
        pinned = items.filter(\.pinned).count
        handoffs = items.filter { $0.group == AgentHandoffRequest.group }.count
        memories = items.filter { $0.group == AgentMemoryRequest.group }.count
        prompts = items.filter { $0.type == .prompt }.count
        skills = items.filter { $0.type == .skill }.count
        mcp = items.filter { $0.type == .mcp }.count
        knowledge = items.filter { $0.type == .knowledge }.count
        clipboard = items.filter { $0.type == .clipboard }.count
    }
}

struct SystemUsageSnapshot: Equatable {
    var residentMemoryBytes: UInt64?
    var storageBytes: UInt64?
    var capturedAt: Date

    static func current(
        storageDirectory: URL = ResourceStore.defaultFileURL().deletingLastPathComponent(),
        fileManager: FileManager = .default
    ) -> SystemUsageSnapshot {
        SystemUsageSnapshot(
            residentMemoryBytes: currentResidentMemoryBytes(),
            storageBytes: allocatedSize(of: storageDirectory, fileManager: fileManager),
            capturedAt: Date()
        )
    }

    private static func currentResidentMemoryBytes() -> UInt64? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return UInt64(info.resident_size)
    }

    private static func allocatedSize(of directory: URL, fileManager: FileManager) -> UInt64? {
        guard fileManager.fileExists(atPath: directory.path) else {
            return 0
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsPackageDescendants]
        ) else {
            return nil
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true
            else {
                continue
            }

            let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0
            total += UInt64(max(0, size))
        }

        return total
    }
}

struct ClipboardSnippetShortcut: Equatable, Identifiable {
    var alias: String
    var item: ResourceItem

    var id: String {
        "\(alias)-\(item.id.uuidString)"
    }
}

private final class NotificationObserverBox: @unchecked Sendable {
    private let center: NotificationCenter
    nonisolated(unsafe) var observer: NSObjectProtocol?

    init(center: NotificationCenter) {
        self.center = center
    }

    deinit {
        if let observer {
            center.removeObserver(observer)
        }
    }
}

struct ClipboardCopilotSummary: Equatable {
    var total = 0
    var usefulCandidates = 0
    var snippetCandidates = 0
    var hiddenSensitive = 0
    var topGroup: String?
    var preferredFilter: ClipboardSmartFilter = .all

    init(items: [ResourceItem] = []) {
        let clipboardItems = items.filter { $0.type == .clipboard }
        let visibleItems = clipboardItems.filter { !$0.isSensitiveClipboard }
        total = clipboardItems.count
        usefulCandidates = visibleItems.filter(Self.isUsefulCandidate).count
        snippetCandidates = visibleItems.filter { !Self.aliases(for: $0).isEmpty }.count
        hiddenSensitive = clipboardItems.filter(\.isSensitiveClipboard).count
        topGroup = ClipboardOverview(items: clipboardItems).groups.first?.name
        preferredFilter = Self.preferredFilter(for: visibleItems)
    }

    var hasSuggestions: Bool {
        usefulCandidates > 0 || snippetCandidates > 0 || hiddenSensitive > 0
    }

    private static func isUsefulCandidate(_ item: ResourceItem) -> Bool {
        let usefulTags: Set<String> = ["command", "code", "json", "url", "path", "text"]
        return !item.pinned && item.tags.contains { usefulTags.contains($0) }
    }

    private static func aliases(for item: ResourceItem) -> [String] {
        item.tags.compactMap { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("alias:") else {
                return nil
            }

            let alias = String(trimmed.dropFirst("alias:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return alias.isEmpty ? nil : alias
        }
    }

    private static func preferredFilter(for items: [ResourceItem]) -> ClipboardSmartFilter {
        let priority: [ClipboardSmartFilter] = [.command, .code, .json, .url, .path, .email]
        return priority.first { filter in
            guard let tag = filter.tagQuery else {
                return false
            }
            return items.contains { $0.tags.contains(tag) }
        } ?? .all
    }
}

struct CompanionReadiness: Equatable {
    var resourceCount = 0
    var promptCount = 0
    var skillCount = 0
    var mcpCount = 0
    var knowledgeCount = 0
    var memoryCount = 0
    var clipboardCount = 0
    var openHandoffCount = 0
    var activeAgentCount = 0
    var clipboardMonitoringEnabled = false

    init(
        resources: [ResourceItem] = [],
        activeAgents: [AgentPresenceRecord] = [],
        handoffStatusCounts: [String: Int] = [:],
        clipboardMonitoringEnabled: Bool = false
    ) {
        resourceCount = resources.count
        promptCount = resources.filter { $0.type == .prompt }.count
        skillCount = resources.filter { $0.type == .skill }.count
        mcpCount = resources.filter { $0.type == .mcp }.count
        knowledgeCount = resources.filter { $0.type == .knowledge }.count
        memoryCount = resources.filter { $0.group == AgentMemoryRequest.group }.count
        clipboardCount = resources.filter { $0.type == .clipboard }.count
        openHandoffCount = handoffStatusCounts["open", default: 0] + handoffStatusCounts["blocked", default: 0]
        activeAgentCount = activeAgents.count
        self.clipboardMonitoringEnabled = clipboardMonitoringEnabled
    }

    var score: Int {
        var value = 0
        if promptCount > 0 { value += 20 }
        if skillCount > 0 { value += 15 }
        if mcpCount > 0 { value += 15 }
        if knowledgeCount > 0 { value += 20 }
        if memoryCount > 0 { value += 10 }
        if clipboardCount > 0 || clipboardMonitoringEnabled { value += 10 }
        if activeAgentCount > 0 { value += 5 }
        if openHandoffCount > 0 { value += 5 }
        return min(value, 100)
    }

    var state: CompanionReadinessState {
        if score >= 80 {
            .ready
        } else if score >= 45 {
            .warming
        } else {
            .needsSetup
        }
    }
}

enum CompanionReadinessState: Equatable {
    case ready
    case warming
    case needsSetup
}

@MainActor
final class StatusController: NSObject, ObservableObject {
    @Published private(set) var lastMessage = "Waiting for an agent signal"
    @Published private(set) var lastTriggerText = "No triggers yet"
    @Published private(set) var serverState: ServerState = .running(port: 8765)
    @Published private(set) var isFlashing = false
    @Published private(set) var unreadDingCount = 0
    @Published private(set) var resources: [ResourceItem] = []
    @Published private(set) var clipboardItems: [ResourceItem] = []
    @Published private(set) var clipboardSnippets: [ClipboardSnippetShortcut] = []
    @Published private(set) var clipboardCopilot = ClipboardCopilotSummary()
    @Published private(set) var activeSessionItems: [ResourceItem] = []
    @Published private(set) var handoffInboxItems: [ResourceItem] = []
    @Published private(set) var handoffInboxStatusCounts: [String: Int] = [:]
    @Published private(set) var memoryItems: [ResourceItem] = []
    @Published private(set) var libraryGroupSummaries: [LibraryGroupSummary] = []
    @Published private(set) var resourceOverview = ResourceOverview()
    @Published private(set) var clipboardOverview = ClipboardOverview()
    @Published private(set) var companionReadiness = CompanionReadiness()
    @Published private(set) var agentEvents: [AgentEvent] = []
    @Published private(set) var activeAgentPresences: [AgentPresenceRecord] = []
    @Published private(set) var selectedResourceType: ResourceType? = nil
    @Published private(set) var isClipboardMonitoring = false
    @Published private(set) var knowledgeIndexTitle: String?
    @Published private(set) var knowledgeIndexRoot: String?
    @Published private(set) var knowledgeIndexEntries: [KnowledgeIndexEntry] = []
    @Published private(set) var knowledgeIndexStatus = ""
    @Published private(set) var activeTab: CompanionTab = .today
    @Published private(set) var isContentLoading = false
    @Published private(set) var language: AppLanguage = .english
    @Published private(set) var clipboardHotKeyState: GlobalHotKeyState = .inactive
    @Published private(set) var selectedClipboardFilter: ClipboardSmartFilter = .all
    @Published private(set) var selectedClipboardGroup: String?
    @Published private(set) var clipboardFilterOrder: [ClipboardSmartFilter] = ClipboardSmartFilter.allCases
    @Published private(set) var clipboardGroupOrder: [String] = []
    @Published private(set) var selectedResourceGroup: String?
    @Published private(set) var clipboardMaxItems = ClipboardRetentionPolicy.defaultMaxItems
    @Published private(set) var clipboardMaxAgeDays = ClipboardRetentionPolicy.defaultMaxAgeDays
    @Published private(set) var panelBackgroundOpacity = PanelPreferences.defaultBackgroundOpacity
    @Published private(set) var panelDensity: PanelDensity = .comfortable
    @Published private(set) var defaultPanelTab: CompanionTab = .today
    @Published private(set) var releaseStatus = ReleaseStatus.currentOnly
    @Published private(set) var resourceManagerEditingResourceID: UUID?
    @Published var searchText = ""

    var isQuickPasteSessionActive: Bool {
        quickPasteTargetApplication != nil
    }

    var isQuickPasteAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    var systemUsageSnapshot: SystemUsageSnapshot {
        SystemUsageSnapshot.current()
    }

    func refreshReleaseStatus() {
        guard !releaseStatus.isChecking else {
            return
        }

        releaseStatus = releaseStatus.checking()
        releaseMetadataTask?.cancel()
        releaseMetadataTask = ReleaseMetadataFetcher.fetch { [weak self] result in
            Task { @MainActor in
                guard let self else {
                    return
                }

                switch result {
                case .success(let metadata):
                    self.releaseStatus = self.releaseStatus.resolved(metadata)
                case .failure(let error):
                    self.releaseStatus = self.releaseStatus.failed(error.localizedDescription)
                }
            }
        }
    }

    func openReleaseWebsite() {
        NSWorkspace.shared.open(releaseStatus.websiteURL)
    }

    func openLatestReleasePage() {
        NSWorkspace.shared.open(releaseStatus.releasePageURL)
    }

    let soundPlayer: SoundPlayer
    let resourceStore: ResourceStoreProtocol
    let clipboardRecorder: ClipboardRecorder
    let agentEventStore: AgentEventStore
    let agentPresenceStore: AgentPresenceStore
    let knowledgeIndexer: KnowledgeIndexer
    let libraryImporter: LibraryImporter

    private var statusItem: NSStatusItem?
    private var statusItemEventView: StatusItemEventView?
    private var panelWindow: NSPanel?
    private var clipboardDetailWindow: NSPanel?
    private var showcaseWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var usageGuideWindow: NSWindow?
    private var resourceManagerWindow: NSWindow?
    private var sharingServicePicker: NSSharingServicePicker?
    private var quickPasteHotKeyController: ClipboardQuickPasteHotKeyController?
    private var quickPasteTargetApplication: NSRunningApplication?
    private var lastExternalApplication: NSRunningApplication?
    private let workspaceActivationObserver = NotificationObserverBox(center: NSWorkspace.shared.notificationCenter)
    private var visibleClipboardShortcutIDs: [UUID] = []
    private var deferredRefreshWorkItem: DispatchWorkItem?
    private var deferredLoadingEndWorkItem: DispatchWorkItem?
    private var deferredClipboardFilterPreferencesSaveWorkItem: DispatchWorkItem?
    private var releaseMetadataTask: URLSessionDataTask?
    private var contentLoadingGeneration = 0
    private var flashTimer: Timer?
    private var clipboardTimer: Timer?
    private var lastClipboardChangeCount = -1
    private var flashRemaining = 0
    private var flashIsHot = false
    private let clipboardMonitoringKey = "dingdong.clipboard.monitoring"
    private let languageKey = "dingdong.language"
    private let clipboardFilterOrderKey = "dingdong.clipboard.filterOrder"
    private let clipboardGroupOrderKey = "dingdong.clipboard.groupOrder"
    private let deferredRefreshDelay: TimeInterval = 0.12
    private let minimumContentLoadingDuration: TimeInterval = 0.72

    init(
        soundPlayer: SoundPlayer,
        resourceStore: ResourceStoreProtocol = ResourceStore(),
        clipboardRecorder: ClipboardRecorder = ClipboardRecorder(),
        agentEventStore: AgentEventStore = AgentEventStore(),
        agentPresenceStore: AgentPresenceStore = AgentPresenceStore(),
        knowledgeIndexer: KnowledgeIndexer = KnowledgeIndexer(),
        libraryImporter: LibraryImporter = LibraryImporter(),
        createsStatusItem: Bool = true
    ) {
        self.soundPlayer = soundPlayer
        self.resourceStore = resourceStore
        self.clipboardRecorder = clipboardRecorder
        self.agentEventStore = agentEventStore
        self.agentPresenceStore = agentPresenceStore
        self.knowledgeIndexer = knowledgeIndexer
        self.libraryImporter = libraryImporter
        super.init()
        restoreLanguagePreference()
        restorePanelPreferences()
        restoreClipboardFilterPreferences()
        restoreClipboardRetentionPolicy()
        startTrackingExternalApplicationActivation()
        configurePopover()
        refreshResources()
        restoreClipboardMonitoringPreference()

        if createsStatusItem {
            configureStatusItem()
            refreshReleaseStatus()
        }
    }

    func setServerState(_ state: ServerState) {
        serverState = state
    }

    func text(_ key: AppText) -> String {
        language.text(key)
    }

    func setLanguage(_ nextLanguage: AppLanguage) {
        let wasIdleMessage = lastMessage == language.text(.waitingForAgent)
        let wasIdleTrigger = lastTriggerText == language.text(.noTriggers)
        language = nextLanguage
        UserDefaults.standard.set(nextLanguage.rawValue, forKey: languageKey)

        if wasIdleMessage {
            lastMessage = nextLanguage.text(.waitingForAgent)
        }

        if wasIdleTrigger {
            lastTriggerText = nextLanguage.text(.noTriggers)
        }
    }

    func setActiveTab(_ tab: CompanionTab) {
        guard activeTab != tab else {
            scheduleDeferredRefresh()
            return
        }

        activeTab = tab
        scheduleDeferredRefresh()
    }

    private func scheduleDeferredRefresh() {
        deferredRefreshWorkItem?.cancel()
        deferredLoadingEndWorkItem?.cancel()
        contentLoadingGeneration += 1
        let loadingGeneration = contentLoadingGeneration
        let loadingStartedAt = Date()
        isContentLoading = true

        var workItem: DispatchWorkItem!
        workItem = DispatchWorkItem { [weak self] in
            guard let self, !workItem.isCancelled else {
                return
            }

            self.refreshResources()
            let elapsed = Date().timeIntervalSince(loadingStartedAt)
            let remaining = max(0, self.minimumContentLoadingDuration - elapsed)
            let endWorkItem = DispatchWorkItem { [weak self] in
                guard let self, self.contentLoadingGeneration == loadingGeneration else {
                    return
                }

                self.isContentLoading = false
                self.deferredLoadingEndWorkItem = nil
            }

            self.deferredLoadingEndWorkItem = endWorkItem
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: endWorkItem)
        }
        deferredRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + deferredRefreshDelay, execute: workItem)
    }

    func setClipboardFilter(_ filter: ClipboardSmartFilter) {
        selectedClipboardFilter = filter
        refreshResources()
    }

    func setClipboardGroup(_ group: String?) {
        let trimmedGroup = group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectedClipboardGroup = trimmedGroup.isEmpty ? nil : trimmedGroup
        refreshResources()
    }

    func moveClipboardFilter(_ source: ClipboardSmartFilter, before target: ClipboardSmartFilter) {
        guard source != target else {
            return
        }

        var nextOrder = clipboardFilterOrder
        guard let sourceIndex = nextOrder.firstIndex(of: source),
              let originalTargetIndex = nextOrder.firstIndex(of: target)
        else {
            return
        }

        nextOrder.remove(at: sourceIndex)
        let targetIndex = nextOrder.firstIndex(of: target) ?? nextOrder.endIndex
        let insertionIndex = sourceIndex < originalTargetIndex ? min(targetIndex + 1, nextOrder.endIndex) : targetIndex
        nextOrder.insert(source, at: insertionIndex)
        let sanitizedOrder = Self.sanitizedClipboardFilterOrder(nextOrder)
        guard sanitizedOrder != clipboardFilterOrder else {
            return
        }

        clipboardFilterOrder = sanitizedOrder
        scheduleClipboardFilterPreferencesSave()
    }

    func moveClipboardGroup(_ source: String, before target: String) {
        let sourceName = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetName = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceName.isEmpty, !targetName.isEmpty, sourceName != targetName else {
            return
        }

        var nextOrder = clipboardGroupOrder
        guard let sourceIndex = nextOrder.firstIndex(of: sourceName),
              let originalTargetIndex = nextOrder.firstIndex(of: targetName)
        else {
            return
        }

        nextOrder.remove(at: sourceIndex)
        let targetIndex = nextOrder.firstIndex(of: targetName) ?? nextOrder.endIndex
        let insertionIndex = sourceIndex < originalTargetIndex ? min(targetIndex + 1, nextOrder.endIndex) : targetIndex
        nextOrder.insert(sourceName, at: insertionIndex)
        let sanitizedOrder = Self.sanitizedClipboardGroupOrder(nextOrder, groups: clipboardOverview.groups)
        guard sanitizedOrder != clipboardGroupOrder else {
            return
        }

        clipboardGroupOrder = sanitizedOrder
        let sortedGroups = sortedClipboardGroupBuckets(clipboardOverview.groups)
        if sortedGroups != clipboardOverview.groups {
            clipboardOverview.groups = sortedGroups
        }
        scheduleClipboardFilterPreferencesSave()
    }

    func setClipboardMaxItems(_ value: Int) {
        updateClipboardRetentionPolicy(maxItems: value, maxAgeDays: clipboardMaxAgeDays)
    }

    func setClipboardMaxAgeDays(_ value: Int) {
        updateClipboardRetentionPolicy(maxItems: clipboardMaxItems, maxAgeDays: value)
    }

    func setPanelBackgroundOpacity(_ value: Double) {
        let opacity = PanelPreferences.clampedBackgroundOpacity(value)
        guard opacity != panelBackgroundOpacity else {
            return
        }

        panelBackgroundOpacity = opacity
        savePanelPreferences()
    }

    func setPanelDensity(_ density: PanelDensity) {
        guard density != panelDensity else {
            return
        }

        panelDensity = density
        savePanelPreferences()
    }

    func setDefaultPanelTab(_ tab: CompanionTab) {
        let sanitizedTab = CompanionTab.mainPanelTabs.contains(tab) ? tab : .today
        guard sanitizedTab != defaultPanelTab else {
            return
        }

        defaultPanelTab = sanitizedTab
        activeTab = sanitizedTab
        savePanelPreferences()
    }

    func setClipboardHotKeyState(_ state: GlobalHotKeyState) {
        clipboardHotKeyState = state
    }

    func openAccessibilityPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func trigger(_ request: DingRequest, recordsEvent: Bool = true) {
        if recordsEvent {
            agentEventStore.record(request)
        } else {
            incrementUnreadDingCount()
        }
        lastMessage = request.message
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        soundPlayer.play(request.sound)
        setStatusContent(isHot: unreadDingCount > 0)
        refreshAgentEvents()
    }

    func testDing() {
        trigger(DingRequest(message: language.text(.manualTest), source: "DingDong", sound: .sparkle, flashCount: 8))
    }

    func chooseCustomSound() {
        soundPlayer.chooseCustomSound()
    }

    func clearCustomSound() {
        soundPlayer.clearCustomSound()
    }

    func selectResourceType(_ type: ResourceType?) {
        selectedResourceType = type
        selectedResourceGroup = nil
        refreshResources()
    }

    func selectResourceGroup(_ group: String?) {
        let trimmedGroup = group?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        selectedResourceGroup = trimmedGroup.isEmpty ? nil : trimmedGroup
        refreshResources()
    }

    func refreshResources() {
        do {
            let allResources = try resourceStore.list(type: nil, query: nil, limit: nil)
            let sessionItems = Self.agentSessionItems(from: allResources)
            let handoffItems = Self.agentHandoffItems(from: allResources)
            let groupSource = selectedResourceType.map { type in
                allResources.filter { $0.type == type }
            } ?? allResources
            resourceOverview = ResourceOverview(items: allResources)
            var nextClipboardOverview = ClipboardOverview(items: allResources)
            reconcileClipboardGroupOrder(with: nextClipboardOverview.groups)
            nextClipboardOverview.groups = sortedClipboardGroupBuckets(nextClipboardOverview.groups)
            clipboardOverview = nextClipboardOverview
            clipboardCopilot = ClipboardCopilotSummary(items: allResources)
            clipboardSnippets = Self.clipboardSnippetShortcuts(from: allResources)
            activeSessionItems = Self.activeSessionItems(from: sessionItems)
            handoffInboxStatusCounts = Self.handoffStatusCounts(handoffItems)
            handoffInboxItems = Self.handoffInboxItems(from: handoffItems)
            memoryItems = Self.agentMemoryItems(from: allResources)
            companionReadiness = CompanionReadiness(
                resources: allResources,
                activeAgents: agentPresenceStore.list(limit: 6),
                handoffStatusCounts: handoffInboxStatusCounts,
                clipboardMonitoringEnabled: isClipboardMonitoring
            )
            libraryGroupSummaries = LibraryGroupSummary.summaries(from: groupSource)
            resources = try filteredLibraryResources()
            clipboardItems = try filteredClipboardItems()
            refreshAgentEvents()
        } catch {
            lastMessage = language.message(.resourceLibraryUnavailable)
        }
    }

    private func filteredLibraryResources() throws -> [ResourceItem] {
        var items = try resourceStore.list(type: selectedResourceType, query: searchText, limit: nil)
        if let selectedResourceGroup {
            items = items.filter {
                $0.group.localizedCaseInsensitiveCompare(selectedResourceGroup) == .orderedSame
            }
        }
        return Array(items.prefix(80))
    }

    private func filteredClipboardItems() throws -> [ResourceItem] {
        var items = try resourceStore.list(type: .clipboard, query: searchText, limit: nil)
        if let tagQuery = selectedClipboardFilter.tagQuery {
            items = items.filter { $0.tags.contains(tagQuery) }
        }
        if let selectedClipboardGroup {
            items = items.filter {
                $0.group.localizedCaseInsensitiveCompare(selectedClipboardGroup) == .orderedSame
            }
        }
        return Array(items.prefix(16))
    }

    private static func clipboardSnippetShortcuts(from resources: [ResourceItem], limit: Int = 8) -> [ClipboardSnippetShortcut] {
        var shortcutsByAlias: [String: ClipboardSnippetShortcut] = [:]

        for item in resources where item.type == .clipboard {
            for alias in snippetAliases(for: item) {
                let shortcut = ClipboardSnippetShortcut(alias: alias, item: item)
                if let existing = shortcutsByAlias[alias] {
                    if shouldPreferSnippet(item, over: existing.item) {
                        shortcutsByAlias[alias] = shortcut
                    }
                } else {
                    shortcutsByAlias[alias] = shortcut
                }
            }
        }

        return Array(shortcutsByAlias.values)
            .sorted { lhs, rhs in
                if lhs.item.pinned != rhs.item.pinned {
                    return lhs.item.pinned && !rhs.item.pinned
                }
                if lhs.item.updatedAt != rhs.item.updatedAt {
                    return lhs.item.updatedAt > rhs.item.updatedAt
                }
                return lhs.alias.localizedCaseInsensitiveCompare(rhs.alias) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func snippetAliases(for item: ResourceItem) -> [String] {
        item.tags.compactMap { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("alias:") else {
                return nil
            }

            let alias = String(trimmed.dropFirst("alias:".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return alias.isEmpty ? nil : alias
        }
    }

    private static func shouldPreferSnippet(_ candidate: ResourceItem, over current: ResourceItem) -> Bool {
        if candidate.pinned != current.pinned {
            return candidate.pinned && !current.pinned
        }

        if candidate.updatedAt != current.updatedAt {
            return candidate.updatedAt > current.updatedAt
        }

        return candidate.title.localizedCaseInsensitiveCompare(current.title) == .orderedAscending
    }

    func handoffStatus(for item: ResourceItem) -> String {
        Self.workflowStatus(for: item)
    }

    func sessionStatus(for item: ResourceItem) -> String {
        Self.workflowStatus(for: item)
    }

    func openSessionLibrary() {
        selectedResourceType = .knowledge
        selectedResourceGroup = AgentSessionRequest.group
        searchText = "session"
        activeTab = .library
        refreshResources()
    }

    func openHandoffLibrary() {
        selectedResourceType = .knowledge
        selectedResourceGroup = AgentHandoffRequest.group
        searchText = "handoff"
        activeTab = .library
        refreshResources()
    }

    func openMemoryLibrary() {
        selectedResourceType = .knowledge
        selectedResourceGroup = AgentMemoryRequest.group
        searchText = "memory"
        activeTab = .library
        refreshResources()
    }

    private static func agentSessionItems(from resources: [ResourceItem]) -> [ResourceItem] {
        resources.filter { $0.type == .knowledge && $0.group == AgentSessionRequest.group }
    }

    private static func activeSessionItems(from sessions: [ResourceItem], limit: Int = 5) -> [ResourceItem] {
        sessions
            .filter { workflowStatus(for: $0) == "active" }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }

                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func agentHandoffItems(from resources: [ResourceItem]) -> [ResourceItem] {
        resources.filter { $0.type == .knowledge && $0.group == AgentHandoffRequest.group }
    }

    private static func handoffInboxItems(from handoffs: [ResourceItem], limit: Int = 5) -> [ResourceItem] {
        handoffs
            .filter { workflowStatus(for: $0) != "done" }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }

                let lhsRank = handoffStatusRank(workflowStatus(for: lhs))
                let rhsRank = handoffStatusRank(workflowStatus(for: rhs))
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }

                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func handoffStatusCounts(_ handoffs: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in handoffs {
            counts[workflowStatus(for: item), default: 0] += 1
        }
        return counts
    }

    private static func agentMemoryItems(from resources: [ResourceItem], limit: Int = 5) -> [ResourceItem] {
        resources
            .filter { $0.type == .knowledge && $0.group == AgentMemoryRequest.group }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }

                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func workflowStatus(for item: ResourceItem) -> String {
        let status = item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            ?? ""
        return status.isEmpty ? "unknown" : status
    }

    private static func handoffStatusRank(_ status: String) -> Int {
        switch status {
        case "blocked":
            0
        case "open":
            1
        case "unknown":
            2
        default:
            3
        }
    }

    func refreshAgentEvents() {
        agentEvents = agentEventStore.list(limit: 12)
        activeAgentPresences = agentPresenceStore.list(limit: 6)
    }

    func captureClipboard() {
        captureClipboard(source: "Menu Bar", announcesEmpty: true)
    }

    @discardableResult
    func addResource(
        type: ResourceType,
        title: String,
        content: String,
        group: String,
        tagsText: String,
        pinned: Bool
    ) -> Bool {
        let item = ResourceItem(
            type: type,
            group: group,
            title: title,
            content: content,
            tags: tagsText
                .split(separator: ",")
                .map(String.init),
            source: "DingDong",
            pinned: pinned
        )

        guard !item.title.isEmpty,
              !item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastMessage = language.message(.titleAndContentRequired)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }

        guard validateContentLength(item.content, type: item.type) else {
            return false
        }

        do {
            _ = try resourceStore.add(item)
            lastMessage = language.message(.savedResource, value: item.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            selectResourceType(type)
            return true
        } catch {
            lastMessage = language.message(.couldNotSaveResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }
    }

    @discardableResult
    func updateResource(
        id: UUID,
        type: ResourceType,
        title: String,
        content: String,
        group: String,
        tagsText: String,
        pinned: Bool
    ) -> Bool {
        let changes = ResourceUpdateRequest(
            type: type,
            group: group,
            title: title,
            content: content,
            tags: tagsText
                .split(separator: ",")
                .map(String.init),
            pinned: pinned
        )

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastMessage = language.message(.titleAndContentRequired)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }

        guard validateContentLength(content, type: type) else {
            return false
        }

        do {
            guard let item = try resourceStore.update(id: id, changes: changes) else {
                lastMessage = language.message(.resourceNotFound)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
                return false
            }

            lastMessage = language.message(.updatedResource, value: item.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            selectResourceType(item.type)
            return true
        } catch {
            lastMessage = language.message(.couldNotUpdateResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }
    }

    func setClipboardMonitoring(_ isEnabled: Bool) {
        if isEnabled {
            startClipboardMonitoring()
        } else {
            stopClipboardMonitoring()
        }
    }

    func toggleClipboardMonitoring() {
        setClipboardMonitoring(!isClipboardMonitoring)
    }

    @discardableResult
    func captureClipboard(source: String, announcesEmpty: Bool = false) -> ResourceItem? {
        guard let item = clipboardRecorder.capture(source: source) else {
            if announcesEmpty {
                lastMessage = language.message(.clipboardHasNoText)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            }
            return nil
        }

        guard validateContentLength(item.content, type: .clipboard) else {
            return nil
        }

        let existingClipboard = (try? resourceStore.list(type: .clipboard, query: nil, limit: nil)) ?? clipboardItems
        if existingClipboard.contains(where: { $0.content == item.content }) {
            if announcesEmpty {
                lastMessage = language.message(.clipboardAlreadyCaptured)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            }
            return nil
        }

        do {
            let stored = try resourceStore.add(item)
            lastMessage = language.message(.capturedClipboard)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            refreshResources()
            pruneClipboardImageCache()
            return stored
        } catch {
            lastMessage = language.message(.couldNotSaveClipboard)
            return nil
        }
    }

    private func validateContentLength(_ content: String, type: ResourceType) -> Bool {
        do {
            try ResourceLimits.validateContent(content, type: type)
            return true
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            lastMessage = language.message(.contentTooLarge, maxCharacters: maxCharacters)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        } catch {
            lastMessage = language.message(.couldNotValidateContent)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }
    }

    private func startClipboardMonitoring() {
        clipboardTimer?.invalidate()
        isClipboardMonitoring = true
        UserDefaults.standard.set(true, forKey: clipboardMonitoringKey)
        lastClipboardChangeCount = clipboardRecorder.reader.changeCount
        refreshResources()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollClipboard()
            }
        }
    }

    private func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
        isClipboardMonitoring = false
        UserDefaults.standard.set(false, forKey: clipboardMonitoringKey)
        refreshResources()
    }

    private func pollClipboard() {
        let currentChangeCount = clipboardRecorder.reader.changeCount
        guard currentChangeCount != lastClipboardChangeCount else {
            return
        }

        lastClipboardChangeCount = currentChangeCount
        _ = captureClipboard(source: "Monitor")
    }

    private func restoreClipboardMonitoringPreference() {
        if UserDefaults.standard.bool(forKey: clipboardMonitoringKey) {
            startClipboardMonitoring()
        }
    }

    private func restoreLanguagePreference() {
        if let value = UserDefaults.standard.string(forKey: languageKey),
           let savedLanguage = AppLanguage(rawValue: value) {
            language = savedLanguage
        }

        lastMessage = language.text(.waitingForAgent)
        lastTriggerText = language.text(.noTriggers)
    }

    func copyResourceContent(_ item: ResourceItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.content, forType: .string)
        lastMessage = language.message(.copied, value: item.title)
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyResourceID(_ item: ResourceItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.id.uuidString, forType: .string)
        lastMessage = language.message(.copied, value: language.text(.copyResourceID))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func restoreClipboardItem(_ item: ResourceItem) {
        restoreClipboardItem(item, pasteToFocusedApp: false)
    }

    func restoreClipboardItem(_ item: ResourceItem, pasteToFocusedApp: Bool) {
        guard item.type == .clipboard else {
            return
        }

        NSPasteboard.general.clearContents()
        if !writeClipboardFileURLsIfNeeded(item) {
            NSPasteboard.general.setString(item.content, forType: .string)
        }
        lastMessage = language.message(.restoredClipboard, value: item.title)
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)

        if pasteToFocusedApp {
            guard requestQuickPasteAccessibilityIfNeeded(prompts: true) else {
                return
            }

            pasteRestoredClipboardToTargetApplication()
        }
    }

    private func writeClipboardFileURLsIfNeeded(_ item: ResourceItem) -> Bool {
        let urls = ClipboardFileReference.fileURLs(for: item)
        guard !urls.isEmpty else {
            return false
        }

        return NSPasteboard.general.writeObjects(urls.map { $0 as NSURL })
    }

    @discardableResult
    func restoreClipboardItemFromQuickAction(_ item: ResourceItem) -> Bool {
        guard item.type == .clipboard else {
            return false
        }

        restoreClipboardItem(item, pasteToFocusedApp: isQuickPasteSessionActive)
        return true
    }

    func updateClipboardTitle(_ item: ResourceItem, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard item.type == .clipboard, !trimmedTitle.isEmpty else {
            lastMessage = language.message(.titleAndContentRequired)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return
        }

        updateClipboardItem(item, changes: ResourceUpdateRequest(title: trimmedTitle))
    }

    func updateClipboardContent(_ item: ResourceItem, content: String) {
        guard item.type == .clipboard,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            lastMessage = language.message(.titleAndContentRequired)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return
        }

        guard validateContentLength(content, type: .clipboard) else {
            return
        }

        updateClipboardItem(item, changes: ResourceUpdateRequest(content: content))
    }

    func archiveClipboardItem(_ item: ResourceItem, group: String = "Archive") {
        guard item.type == .clipboard else {
            return
        }

        var tags = item.tags
        if !tags.contains("archived") {
            tags.append("archived")
        }
        updateClipboardItem(item, changes: ResourceUpdateRequest(group: sanitizedClipboardArchiveGroup(group), tags: tags))
    }

    private func sanitizedClipboardArchiveGroup(_ group: String) -> String {
        let trimmedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedGroup.isEmpty ? "Archive" : trimmedGroup
    }

    func saveClipboardItem(_ item: ResourceItem, as targetType: ResourceType) {
        guard item.type == .clipboard, targetType != .clipboard else {
            return
        }

        do {
            let promoted = try ClipboardPromotionRequest(targetType: targetType, group: targetType.defaultGroup)
                .makeResource(from: item)
            let stored = try resourceStore.add(promoted)
            selectedResourceType = targetType
            searchText = stored.title
            lastMessage = language.message(.savedResource, value: stored.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            refreshResources()
        } catch {
            lastMessage = language.message(.couldNotSaveResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    func shareResourceContent(_ item: ResourceItem) {
        let content = item.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? item.title : item.content
        guard let sourceView = clipboardDetailWindow?.contentView ?? panelWindow?.contentView else {
            copyResourceContent(item)
            return
        }

        let picker = NSSharingServicePicker(items: [content])
        sharingServicePicker = picker
        picker.show(relativeTo: sourceView.bounds, of: sourceView, preferredEdge: .maxY)
    }

    private func updateClipboardItem(_ item: ResourceItem, changes: ResourceUpdateRequest) {
        do {
            guard let updated = try resourceStore.update(id: item.id, changes: changes) else {
                lastMessage = language.message(.resourceNotFound)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
                return
            }

            lastMessage = language.message(.updatedResource, value: updated.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            refreshResources()
            if clipboardDetailWindow?.isVisible == true {
                showClipboardDetail(updated)
            }
        } catch {
            lastMessage = language.message(.couldNotUpdateResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    @discardableResult
    func restoreVisibleClipboardItem(at shortcutNumber: Int, pasteToFocusedApp: Bool = false) -> Bool {
        guard activeTab == .clipboard else {
            return false
        }

        let index = shortcutNumber - 1

        if !visibleClipboardShortcutIDs.isEmpty {
            guard visibleClipboardShortcutIDs.indices.contains(index),
                  let item = clipboardItems.first(where: { $0.id == visibleClipboardShortcutIDs[index] })
            else {
                return false
            }

            restoreClipboardItem(item, pasteToFocusedApp: pasteToFocusedApp)
            return true
        }

        guard clipboardItems.indices.contains(index) else {
            return false
        }

        restoreClipboardItem(clipboardItems[index], pasteToFocusedApp: pasteToFocusedApp)
        return true
    }

    @discardableResult
    func restoreVisibleClipboardItemFromShortcut(at shortcutNumber: Int) -> Bool {
        restoreVisibleClipboardItem(
            at: shortcutNumber,
            pasteToFocusedApp: isQuickPasteSessionActive
        )
    }

    func updateVisibleClipboardShortcutItems(_ items: [ResourceItem]) {
        let ids = Array(items.prefix(9).map(\.id))
        if ids != visibleClipboardShortcutIDs {
            visibleClipboardShortcutIDs = ids
        }
    }

    func clipboardArchiveGroups(excluding excludedGroup: String = "Archive") -> [String] {
        let items = (try? resourceStore.list(type: .clipboard, query: nil, limit: nil)) ?? clipboardItems
        var seen: Set<String> = []

        return items.compactMap { item in
            guard item.tags.contains("archived") else {
                return nil
            }

            let group = item.group.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = group.lowercased()
            guard !group.isEmpty,
                  group.localizedCaseInsensitiveCompare(excludedGroup) != .orderedSame,
                  !seen.contains(key)
            else {
                return nil
            }

            seen.insert(key)
            return group
        }
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func promoteClipboardToPrompt(_ item: ResourceItem) {
        guard item.type == .clipboard else {
            return
        }

        do {
            let promoted = try ClipboardPromotionRequest(targetType: .prompt).makeResource(from: item)
            let stored = try resourceStore.add(promoted)
            lastMessage = language.message(.savedAsPrompt)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            selectedResourceType = .prompt
            activeTab = .library
            searchText = stored.title
            refreshResources()
        } catch {
            lastMessage = language.message(.couldNotSavePrompt)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    func togglePinned(_ item: ResourceItem) {
        do {
            guard let updated = try resourceStore.setPinned(id: item.id, pinned: !item.pinned) else {
                lastMessage = language.message(.resourceNotFound)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
                return
            }

            lastMessage = updated.pinned
                ? language.message(.pinnedResource, value: updated.title)
                : language.message(.unpinnedResource, value: updated.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            refreshResources()
        } catch {
            lastMessage = language.message(.couldNotUpdateResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    func deleteResource(_ item: ResourceItem) {
        do {
            guard try resourceStore.delete(id: item.id) else {
                lastMessage = language.message(.resourceNotFound)
                lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
                return
            }

            lastMessage = language.message(.deletedResource, value: item.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            refreshResources()
            if item.type == .clipboard {
                pruneClipboardImageCache()
            }
        } catch {
            lastMessage = language.message(.couldNotDeleteResource)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    @discardableResult
    func importResources(
        type: ResourceType,
        path: String,
        group: String,
        tagsText: String
    ) -> Bool {
        guard type != .clipboard else {
            lastMessage = language.message(.clipboardImportUnsupported)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }

        let request = LibraryImportRequest(
            type: type,
            path: path,
            group: group,
            tags: tagsText
                .split(separator: ",")
                .map(String.init),
            source: "DingDong",
            limit: LibraryImporter.defaultLimit
        )

        do {
            let existing = try resourceStore.list(type: type, query: nil, limit: nil)
            let result = try libraryImporter.candidates(from: request, existing: existing)
            for item in result.imported {
                _ = try resourceStore.add(item)
            }

            lastMessage = language.message(.importedResources, count: result.imported.count)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            selectResourceType(type)
            return true
        } catch LibraryImportError.missingDirectory {
            lastMessage = language.message(.importPathNotDirectory)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        } catch {
            lastMessage = language.message(.couldNotImportResources)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return false
        }
    }

    func scanKnowledge(_ item: ResourceItem) {
        guard item.type == .knowledge else {
            lastMessage = language.message(.onlyKnowledgeScannable)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
            return
        }

        do {
            let result = try knowledgeIndexer.index(rootPath: item.content, maxFiles: 12)
            knowledgeIndexTitle = item.title
            knowledgeIndexRoot = result.root
            knowledgeIndexEntries = result.files
            knowledgeIndexStatus = result.truncated
                ? language.message(.filesShownMoreAvailable, count: result.files.count)
                : language.message(.filesCount, count: result.files.count)
            lastMessage = language.message(.scannedResource, value: item.title)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        } catch KnowledgeIndexError.missingDirectory {
            knowledgeIndexTitle = item.title
            knowledgeIndexRoot = item.content
            knowledgeIndexEntries = []
            knowledgeIndexStatus = language.message(.pathNotDirectory)
            lastMessage = language.message(.knowledgePathUnavailable)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        } catch {
            knowledgeIndexTitle = item.title
            knowledgeIndexRoot = item.content
            knowledgeIndexEntries = []
            knowledgeIndexStatus = language.message(.couldNotScan)
            lastMessage = language.message(.knowledgeScanFailed)
            lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        }
    }

    func closeKnowledgeIndex() {
        knowledgeIndexTitle = nil
        knowledgeIndexRoot = nil
        knowledgeIndexEntries = []
        knowledgeIndexStatus = ""
    }

    func copyKnowledgeEntryPath(_ entry: KnowledgeIndexEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.path, forType: .string)
        lastMessage = language.message(.copied, value: entry.name)
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyCurlExample() {
        let command = """
        curl -X POST http://127.0.0.1:8765/ding \\
          -H 'Content-Type: application/json' \\
          -d '{"message":"Agent task complete","sound":"random","flashCount":10}'
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    func copyAgentPrepareCommand(task: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.prepare(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentPrepareCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyAgentStartupCommand(task: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.startup(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentStartupCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyAgentWorkbenchCommand(task: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.workbench(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentWorkbenchCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyAgentToolkitCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.toolkit(), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentToolkitCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyAgentPresenceCommand(task: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.presence(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentPresenceCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyAgentMemoryCommand(task: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.memory(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.agentMemoryCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyClipboardInsightsCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.clipboardInsights(), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.clipboardInsightsCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func copyClipboardDigestCommand(task: String) {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = trimmedTask.isEmpty ? (clipboardCopilot.topGroup ?? AgentLaunchpadCommand.defaultTask) : trimmedTask
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AgentLaunchpadCommand.clipboardDigest(task: task), forType: .string)
        lastMessage = language.message(.copied, value: language.text(.clipboardDigestCommand))
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func focusClipboardCopilotCandidates() {
        selectedClipboardFilter = clipboardCopilot.preferredFilter
        selectedClipboardGroup = clipboardCopilot.topGroup
        activeTab = .clipboard
        refreshResources()
    }

    func copyAgentTemplate(_ template: AgentCommandTemplate) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(template.command, forType: .string)
        lastMessage = language.message(.copied, value: template.title)
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func pulseStatusIcon() {
        setStatusContent(isHot: unreadDingCount > 0)
    }

    func clearUnreadDingCount() {
        guard unreadDingCount != 0 else {
            return
        }

        unreadDingCount = 0
        stopStatusIconFlash()
        setStatusContent(isHot: false)
    }

    func hideCurrentPanel() {
        hidePopover(restoresFocus: isQuickPasteSessionActive)
    }

    func showPopover(activatesApp: Bool = true) {
        guard let button = statusItem?.button else {
            return
        }

        closeShowcaseWindow()

        if activatesApp {
            stopQuickPasteHotKeys(clearsTarget: false)
        }

        clearUnreadDingCount()
        let panel = panelWindow ?? makeFloatingPanel()
        panelWindow = panel
        let hidesOnDeactivateAfterActivation = activatesApp
        panel.hidesOnDeactivate = false
        positionFloatingPanel(panel, below: button)
        showPanelWithAnimation(panel)
        if clipboardDetailWindow?.isVisible == true {
            positionClipboardDetailPanel()
        }

        if activatesApp {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let self,
                      let panel,
                      self.panelWindow === panel,
                      panel.isVisible
                else {
                    return
                }

                panel.hidesOnDeactivate = hidesOnDeactivateAfterActivation
            }
        }
    }

    func showWindow(tab: CompanionTab? = nil) {
        if tab == .api {
            showSettingsWindow()
            return
        }

        if let tab {
            setActiveTab(tab)
        }

        if statusItem?.button != nil {
            closeShowcaseWindow()
            showPopover(activatesApp: true)
            return
        }

        if let showcaseWindow {
            showcaseWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = makePanelHostingController()
        let window = NSWindow(contentViewController: hostingController)
        window.title = "DingDong"
        window.setContentSize(NSSize(width: PanelMetrics.width, height: PanelMetrics.height))
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        showcaseWindow = window
    }

    private func closeShowcaseWindow() {
        showcaseWindow?.orderOut(nil)
        showcaseWindow = nil
    }

    func showSettingsWindow() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = makeSettingsHostingController()
        let window = NSWindow(contentViewController: hostingController)
        window.title = language.text(.settings)
        window.setContentSize(NSSize(width: 620, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func showUsageGuideWindow() {
        if let usageGuideWindow {
            usageGuideWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = makeUsageGuideHostingController()
        let window = NSWindow(contentViewController: hostingController)
        window.title = language == .chinese ? "使用说明" : "User Guide"
        window.setContentSize(NSSize(width: 640, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.level = .floating
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        usageGuideWindow = window
    }

    func showResourceManagerWindow(editing item: ResourceItem? = nil) {
        if let item {
            if resourceManagerEditingResourceID == item.id {
                resourceManagerEditingResourceID = nil
            }
            resourceManagerEditingResourceID = item.id
        }

        if let resourceManagerWindow {
            resourceManagerWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = makeResourceManagerHostingController()
        let window = NSWindow(contentViewController: hostingController)
        window.title = language == .chinese ? "资源管理" : "Resource Manager"
        window.setContentSize(NSSize(width: 1060, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true
        window.level = .normal
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        resourceManagerWindow = window
    }

    func showClipboardDetail(_ item: ResourceItem) {
        let view = ClipboardDetailPopoverView(
            item: item,
            language: language,
            onCopy: { [weak self] in
                self?.restoreClipboardItem(item)
            },
            onShare: { [weak self] in
                self?.shareResourceContent(item)
            },
            onClose: { [weak self] in
                self?.hideClipboardDetail()
            }
        )

        let window = clipboardDetailWindow ?? makeClipboardDetailPanel()
        clipboardDetailWindow = window

        if let hostingController = window.contentViewController as? NSHostingController<ClipboardDetailPopoverView> {
            hostingController.rootView = view
        } else {
            window.contentViewController = NSHostingController(rootView: view)
        }

        if let contentView = window.contentViewController?.view {
            applyPanelBackground(to: contentView)
        }
        positionClipboardDetailPanel()
        window.orderFrontRegardless()
    }

    func hideClipboardDetail() {
        clipboardDetailWindow?.orderOut(nil)
    }

    @discardableResult
    func handleClipboardHotKey() -> Bool {
        if panelWindow?.isVisible == true {
            hidePopover(restoresFocus: isQuickPasteSessionActive)
            return true
        }

        quickPasteTargetApplication = resolveQuickPasteTargetApplication()
        _ = requestQuickPasteAccessibilityIfNeeded(prompts: true)
        openClipboardList(activatesApp: true)
        if panelWindow?.isVisible == true {
            startQuickPasteHotKeys()
        }
        return true
    }

    func openClipboardList(activateWindow: Bool = true, activatesApp: Bool = true) {
        activeTab = .clipboard
        refreshResources()
        if activateWindow {
            showPopover(activatesApp: activatesApp)
        }
    }

    private func togglePopover() {
        guard statusItem?.button != nil else {
            return
        }

        if panelWindow?.isVisible == true {
            hidePopover(restoresFocus: isQuickPasteSessionActive)
        } else {
            showPopover()
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.autosaveName = "com.temptrip.dingdong.status-item"

        guard let button = item.button else {
            return
        }

        item.length = NSStatusItem.squareLength
        item.isVisible = true
        setStatusContent(isHot: false)
        installStatusItemEventView(on: button)
        button.toolTip = "DingDong Agent Reminder"
    }

    private func installStatusItemEventView(on button: NSStatusBarButton) {
        statusItemEventView?.removeFromSuperview()

        let eventView = StatusItemEventView(frame: button.bounds)
        eventView.autoresizingMask = [.width, .height]
        eventView.onLeftClick = { [weak self] in
            self?.togglePopover()
        }
        eventView.onRightClick = { [weak self] in
            self?.showStatusItemMenu()
        }
        button.addSubview(eventView)
        statusItemEventView = eventView
    }

    private func showStatusItemMenu() {
        guard let statusItem, let button = statusItem.button else {
            return
        }

        let menu = NSMenu()
        menu.addItem(menuItem(title: statusMenuTitle(.openPanel), action: #selector(openPanelFromStatusMenu)))
        menu.addItem(menuItem(title: statusMenuTitle(.openClipboard), action: #selector(openClipboardFromStatusMenu)))
        menu.addItem(menuItem(title: statusMenuTitle(.resourceManager), action: #selector(openResourceManagerFromStatusMenu)))
        menu.addItem(menuItem(title: statusMenuTitle(.toggleClipboardMonitoring), action: #selector(toggleClipboardMonitoringFromStatusMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: statusMenuTitle(.usageGuide), action: #selector(openUsageGuideFromStatusMenu)))
        menu.addItem(menuItem(title: statusMenuTitle(.settings), action: #selector(openSettingsFromStatusMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: statusMenuTitle(.quit), action: #selector(quitFromStatusMenu)))

        button.highlight(true)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        button.highlight(false)
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private enum StatusMenuAction {
        case openPanel
        case openClipboard
        case resourceManager
        case toggleClipboardMonitoring
        case usageGuide
        case settings
        case quit
    }

    private func statusMenuTitle(_ action: StatusMenuAction) -> String {
        switch (language, action) {
        case (.chinese, .openPanel):
            "打开面板"
        case (.english, .openPanel):
            "Open Panel"
        case (.chinese, .openClipboard):
            "打开剪贴板"
        case (.english, .openClipboard):
            "Open Clipboard"
        case (.chinese, .resourceManager):
            "资源管理"
        case (.english, .resourceManager):
            "Resource Manager"
        case (.chinese, .toggleClipboardMonitoring):
            isClipboardMonitoring ? "关闭剪贴板监听" : "开启剪贴板监听"
        case (.english, .toggleClipboardMonitoring):
            isClipboardMonitoring ? "Stop Clipboard Monitoring" : "Start Clipboard Monitoring"
        case (.chinese, .usageGuide):
            "使用说明"
        case (.english, .usageGuide):
            "User Guide"
        case (.chinese, .settings):
            "设置"
        case (.english, .settings):
            "Settings"
        case (.chinese, .quit):
            "退出"
        case (.english, .quit):
            "Quit"
        }
    }

    @objc private func openPanelFromStatusMenu() {
        showPopover()
    }

    @objc private func openClipboardFromStatusMenu() {
        openClipboardList()
    }

    @objc private func toggleClipboardMonitoringFromStatusMenu() {
        toggleClipboardMonitoring()
    }

    @objc private func openResourceManagerFromStatusMenu() {
        showResourceManagerWindow()
    }

    @objc private func openUsageGuideFromStatusMenu() {
        showUsageGuideWindow()
    }

    @objc private func openSettingsFromStatusMenu() {
        showSettingsWindow()
    }

    @objc private func quitFromStatusMenu() {
        quit()
    }

    private func startQuickPasteHotKeys() {
        if quickPasteHotKeyController == nil {
            quickPasteHotKeyController = ClipboardQuickPasteHotKeyController { [weak self] shortcutNumber in
                self?.handleQuickPasteShortcut(shortcutNumber)
            }
        }
        quickPasteHotKeyController?.start()
    }

    private func stopQuickPasteHotKeys(clearsTarget: Bool = true) {
        quickPasteHotKeyController?.stop()
        if clearsTarget {
            quickPasteTargetApplication = nil
        }
    }

    private func handleQuickPasteShortcut(_ shortcutNumber: Int) {
        guard restoreVisibleClipboardItemFromShortcut(at: shortcutNumber) else {
            return
        }
    }

    private func pasteRestoredClipboardToTargetApplication() {
        let targetApplication = quickPasteTargetApplication
        hideClipboardDetail()
        stopQuickPasteHotKeys()
        hidePanelWithAnimation(panelWindow) { [weak self] in
            self?.restoreFocusToTargetApplication(targetApplication) {
                Self.postPasteShortcut()
            }
        }
    }

    private func showPanelWithAnimation(_ panel: NSPanel) {
        let shouldAnimate = !panel.isVisible || panel.alphaValue < 0.98
        if shouldAnimate {
            panel.alphaValue = 0
        }

        panel.orderFrontRegardless()

        guard shouldAnimate else {
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.11
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanelWithAnimation(_ panel: NSPanel?, completion: (@MainActor @Sendable () -> Void)? = nil) {
        guard let panel, panel.isVisible else {
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.09
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel, completion] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
                completion?()
            }
        }
    }

    private func restoreFocusToTargetApplication(_ targetApplication: NSRunningApplication?, completion: (() -> Void)? = nil) {
        NSApp.deactivate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Self.activate(application: targetApplication)
            if let completion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                    completion()
                }
            }
        }
    }

    private func startTrackingExternalApplicationActivation() {
        if let application = Self.currentExternalFrontmostApplication() {
            lastExternalApplication = application
        }

        workspaceActivationObserver.observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }

            Task { @MainActor in
                self?.recordExternalApplication(application)
            }
        }
    }

    private func recordExternalApplication(_ application: NSRunningApplication) {
        guard Self.isExternalApplication(application) else {
            return
        }

        lastExternalApplication = application
    }

    private func resolveQuickPasteTargetApplication() -> NSRunningApplication? {
        if let application = Self.currentExternalFrontmostApplication() {
            lastExternalApplication = application
            return application
        }

        guard let application = lastExternalApplication,
              !application.isTerminated
        else {
            return nil
        }

        return application
    }

    private static func currentExternalFrontmostApplication() -> NSRunningApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        guard isExternalApplication(application) else {
            return nil
        }

        return application
    }

    private static func isExternalApplication(_ application: NSRunningApplication) -> Bool {
        guard !application.isTerminated,
              application.processIdentifier != NSRunningApplication.current.processIdentifier
        else {
            return false
        }

        if let bundleIdentifier = application.bundleIdentifier,
           bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return true
    }

    private static func activate(application: NSRunningApplication?) {
        guard let application, !application.isTerminated else {
            return
        }

        if #available(macOS 14.0, *) {
            application.activate(options: [.activateAllWindows])
        } else {
            application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    private static func postPasteShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }

        source.localEventsSuppressionInterval = 0
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let commandFlag = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = commandFlag
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = commandFlag
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func requestQuickPasteAccessibilityIfNeeded(prompts: Bool) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        if prompts {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            openAccessibilityPrivacySettings()
        }

        lastMessage = language == .chinese
            ? "请在系统设置允许 DingDong 控制电脑；授权后请重启 DingDong。"
            : "Allow DingDong to control this computer in System Settings, then restart DingDong."
        lastTriggerText = Date.now.formatted(date: .omitted, time: .standard)
        return false
    }

    private func hidePopover(restoresFocus: Bool = false) {
        let targetApplication = restoresFocus ? quickPasteTargetApplication : nil
        stopQuickPasteHotKeys()
        hideClipboardDetail()
        hidePanelWithAnimation(panelWindow) { [weak self] in
            guard restoresFocus else {
                return
            }

            self?.restoreFocusToTargetApplication(targetApplication)
        }
    }

    private func configurePopover() {
        panelWindow = makeFloatingPanel()
    }

    private func makeFloatingPanel() -> NSPanel {
        let hostingController = makePanelHostingController()
        hostingController.view.frame = NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height)
        let panel = FocusableFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.width, height: PanelMetrics.height),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hostingController
        panel.delegate = self
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.minSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.minHeight)
        panel.maxSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.maxHeight)
        panel.contentMinSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.minHeight)
        panel.contentMaxSize = NSSize(width: PanelMetrics.width, height: PanelMetrics.maxHeight)
        panel.setContentSize(NSSize(width: PanelMetrics.width, height: PanelMetrics.height))
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hidesOnDeactivate = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 18
        panel.contentView?.layer?.masksToBounds = true
        panel.onEscape = { [weak self] in
            guard let self else {
                return
            }

            self.hidePopover(restoresFocus: self.isQuickPasteSessionActive)
        }
        return panel
    }

    private func makeClipboardDetailPanel() -> NSPanel {
        let panel = FocusableFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: PanelMetrics.detailWidth, height: PanelMetrics.detailHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        panel.hidesOnDeactivate = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 16
        panel.contentView?.layer?.masksToBounds = true
        return panel
    }

    private func positionFloatingPanel(_ panel: NSPanel, below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else {
            panel.center()
            return
        }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let size = panel.frame.size
        let margin: CGFloat = 10
        let verticalGap: CGFloat = 14
        let x = min(max(buttonFrame.midX - size.width / 2, screenFrame.minX + margin), screenFrame.maxX - size.width - margin)
        let y = max(screenFrame.minY + margin, buttonFrame.minY - size.height - verticalGap)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionClipboardDetailPanel() {
        guard let detailPanel = clipboardDetailWindow else {
            return
        }

        guard let mainWindow = panelWindow ?? showcaseWindow,
              let mainScreen = mainWindow.screen ?? NSScreen.screens.first(where: { $0.frame.intersects(mainWindow.frame) })
        else {
            detailPanel.center()
            return
        }

        let mainFrame = mainWindow.frame
        let screenFrame = mainScreen.visibleFrame
        let detailSize = NSSize(width: PanelMetrics.detailWidth, height: PanelMetrics.detailHeight)
        let margin: CGFloat = 10
        let rightX = mainFrame.maxX + PanelMetrics.detailGap
        let leftX = mainFrame.minX - detailSize.width - PanelMetrics.detailGap
        let x = rightX + detailSize.width <= screenFrame.maxX - margin
            ? rightX
            : max(screenFrame.minX + margin, leftX)
        let y = min(
            max(screenFrame.minY + margin, mainFrame.maxY - detailSize.height),
            screenFrame.maxY - detailSize.height - margin
        )

        detailPanel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: detailSize), display: true)
    }

    private func makePanelHostingController() -> NSHostingController<ControlPanelView> {
        let hostingController = NSHostingController(
            rootView: ControlPanelView(controller: self, soundPlayer: soundPlayer)
        )
        applyPanelBackground(to: hostingController.view)
        return hostingController
    }

    private func makeSettingsHostingController() -> NSHostingController<SettingsPanelView> {
        let hostingController = NSHostingController(
            rootView: SettingsPanelView(controller: self, soundPlayer: soundPlayer)
        )
        applyPanelBackground(to: hostingController.view)
        return hostingController
    }

    private func makeUsageGuideHostingController() -> NSHostingController<UsageGuidePanelView> {
        let hostingController = NSHostingController(
            rootView: UsageGuidePanelView(language: language)
        )
        applyPanelBackground(to: hostingController.view)
        return hostingController
    }

    private func makeResourceManagerHostingController() -> NSHostingController<ResourceManagerWindowView> {
        let hostingController = NSHostingController(
            rootView: ResourceManagerWindowView(controller: self)
        )
        applyPanelBackground(to: hostingController.view)
        return hostingController
    }

    private func applyPanelBackground(to view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func restoreClipboardRetentionPolicy() {
        let policy = ResourceStore.clipboardRetentionPolicy()
        clipboardMaxItems = policy.maxItems
        clipboardMaxAgeDays = policy.maxAgeDays
    }

    private func restorePanelPreferences() {
        let preferences = PanelPreferences.load()
        panelBackgroundOpacity = preferences.backgroundOpacity
        panelDensity = preferences.density
        defaultPanelTab = preferences.defaultTab
        activeTab = preferences.defaultTab
    }

    private func restoreClipboardFilterPreferences() {
        let defaults = UserDefaults.standard
        let filterValues = defaults.stringArray(forKey: clipboardFilterOrderKey) ?? []
        let filters = filterValues.compactMap(ClipboardSmartFilter.init(rawValue:))
        clipboardFilterOrder = Self.sanitizedClipboardFilterOrder(filters)
        clipboardGroupOrder = Self.sanitizedClipboardGroupOrder(defaults.stringArray(forKey: clipboardGroupOrderKey) ?? [], groups: [])
    }

    private func saveClipboardFilterPreferences() {
        UserDefaults.standard.set(clipboardFilterOrder.map(\.rawValue), forKey: clipboardFilterOrderKey)
        UserDefaults.standard.set(clipboardGroupOrder, forKey: clipboardGroupOrderKey)
    }

    private func scheduleClipboardFilterPreferencesSave() {
        deferredClipboardFilterPreferencesSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveClipboardFilterPreferences()
        }
        deferredClipboardFilterPreferencesSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: workItem)
    }

    private func savePanelPreferences() {
        PanelPreferences.save(PanelPreferences(
            backgroundOpacity: panelBackgroundOpacity,
            density: panelDensity,
            defaultTab: defaultPanelTab
        ))
    }

    private func reconcileClipboardGroupOrder(with groups: [ClipboardBucket]) {
        let sanitized = Self.sanitizedClipboardGroupOrder(clipboardGroupOrder, groups: groups)
        guard sanitized != clipboardGroupOrder else {
            return
        }

        clipboardGroupOrder = sanitized
        saveClipboardFilterPreferences()
    }

    private func sortedClipboardGroupBuckets(_ groups: [ClipboardBucket]) -> [ClipboardBucket] {
        let rank = Dictionary(uniqueKeysWithValues: clipboardGroupOrder.enumerated().map { ($0.element, $0.offset) })
        return groups.sorted { lhs, rhs in
            let lhsIsDefault = Self.isDefaultClipboardGroup(lhs.name)
            let rhsIsDefault = Self.isDefaultClipboardGroup(rhs.name)
            if lhsIsDefault != rhsIsDefault {
                return !lhsIsDefault
            }

            let lhsRank = rank[lhs.name] ?? Int.max
            let rhsRank = rank[rhs.name] ?? Int.max
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }

            if lhs.count != rhs.count {
                return lhs.count > rhs.count
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func sanitizedClipboardFilterOrder(_ filters: [ClipboardSmartFilter]) -> [ClipboardSmartFilter] {
        var seen: Set<ClipboardSmartFilter> = []
        var result: [ClipboardSmartFilter] = []
        for filter in filters where !seen.contains(filter) {
            seen.insert(filter)
            result.append(filter)
        }

        for filter in ClipboardSmartFilter.allCases where !seen.contains(filter) {
            result.append(filter)
        }

        return result
    }

    private static func sanitizedClipboardGroupOrder(_ preferredOrder: [String], groups: [ClipboardBucket]) -> [String] {
        let existingNames = Set(groups.map(\.name))
        var seen: Set<String> = []
        var result: [String] = []

        for rawName in preferredOrder {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !seen.contains(name), (existingNames.isEmpty || existingNames.contains(name)) else {
                continue
            }
            seen.insert(name)
            result.append(name)
        }

        let missing = groups
            .map(\.name)
            .filter { !seen.contains($0) }
            .sorted { lhs, rhs in
                let lhsIsDefault = isDefaultClipboardGroup(lhs)
                let rhsIsDefault = isDefaultClipboardGroup(rhs)
                if lhsIsDefault != rhsIsDefault {
                    return !lhsIsDefault
                }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }

        return result + missing
    }

    private static func isDefaultClipboardGroup(_ group: String) -> Bool {
        group.localizedCaseInsensitiveCompare(ResourceType.clipboard.defaultGroup) == .orderedSame
    }

    private func updateClipboardRetentionPolicy(maxItems: Int, maxAgeDays: Int) {
        let policy = ClipboardRetentionPolicy(maxItems: maxItems, maxAgeDays: maxAgeDays).sanitized()
        guard policy.maxItems != clipboardMaxItems || policy.maxAgeDays != clipboardMaxAgeDays else {
            return
        }

        ResourceStore.saveClipboardRetentionPolicy(policy)
        clipboardMaxItems = policy.maxItems
        clipboardMaxAgeDays = policy.maxAgeDays
        applyClipboardRetentionPolicy(policy)
    }

    private func applyClipboardRetentionPolicy(_ policy: ClipboardRetentionPolicy) {
        do {
            let clipboardRecords = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            let retainedRecords = ResourceStore.trimClipboardItems(clipboardRecords, policy: policy)
            let retainedIDs = Set(retainedRecords.map(\.id))

            for item in clipboardRecords where !retainedIDs.contains(item.id) {
                _ = try resourceStore.delete(id: item.id)
            }

            refreshResources()
            pruneClipboardImageCache()
        } catch {
            lastMessage = language.message(.couldNotDeleteResource)
        }
    }

    private func pruneClipboardImageCache() {
        let retained = (try? resourceStore.list(type: .clipboard, query: nil, limit: nil)) ?? clipboardItems
        clipboardRecorder.pruneStoredImages(retainedItems: retained)
    }

    private func flash(count: Int) {
        stopStatusIconFlash()
        setStatusContent(isHot: unreadDingCount > 0)
    }

    private func stepFlash() {
        stopStatusIconFlash()
        setStatusContent(isHot: unreadDingCount > 0)
    }

    private func stopStatusIconFlash() {
        flashTimer?.invalidate()
        flashTimer = nil
        flashRemaining = 0
        flashIsHot = false
        isFlashing = false
        statusItem?.button?.contentTintColor = nil
    }

    private func incrementUnreadDingCount() {
        unreadDingCount = min(unreadDingCount + 1, 999)
        stopStatusIconFlash()
        setStatusContent(isHot: true)
    }

    private func setStatusContent(isHot: Bool) {
        guard let button = statusItem?.button else {
            return
        }

        button.image = Self.makeStatusImage(isHot: isHot)
        if unreadDingCount > 0 {
            let countText = unreadDingCount > 99 ? "99+" : "\(unreadDingCount)"
            button.attributedTitle = NSAttributedString(
                string: " \(countText)\u{2009}",
                attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
                ]
            )
            button.imagePosition = .imageLeading
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor(
                calibratedRed: 0.86,
                green: 0.45,
                blue: 0.20,
                alpha: 0.95
            ).cgColor
            button.layer?.cornerRadius = 12
            button.layer?.masksToBounds = true
            statusItem?.length = countText.count > 2 ? 65 : 55
        } else {
            button.title = ""
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
            button.layer?.backgroundColor = nil
            button.layer?.cornerRadius = 0
            button.layer?.masksToBounds = false
            button.wantsLayer = false
            statusItem?.length = NSStatusItem.squareLength
        }
    }

    static func makeStatusImage(isHot: Bool) -> NSImage {
        let resourceName = isHot ? "MenuBarIconHot" : "MenuBarIcon"

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            image.size = NSSize(width: 22, height: 22)
            return image
        }

        let fallback = NSImage(systemSymbolName: isHot ? "bell.and.waves.left.and.right.fill" : "bell.circle.fill", accessibilityDescription: "DingDong") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }

    static func makePanelLogoImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "PanelLogoIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            image.size = NSSize(width: 34, height: 34)
            return image
        }

        return makeStatusImage(isHot: false)
    }
}

extension StatusController: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === panelWindow else {
            return
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === panelWindow else {
            return
        }

        hideClipboardDetail()
        stopQuickPasteHotKeys()
    }
}

private final class StatusItemEventView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            onRightClick?()
        } else {
            onLeftClick?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}

private final class FocusableFloatingPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }

        super.keyDown(with: event)
    }
}
