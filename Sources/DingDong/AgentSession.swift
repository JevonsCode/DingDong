import Foundation

struct AgentSessionRequest: Codable, Equatable {
    var task: String
    var title: String?
    var summary: String?
    var currentStep: String?
    var nextActions: [String]?
    var resourceIDs: [String]?
    var source: String?
    var status: String?
    var tags: [String]?
    var pinned: Bool?

    static let group = "Agent Sessions"

    func makeResource(now: Date = Date()) throws -> ResourceItem {
        let cleanedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTask.isEmpty else {
            throw AgentSessionError.missingTask
        }

        let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? cleanedTask
        let cleanedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "active"
        let cleanedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Agent"
        let sessionTags = Self.uniqueTags(
            ["session", "status:\(cleanedStatus.lowercased())", "source:\(cleanedSource.lowercased())"] + (tags ?? [])
        )

        return ResourceItem(
            type: .knowledge,
            group: Self.group,
            title: cleanedTitle,
            content: markdown(task: cleanedTask, title: cleanedTitle, status: cleanedStatus, source: cleanedSource, now: now),
            tags: sessionTags,
            source: cleanedSource,
            pinned: pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
    }

    private func markdown(task: String, title: String, status: String, source: String, now: Date) -> String {
        var lines = [
            "# \(title)",
            "",
            "- Task: \(task)",
            "- Status: \(status)",
            "- Source: \(source)",
            "- Started: \(Self.timestamp(now))"
        ]

        if let summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("")
            lines.append("## Summary")
            lines.append(summary)
        }

        if let currentStep = currentStep?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("")
            lines.append("## Current Step")
            lines.append(currentStep)
        }

        appendSection("Next Actions", values: nextActions, to: &lines)
        appendSection("Resources", values: resourceIDs, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func appendSection(_ title: String, values: [String]?, to lines: inout [String]) {
        let cleaned = Self.cleanedList(values)
        guard !cleaned.isEmpty else {
            return
        }

        lines.append("")
        lines.append("## \(title)")
        for value in cleaned {
            lines.append("- \(value)")
        }
    }

    static func cleanedList(_ values: [String]?) -> [String] {
        (values ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func uniqueTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

struct AgentSessionUpdateRequest: Codable, Equatable {
    var status: String?
    var progress: String?
    var currentStep: String?
    var nextActions: [String]?
    var resourceIDs: [String]?
    var source: String?
    var pinned: Bool?

    var hasChanges: Bool {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || progress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || currentStep?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || !AgentSessionRequest.cleanedList(nextActions).isEmpty
            || !AgentSessionRequest.cleanedList(resourceIDs).isEmpty
            || source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || pinned != nil
    }

    func makeChanges(from item: ResourceItem, now: Date = Date()) throws -> ResourceUpdateRequest {
        guard hasChanges else {
            throw AgentSessionError.noChanges
        }

        let cleanedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let nextStatus = cleanedStatus ?? currentStatus(from: item.tags) ?? "active"
        let nextTags = updatedTags(item.tags, status: nextStatus, source: cleanedSource)
        let nextContent = appendCheckpoint(to: item.content, status: cleanedStatus, source: cleanedSource, now: now)

        return ResourceUpdateRequest(
            group: AgentSessionRequest.group,
            content: nextContent,
            tags: nextTags,
            source: cleanedSource ?? item.source,
            pinned: pinned
        )
    }

    private func appendCheckpoint(to content: String, status: String?, source: String?, now: Date) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines.append("")
        lines.append("## Checkpoint \(AgentSessionRequest.timestamp(now))")

        if let source {
            lines.append("- Source: \(source)")
        }

        if let status {
            lines.append("- Status: \(status)")
        }

        if let currentStep = currentStep?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("- Current Step: \(currentStep)")
        }

        if let progress = progress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            lines.append("")
            lines.append("### Progress")
            lines.append(progress)
        }

        appendSection("Next Actions", values: nextActions, to: &lines)
        appendSection("Resources", values: resourceIDs, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func appendSection(_ title: String, values: [String]?, to lines: inout [String]) {
        let cleaned = AgentSessionRequest.cleanedList(values)
        guard !cleaned.isEmpty else {
            return
        }

        lines.append("")
        lines.append("### \(title)")
        for value in cleaned {
            lines.append("- \(value)")
        }
    }

    private func updatedTags(_ tags: [String], status: String, source: String?) -> [String] {
        var nextTags = tags.filter {
            !$0.lowercased().hasPrefix("status:")
                && (source == nil || !$0.lowercased().hasPrefix("source:"))
        }
        nextTags.append("status:\(status.lowercased())")
        if let source {
            nextTags.append("source:\(source.lowercased())")
        }
        return AgentSessionRequest.uniqueTags(nextTags)
    }

    private func currentStatus(from tags: [String]) -> String? {
        tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .nilIfEmpty
    }
}

enum AgentSessionError: Error {
    case missingTask
    case noChanges
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
