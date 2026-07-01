import Foundation

struct AgentInstructionPack {
    static let defaultLimit = 6
    static let maxLimit = 12
    static let sessionLimit = 5

    static func object(
        resources: [ResourceItem],
        task: String,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        requestedLimit: Int?
    ) -> [String: Any] {
        let appliedLimit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let recommendations = AgentRecommendation.object(
            resources: resources,
            query: task,
            type: type,
            clipboardVisibility: clipboardVisibility,
            requestedLimit: appliedLimit
        )
        let recommendedResources = recommendations["recommendations"] as? [[String: Any]] ?? []
        let sessions = activeSessions(from: resources)

        return [
            "status": "ok",
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "Copyable startup instructions for local AI agents using DingDong shared resources.",
            "task": task,
            "type": type?.rawValue ?? "all",
            "privacy": clipboardVisibility.privacyObject,
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItemsMax": appliedLimit,
                "activeSessionsMax": sessionLimit
            ],
            "activeSessions": sessions.map(sessionObject),
            "recommendedResources": recommendedResources,
            "commandIDs": commandIDs,
            "recommendedFlow": recommendedFlow(task: task),
            "copyablePrompt": copyablePrompt(
                task: task,
                type: type,
                clipboardVisibility: clipboardVisibility,
                recommendedResources: recommendedResources,
                activeSessions: sessions
            )
        ]
    }

    static var commandIDs: [String] {
        [
            "agent-instructions",
            "agent-toolkit",
            "agent-presence",
            "start-session",
            "list-sessions",
            "update-session",
            "save-memory",
            "list-memories",
            "resolve-resource",
            "agent-context",
            "save-bundle",
            "save-handoff",
            "ding-complete"
        ]
    }

    private static func activeSessions(from resources: [ResourceItem]) -> [ResourceItem] {
        Array(
            resources
                .filter { $0.group == AgentSessionRequest.group && status(for: $0) == "active" }
                .sorted { lhs, rhs in
                    if lhs.pinned != rhs.pinned {
                        return lhs.pinned && !rhs.pinned
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
                .prefix(sessionLimit)
        )
    }

    private static func sessionObject(_ item: ResourceItem) -> [String: Any] {
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "title": item.title,
            "status": status(for: item),
            "source": item.source ?? "",
            "tags": item.tags,
            "pinned": item.pinned,
            "contentExcerpt": excerpt(item.content, limit: 700),
            "updatedAt": timestamp(item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        return object
    }

    private static func recommendedFlow(task: String) -> [String] {
        let encodedTask = encoded(task)
        return [
            "GET /agent/sessions?status=active&limit=10 before starting work.",
            "POST /agent/presence with the current agent source and task.",
            "POST /agent/session when starting multi-step work, or PATCH an active session if continuing one.",
            "GET /agent/memories?q=\(encodedTask)&limit=10 before work that may depend on prior preferences or lessons.",
            "GET /agent/resolve?q=\(encodedTask) when one best resource is enough.",
            "GET /agent/context?q=\(encodedTask)&limit=12 when broader local context is needed.",
            "POST /agent/memory when you learn a durable preference, rule, or lesson.",
            "POST /agent/bundle for reusable task context and POST /agent/handoff for resumable work.",
            "POST /ding only once for a user-visible task: immediately before the final answer, when the whole task is complete, blocked, or waiting for user attention. Do not call it for intermediate steps or partial subtasks."
        ]
    }

    private static func copyablePrompt(
        task: String,
        type: ResourceType?,
        clipboardVisibility: AgentClipboardVisibility,
        recommendedResources: [[String: Any]],
        activeSessions: [ResourceItem]
    ) -> String {
        let encodedTask = encoded(task)
        var lines = [
            "You have access to DingDong, a local macOS AI companion at http://127.0.0.1:8765.",
            "Task: \(task)",
            "",
            "Before acting:",
            "1. Check active sessions:",
            "   curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/sessions?status=active&limit=10'",
            "2. Register your presence:",
            "   curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/presence -H 'Content-Type: application/json' -d '{\"source\":\"Agent\",\"status\":\"active\",\"task\":\"\(escaped(task))\"}'",
            "3. Create or update a session for multi-step work:",
            "   curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/session -H 'Content-Type: application/json' -d '{\"task\":\"\(escaped(task))\",\"source\":\"Agent\",\"status\":\"active\"}'",
            "4. Read durable memories for this task:",
            "   curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/memories?q=\(encodedTask)&limit=10'",
            "",
            "Use shared resources:",
            "   curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/resolve?q=\(encodedTask)\(typeQuery(type))'",
            "   curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/context?q=\(encodedTask)&limit=12'",
            "",
            "Clipboard privacy:",
            clipboardVisibility.includeClipboard
                ? "- Clipboard records may be included because includeClipboard=true was requested."
                : "- Clipboard records are excluded by default; only request includeClipboard=true when the user explicitly wants clipboard-aware work.",
            clipboardVisibility.includeSensitiveClipboard
                ? "- Sensitive clipboard records may be included because includeSensitiveClipboard=true was requested."
                : "- Sensitive clipboard records stay hidden unless the user explicitly asks for sensitive clipboard access.",
            ""
        ]

        if !activeSessions.isEmpty {
            lines.append("Active sessions to consider:")
            for session in activeSessions {
                lines.append("- \(session.title) [\(session.id.uuidString)]")
            }
            lines.append("")
        }

        if !recommendedResources.isEmpty {
            lines.append("Recommended resource ids:")
            for resource in recommendedResources.prefix(5) {
                let id = resource["id"] as? String ?? ""
                let title = resource["title"] as? String ?? "Untitled"
                let resourceType = resource["type"] as? String ?? "resource"
                lines.append("- \(title) (\(resourceType)): \(id)")
            }
            lines.append("")
        }

        lines.append("Only once, immediately before the final answer for the whole user-visible task, when finished, blocked, or needing user attention:")
        lines.append("   curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/ding -H 'Content-Type: application/json' -d '{\"message\":\"Agent task complete\",\"source\":\"Agent\",\"sound\":\"random\",\"flashCount\":10}'")

        return lines.joined(separator: "\n")
    }

    private static func status(for item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    private static func typeQuery(_ type: ResourceType?) -> String {
        type.map { "&type=\($0.rawValue)" } ?? ""
    }

    private static func encoded(_ task: String) -> String {
        task.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? task
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func excerpt(_ content: String, limit: Int) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return String(trimmed.prefix(limit)) + "\n[truncated]"
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
