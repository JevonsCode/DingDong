import Foundation

struct AgentHandoffRequest: Codable, Equatable {
    var title: String
    var summary: String
    var nextSteps: [String]?
    var blockers: [String]?
    var artifacts: [String]?
    var source: String?
    var status: String?
    var tags: [String]?
    var pinned: Bool?

    func makeResource(now: Date = Date()) throws -> ResourceItem {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, !cleanedSummary.isEmpty else {
            throw AgentHandoffError.missingRequiredFields
        }

        let cleanedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "open"
        let cleanedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Agent"
        let handoffTags = Self.uniqueTags(
            ["handoff", "status:\(cleanedStatus.lowercased())", "source:\(cleanedSource.lowercased())"] + (tags ?? [])
        )

        return ResourceItem(
            type: .knowledge,
            group: Self.group,
            title: cleanedTitle,
            content: markdown(title: cleanedTitle, summary: cleanedSummary, status: cleanedStatus, source: cleanedSource),
            tags: handoffTags,
            source: cleanedSource,
            pinned: pinned ?? false,
            createdAt: now,
            updatedAt: now
        )
    }

    static let group = "Agent Handoffs"

    private func markdown(title: String, summary: String, status: String, source: String) -> String {
        var lines = [
            "# \(title)",
            "",
            "- Status: \(status)",
            "- Source: \(source)",
            "",
            "## Summary",
            summary
        ]

        appendSection("Next Steps", values: nextSteps, to: &lines)
        appendSection("Blockers", values: blockers, to: &lines)
        appendSection("Artifacts", values: artifacts, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func appendSection(_ title: String, values: [String]?, to lines: inout [String]) {
        let cleaned = (values ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else {
            return
        }

        lines.append("")
        lines.append("## \(title)")
        for value in cleaned {
            lines.append("- \(value)")
        }
    }

    private static func uniqueTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}

enum AgentHandoffError: Error {
    case missingRequiredFields
    case noChanges
}

struct AgentHandoffUpdateRequest: Codable, Equatable {
    var status: String?
    var progress: String?
    var source: String?
    var pinned: Bool?

    var hasChanges: Bool {
        status?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || progress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || pinned != nil
    }

    func makeChanges(from item: ResourceItem, now: Date = Date()) throws -> ResourceUpdateRequest {
        guard hasChanges else {
            throw AgentHandoffError.noChanges
        }

        let cleanedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanedSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let cleanedProgress = progress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let nextStatus = cleanedStatus ?? currentStatus(from: item.tags) ?? "open"
        let nextSource = cleanedSource ?? item.source
        let nextTags = updatedTags(item.tags, status: nextStatus, source: cleanedSource)
        let nextContent = appendProgress(cleanedProgress, to: item.content, status: cleanedStatus, source: cleanedSource, now: now)

        return ResourceUpdateRequest(
            group: AgentHandoffRequest.group,
            content: nextContent,
            tags: nextTags,
            source: nextSource,
            pinned: pinned
        )
    }

    private func updatedTags(_ tags: [String], status: String, source: String?) -> [String] {
        var nextTags = tags.filter { !$0.lowercased().hasPrefix("status:") }
        nextTags.append("status:\(status.lowercased())")
        if let source {
            nextTags.removeAll { $0.lowercased().hasPrefix("source:") }
            nextTags.append("source:\(source.lowercased())")
        }
        return uniqueTags(nextTags)
    }

    private func appendProgress(_ progress: String?, to content: String, status: String?, source: String?, now: Date) -> String {
        var lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        if let status {
            lines.append("")
            lines.append("## Status Update")
            lines.append("- Status: \(status)")
        }

        if let progress {
            if !lines.contains("## Progress") {
                lines.append("")
                lines.append("## Progress")
            }

            var note = "- [\(Self.timestamp(now))]"
            if let source {
                note += " \(source):"
            }
            note += " \(progress)"
            lines.append(note)
        }

        return lines.joined(separator: "\n")
    }

    private func currentStatus(from tags: [String]) -> String? {
        tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .nilIfEmpty
    }

    private func uniqueTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        return tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
