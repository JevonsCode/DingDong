import AppKit
import Foundation

struct NotificationRouter {
    var handleDing: (DingRequest) -> Void
    var handleShowPanel: ((CompanionTab?) -> Void)? = nil
    var handleClipboardMonitoring: ((Bool) -> Void)? = nil
    var resourceStore: ResourceStoreProtocol? = nil
    var clipboardRecorder: ClipboardRecorder? = nil
    var agentEventStore: AgentEventStore? = nil
    var agentPresenceStore: AgentPresenceStore? = nil
    var apiEndpoint = AgentAPIEndpoint()
    var knowledgeIndexer = KnowledgeIndexer()
    var libraryImporter = LibraryImporter()
    var writePasteboard: (String) -> Bool = Self.writeSystemPasteboard
    var clipboardMonitoringState: () -> Bool = Self.defaultClipboardMonitoringState

    func route(_ request: HTTPRequest) -> HTTPResponse {
        let route = ParsedRoute(path: request.path)

        switch (request.method, route.path) {
        case ("GET", "/health"):
            return .json(object: ["status": "ok", "service": "DingDong"])

        case ("GET", "/agent/templates"):
            return HTTPResponse.jsonObject([
                "status": "ok",
                "templates": AgentCommandTemplate.defaults.map(AgentCommandTemplateJSON.object)
            ])

        case ("GET", "/agent/capabilities"):
            return HTTPResponse.jsonObject(AgentCapabilityManifest.object(apiEndpoint: apiEndpoint).merging(["status": "ok"]) { current, _ in current })

        case ("GET", "/agent/manifest"), ("GET", "/.well-known/dingdong-agent.json"):
            return HTTPResponse.jsonObject(AgentDiscoveryManifest.object(apiEndpoint: apiEndpoint).merging(["status": "ok"]) { current, _ in current })

        case ("GET", "/system/status"):
            return systemStatus()

        case ("GET", "/agent/toolkit"):
            return agentToolkit()

        case ("GET", "/agent/startup"):
            return agentStartup(query: route.query)

        case ("GET", "/agent/bridge"):
            return agentBridge(query: route.query)

        case ("GET", "/agent/prepare"):
            return agentPrepare(query: route.query)

        case ("GET", "/agent/workbench"):
            return agentWorkbench(query: route.query)

        case ("GET", "/agent/instructions"):
            return agentInstructions(query: route.query)

        case ("GET", "/agent/presence"):
            return listAgentPresence(query: route.query)

        case ("POST", "/agent/presence"):
            return updateAgentPresence(request.body)

        case ("POST", "/agent/session"):
            return createAgentSession(request.body)

        case ("PATCH", let path) where path.hasPrefix("/agent/session/"):
            return updateAgentSession(path: path, body: request.body)

        case ("GET", "/agent/sessions"):
            return listAgentSessions(query: route.query)

        case ("POST", "/agent/memory"):
            return createAgentMemory(request.body)

        case ("GET", "/agent/memories"):
            return listAgentMemories(query: route.query)

        case ("GET", "/agent/brief"):
            return agentBrief(query: route.query)

        case ("GET", "/agent/recommend"):
            return agentRecommend(query: route.query)

        case ("GET", "/agent/resolve"):
            return agentResolve(query: route.query)

        case ("GET", let path) where path.hasPrefix("/agent/resource/"):
            return agentResource(path: path, query: route.query)

        case ("POST", "/agent/bundle"):
            return createAgentBundle(request.body)

        case ("POST", "/agent/handoff"):
            return createAgentHandoff(request.body)

        case ("PATCH", let path) where path.hasPrefix("/agent/handoff/"):
            return updateAgentHandoff(path: path, body: request.body)

        case ("GET", "/agent/handoffs"):
            return listAgentHandoffs(query: route.query)

        case ("GET", "/agent/context"):
            return agentContext(query: route.query)

        case ("GET", "/events"):
            return listEvents(limit: route.query["limit"].flatMap(Int.init))

        case ("GET", "/ding"), ("POST", "/ding"):
            do {
                let dingRequest = try DingRequestParser.parse(request.body)
                agentEventStore?.record(dingRequest)
                handleDing(dingRequest)
                return .json(object: ["status": "triggered", "message": dingRequest.message])
            } catch {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "Invalid JSON body"
                ])
            }

        case ("GET", "/library"):
            return listResources(
                typeName: route.query["type"],
                query: route.query["q"],
                limit: route.query["limit"].flatMap(Int.init)
            )

        case ("GET", "/library/groups"):
            return listResourceGroups(typeName: route.query["type"])

        case ("GET", "/library/export"):
            return exportResources(query: route.query)

        case ("POST", "/library"):
            return addResource(request.body)

        case ("POST", "/library/import"):
            return importResources(request.body)

        case ("POST", "/library/seed-defaults"):
            return seedDefaultResources()

        case ("GET", "/knowledge/index"):
            return indexKnowledge(idValue: route.query["id"], pathValue: route.query["path"], limitValue: route.query["limit"])

        case ("PATCH", let path) where path.hasPrefix("/library/"):
            return updateResource(path: path, body: request.body)

        case ("DELETE", let path) where path.hasPrefix("/library/"):
            return deleteResource(path: path)

        case ("POST", "/clipboard/capture"):
            return captureClipboard()

        case ("GET", "/clipboard/overview"):
            return clipboardOverview()

        case ("GET", "/clipboard/insights"):
            return clipboardInsights(query: route.query)

        case ("GET", "/clipboard/digest"):
            return clipboardDigest(query: route.query)

        case ("POST", "/clipboard/collect"):
            return collectClipboard(request.body)

        case ("GET", "/clipboard/history"):
            return clipboardHistory(query: route.query)

        case ("GET", "/clipboard/snippets"):
            return clipboardSnippets(query: route.query)

        case ("GET", "/clipboard/groups"):
            return clipboardGroups()

        case ("PATCH", let path) where path.hasPrefix("/clipboard/"):
            return updateClipboard(path: path, body: request.body)

        case ("POST", let path) where path.hasPrefix("/clipboard/promote/"):
            return promoteClipboard(path: path, body: request.body)

        case ("POST", let path) where path.hasPrefix("/clipboard/restore/"):
            return restoreClipboard(path: path)

        case ("POST", let path) where path.hasPrefix("/clipboard/snippet/"):
            return restoreClipboardSnippet(path: path, query: route.query)

        case ("POST", "/clipboard/monitor"):
            return setClipboardMonitoring(enabledValue: route.query["enabled"], body: request.body)

        case ("GET", "/ui/show"), ("POST", "/ui/show"):
            return showUI(query: route.query)

        default:
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "Route not found"
            ])
        }
    }

    static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "on":
            true
        case "false", "0", "no", "off":
            false
        default:
            nil
        }
    }

    static func defaultClipboardMonitoringState() -> Bool {
        AppPreferences.shared.isClipboardMonitoringEnabled
    }

    static func parseClipboardVisibility(_ query: [String: String]) throws -> AgentClipboardVisibility {
        let includeClipboard = try parseBoolQuery(query, key: "includeClipboard") ?? false
        let includeSensitiveClipboard = try parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        return AgentClipboardVisibility(
            includeClipboard: includeClipboard,
            includeSensitiveClipboard: includeSensitiveClipboard
        )
    }

    static func parseBoolQuery(_ query: [String: String], key: String) throws -> Bool? {
        guard let rawValue = query[key] else {
            return nil
        }

        guard let value = parseBool(rawValue) else {
            throw ClipboardVisibilityError.invalidBoolean
        }

        return value
    }

    static func invalidClipboardVisibilityResponse() -> HTTPResponse {
        .json(statusCode: 400, reason: "Bad Request", object: [
            "status": "error",
            "message": "includeClipboard and includeSensitiveClipboard must be true or false"
        ])
    }

    static func handoffStatus(_ item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    static func handoffStatusCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[handoffStatus(item), default: 0] += 1
        }
        return counts
    }

    static func sessionStatus(_ item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    static func sessionStatusCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[sessionStatus(item), default: 0] += 1
        }
        return counts
    }

    static func memoryKindCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[AgentMemoryRequest.kind(from: item), default: 0] += 1
        }
        return counts
    }

    static func resourceMatches(_ item: ResourceItem, query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return item.title.lowercased().contains(lowercasedQuery)
            || item.content.lowercased().contains(lowercasedQuery)
            || item.group.lowercased().contains(lowercasedQuery)
            || item.tags.contains { $0.lowercased().contains(lowercasedQuery) }
    }

    static func encodedQuery(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    static func contentTooLargeResponse(maxCharacters: Int) -> HTTPResponse {
        .json(statusCode: 413, reason: "Payload Too Large", object: [
            "status": "error",
            "message": "content exceeds \(maxCharacters) characters"
        ])
    }

    static func parseMonitorBody(_ body: Data) -> Bool? {
        guard !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let value = object["enabled"] else {
            return nil
        }

        if let bool = value as? Bool {
            return bool
        }

        if let string = value as? String {
            return parseBool(string)
        }

        return nil
    }

    func resourceID(from path: String) -> UUID? {
        let prefix = "/library/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func clipboardID(from path: String) -> UUID? {
        let prefix = "/clipboard/promote/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func clipboardRestoreID(from path: String) -> UUID? {
        let prefix = "/clipboard/restore/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func clipboardSnippetAlias(from path: String) -> String? {
        let prefix = "/clipboard/snippet/"
        let suffix = "/restore"
        guard path.hasPrefix(prefix), path.hasSuffix(suffix) else {
            return nil
        }

        let rawAlias = String(path.dropFirst(prefix.count).dropLast(suffix.count))
        guard !rawAlias.isEmpty, !rawAlias.contains("/") else {
            return nil
        }

        return Self.normalizedClipboardAlias(rawAlias)
    }

    func clipboardRecordID(from path: String) -> UUID? {
        let prefix = "/clipboard/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty,
              !rawID.contains("/"),
              rawID != "history",
              rawID != "groups",
              rawID != "overview",
              rawID != "capture",
              rawID != "monitor",
              rawID != "snippets",
              rawID != "snippet" else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func handoffID(from path: String) -> UUID? {
        let prefix = "/agent/handoff/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func sessionID(from path: String) -> UUID? {
        let prefix = "/agent/session/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    func agentResourceID(from path: String) -> UUID? {
        let prefix = "/agent/resource/"
        guard path.hasPrefix(prefix) else {
            return nil
        }

        let rawID = String(path.dropFirst(prefix.count))
        guard !rawID.isEmpty, !rawID.contains("/") else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    static func writeSystemPasteboard(_ content: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(content, forType: .string)
    }

    static func parsePromotionRequest(_ body: Data) throws -> ClipboardPromotionRequest {
        guard !body.isEmpty else {
            return ClipboardPromotionRequest()
        }

        return try JSONDecoder().decode(ClipboardPromotionRequest.self, from: body)
    }

    static func parseAgentPresenceRequest(_ body: Data) throws -> AgentPresenceRequest {
        guard !body.isEmpty else {
            throw AgentPresenceError.missingSource
        }

        return try JSONDecoder().decode(AgentPresenceRequest.self, from: body)
    }
}

struct ParsedRoute {
    var path: String
    var query: [String: String]

    init(path rawPath: String) {
        guard var components = URLComponents(string: rawPath) else {
            path = rawPath
            query = [:]
            return
        }

        path = components.path
        query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        components.queryItems = nil
    }
}

enum ResourceJSON {
    static func object(_ item: ResourceItem) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var object: [String: Any] = [
            "id": item.id.uuidString,
            "type": item.type.rawValue,
            "group": item.group,
            "title": item.title,
            "content": item.content,
            "tags": item.tags,
            "pinned": item.pinned,
            "createdAt": formatter.string(from: item.createdAt),
            "updatedAt": formatter.string(from: item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        return object
    }
}

enum ClipboardHistoryJSON {
    static func object(_ item: ResourceItem, includeContent: Bool, aliases: [String]? = nil) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var object: [String: Any] = [
            "id": item.id.uuidString,
            "title": item.title,
            "group": item.group,
            "classification": classification(for: item),
            "tags": item.tags,
            "pinned": item.pinned,
            "sensitive": item.isSensitiveClipboard,
            "contentCharacterCount": item.content.count,
            "createdAt": formatter.string(from: item.createdAt),
            "updatedAt": formatter.string(from: item.updatedAt)
        ]

        if let source = item.source {
            object["source"] = source
        }

        if includeContent {
            object["content"] = item.content
        }

        if let aliases {
            object["aliases"] = aliases
        }

        return object
    }

    static func classification(for item: ResourceItem) -> String {
        for candidate in ["url", "command", "code", "json", "path", "email", "sensitive", "text"] {
            if item.tags.contains(candidate) {
                return candidate
            }
        }
        return "unknown"
    }
}

enum ResourceGroupJSON {
    static func object(_ summary: LibraryGroupSummary) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [
            "type": summary.type.rawValue,
            "group": summary.group,
            "count": summary.count,
            "pinnedCount": summary.pinnedCount,
            "latestUpdatedAt": formatter.string(from: summary.latestUpdatedAt)
        ]
    }
}

enum KnowledgeIndexJSON {
    static func object(_ entry: KnowledgeIndexEntry) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var object: [String: Any] = [
            "path": entry.path,
            "name": entry.name,
            "relativePath": entry.relativePath,
            "byteCount": entry.byteCount,
            "summary": entry.summary
        ]

        if let modifiedAt = entry.modifiedAt {
            object["modifiedAt"] = formatter.string(from: modifiedAt)
        }

        return object
    }
}

enum AgentCommandTemplateJSON {
    static func object(_ template: AgentCommandTemplate) -> [String: Any] {
        [
            "id": template.id,
            "title": template.title,
            "summary": template.summary,
            "command": template.command
        ]
    }
}

enum AgentEventJSON {
    static func object(_ event: AgentEvent) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return [
            "id": event.id.uuidString,
            "message": event.message,
            "source": event.source,
            "sound": event.sound.rawValue,
            "createdAt": formatter.string(from: event.createdAt)
        ]
    }
}

enum AgentPresenceJSON {
    static func object(_ record: AgentPresenceRecord) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var object: [String: Any] = [
            "source": record.source,
            "status": record.status,
            "capabilities": record.capabilities,
            "updatedAt": formatter.string(from: record.updatedAt)
        ]

        if let task = record.task {
            object["task"] = task
        }

        return object
    }
}

enum KnowledgeIndexRouteError: Error {
    case missingInput
    case invalidID
    case notFound
    case notKnowledge
}

enum ClipboardVisibilityError: Error {
    case invalidBoolean
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
