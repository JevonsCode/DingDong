import Foundation

enum AgentBridgeExpansion: String {
    case none
    case prompts
    case all

    static let defaultValue: AgentBridgeExpansion = .prompts

    init(queryValue: String?) {
        guard let value = queryValue?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              let expansion = AgentBridgeExpansion(rawValue: value) else {
            self = Self.defaultValue
            return
        }

        self = expansion
    }
}

struct AgentBridgePack {
    static let defaultLimit = 20
    static let maxLimit = 60
    static let excerptLimit = 320
    static let inlinePromptCharacterLimit = 1_200

    static func object(
        resources: [ResourceItem],
        task: String?,
        source: String?,
        requestedLimit: Int?,
        expansion: AgentBridgeExpansion = .defaultValue
    ) -> [String: Any] {
        let limit = requestedLimit.map { min(max(0, $0), maxLimit) } ?? defaultLimit
        let normalizedTask = task?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let bridgeResources = resources
            .filter(isBridgeResource)
            .filter { item in item.pinned || matches(item, query: normalizedTask) }
            .sorted { lhs, rhs in
                if lhs.pinned != rhs.pinned {
                    return lhs.pinned && !rhs.pinned
                }
                if lhs.type != rhs.type {
                    return typeRank(lhs.type) < typeRank(rhs.type)
                }
                return lhs.updatedAt > rhs.updatedAt
            }

        let limited = Array(bridgeResources.prefix(limit))

        return [
            "status": "ok",
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "Dynamic agent bridge config. Keep only this bridge in agent global setup; keep prompts, skills, and MCP references in DingDong.",
            "mode": "minimal-bridge-summary",
            "source": source?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Agent",
            "task": normalizedTask ?? "",
            "adapterInstructions": [
                "Fetch this bridge config at the start of each meaningful task or session.",
                "Default bridge responses are summary-first. Short prompt content may be inlined; skills and MCP references are summaries until fetched by id.",
                "Apply active.prompts with contentIncluded=true as DingDong-maintained user instructions for the current turn.",
                "Use active.skills as procedural guidance summaries. Fetch full skill text with GET /agent/resource/{id} only when the task needs that skill.",
                "Use active.mcpServers as MCP setup/routing summaries. Fetch full MCP details with GET /agent/resource/{id} only before setup or execution.",
                "Use expand=all only for explicit debugging or manual export, not as the default agent startup path.",
                "Do not persist returned prompt, skill, or MCP contents into the agent's global prompt; fetch fresh config from DingDong instead.",
                "Clipboard content is not included in this bridge. Request clipboard APIs only when the user explicitly asks for clipboard-aware work."
            ],
            "contentPolicy": [
                "defaultExpansion": AgentBridgeExpansion.defaultValue.rawValue,
                "requestedExpansion": expansion.rawValue,
                "summaryOnlyDefault": true,
                "inlinePromptCharacterLimit": inlinePromptCharacterLimit,
                "excerptCharacters": excerptLimit,
                "fullResourceEndpoint": "/agent/resource/{id}"
            ],
            "limits": [
                "requestedItems": requestedLimit ?? defaultLimit,
                "returnedItemsMax": limit,
                "requestedExpansion": expansion.rawValue,
                "activeOnly": "pinned resources plus task matches",
                "supportedTypes": ["prompt", "skill", "mcp"]
            ],
            "active": [
                "prompts": limited.filter { $0.type == .prompt }.map { resourceObject($0, expansion: expansion) },
                "skills": limited.filter { $0.type == .skill }.map { resourceObject($0, expansion: expansion) },
                "mcpServers": limited.filter { $0.type == .mcp }.map { resourceObject($0, expansion: expansion) }
            ],
            "counts": [
                "prompts": limited.filter { $0.type == .prompt }.count,
                "skills": limited.filter { $0.type == .skill }.count,
                "mcpServers": limited.filter { $0.type == .mcp }.count,
                "total": limited.count
            ],
            "nextActions": [
                "Register presence with POST /agent/presence for non-trivial work.",
                "Call GET /agent/context?task=TASK for broader task-scoped resources when needed.",
                "Call GET /agent/resource/{id} to load the full content for a selected skill, prompt, or MCP reference.",
                "Call POST /ding when work is complete, blocked, or needs user attention."
            ]
        ]
    }

    private static func isBridgeResource(_ item: ResourceItem) -> Bool {
        item.type == .prompt || item.type == .skill || item.type == .mcp
    }

    private static func matches(_ item: ResourceItem, query: String?) -> Bool {
        guard let query, !query.isEmpty else {
            return false
        }
        let tokens = query
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            return false
        }

        let haystack = ([item.title, item.group, item.content] + item.tags)
            .joined(separator: " ")
            .lowercased()
        return tokens.contains { haystack.contains($0) }
    }

    private static func typeRank(_ type: ResourceType) -> Int {
        switch type {
        case .prompt:
            0
        case .skill:
            1
        case .mcp:
            2
        case .knowledge:
            3
        case .clipboard:
            4
        }
    }

    private static func resourceObject(_ item: ResourceItem, expansion: AgentBridgeExpansion) -> [String: Any] {
        let contentIncluded = shouldIncludeContent(for: item, expansion: expansion)
        var object: [String: Any] = [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "tags": item.tags,
            "pinned": item.pinned,
            "contentAvailable": true,
            "contentIncluded": contentIncluded,
            "contentCharacterCount": item.content.count,
            "contentExcerpt": excerpt(item.content, limit: excerptLimit),
            "detailURL": "/agent/resource/\(item.id.uuidString)",
            "updatedAt": timestamp(item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        if contentIncluded {
            object["content"] = item.content
        }

        return object
    }

    private static func shouldIncludeContent(for item: ResourceItem, expansion: AgentBridgeExpansion) -> Bool {
        switch expansion {
        case .none:
            false
        case .prompts:
            item.type == .prompt && item.content.count <= inlinePromptCharacterLimit
        case .all:
            true
        }
    }

    private static func excerpt(_ content: String, limit: Int) -> String {
        let trimmed = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        guard trimmed.count > limit else {
            return trimmed
        }

        return "\(trimmed.prefix(limit))..."
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
