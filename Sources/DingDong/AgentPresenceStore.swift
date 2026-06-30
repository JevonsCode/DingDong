import Foundation

struct AgentPresenceRecord: Equatable, Identifiable {
    var source: String
    var status: String
    var task: String?
    var capabilities: [String]
    var updatedAt: Date

    var id: String {
        source
    }
}

struct AgentPresenceRequest: Codable, Equatable {
    var source: String
    var status: String?
    var task: String?
    var capabilities: [String]?

    func makeRecord(now: Date = Date()) throws -> AgentPresenceRecord {
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            throw AgentPresenceError.missingSource
        }

        let status = (status ?? "active")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty ?? "active"
        let task = task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let capabilities = (capabilities ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return AgentPresenceRecord(
            source: source,
            status: status,
            task: task,
            capabilities: capabilities,
            updatedAt: now
        )
    }
}

enum AgentPresenceError: Error {
    case missingSource
}

final class AgentPresenceStore: @unchecked Sendable {
    static let maxAgents = 40
    static let defaultActiveWithin: TimeInterval = 15 * 60

    private let queue = DispatchQueue(label: "dingdong.agent-presence")
    private var recordsBySource: [String: AgentPresenceRecord] = [:]

    @discardableResult
    func upsert(_ request: AgentPresenceRequest, now: Date = Date()) throws -> AgentPresenceRecord {
        let record = try request.makeRecord(now: now)
        return queue.sync {
            recordsBySource[record.source.lowercased()] = record
            trimIfNeeded()
            return record
        }
    }

    func list(activeWithin: TimeInterval? = defaultActiveWithin, limit: Int? = nil, now: Date = Date()) -> [AgentPresenceRecord] {
        queue.sync {
            var records = Array(recordsBySource.values)
            if let activeWithin {
                let cutoff = now.addingTimeInterval(-activeWithin)
                records = records.filter { $0.updatedAt >= cutoff }
            }

            let sorted = records.sorted { lhs, rhs in
                lhs.updatedAt > rhs.updatedAt
            }
            let cappedLimit = limit.map { max(0, min($0, Self.maxAgents)) }
            return cappedLimit.map { Array(sorted.prefix($0)) } ?? sorted
        }
    }

    private func trimIfNeeded() {
        guard recordsBySource.count > Self.maxAgents else {
            return
        }

        let keep = Set(
            recordsBySource.values
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(Self.maxAgents)
                .map { $0.source.lowercased() }
        )
        recordsBySource = recordsBySource.filter { keep.contains($0.key) }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
