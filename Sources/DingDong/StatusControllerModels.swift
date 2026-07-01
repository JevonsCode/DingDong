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

final class NotificationObserverBox: @unchecked Sendable {
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
