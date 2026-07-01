import AppKit
import Foundation

extension NotificationRouter {
    func agentToolkit() -> HTTPResponse {
        do {
            let resources = try resourceStore?.list(type: nil, query: nil, limit: nil) ?? []
            return HTTPResponse.jsonObject(
                AgentToolkit.object(resources: resources, libraryAvailable: resourceStore != nil, apiEndpoint: apiEndpoint)
                    .merging(["status": "ok"]) { current, _ in current }
            )
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent toolkit"
            ])
        }
    }

    func systemStatus() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(SystemStatus.object(
                resources: resources,
                recentEvents: agentEventStore?.list(limit: AgentEventStore.maxEvents) ?? [],
                activeAgents: agentPresenceStore?.list(limit: AgentPresenceStore.maxAgents) ?? [],
                clipboardMonitoringEnabled: clipboardMonitoringState(),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build system status"
            ])
        }
    }

    func agentStartup(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        let taskQuery = (query["q"] ?? query["task"])?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            let matchingResources = try resourceStore.list(type: type, query: taskQuery, limit: nil)
            return HTTPResponse.jsonObject(AgentStartupPack.object(
                resources: resources,
                matchingResources: matchingResources,
                events: agentEventStore?.list(limit: AgentBrief.eventLimit) ?? [],
                activeAgents: agentPresenceStore?.list(limit: 8) ?? [],
                query: taskQuery,
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: query["limit"].flatMap(Int.init),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent startup pack"
            ])
        }
    }

    func agentBridge(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let task = (query["q"] ?? query["task"])?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        let source = query["source"]?
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(AgentBridgePack.object(
                resources: resources,
                task: task,
                source: source,
                requestedLimit: query["limit"].flatMap(Int.init),
                expansion: AgentBridgeExpansion(queryValue: query["expand"]),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent bridge config"
            ])
        }
    }

    func agentPrepare(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let task = (query["q"] ?? query["task"])?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !task.isEmpty else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "q or task is required"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        let includeSensitiveClipboardInsights: Bool
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
            includeSensitiveClipboardInsights = try Self.parseBoolQuery(query, key: "includeSensitiveClipboardInsights") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeClipboard, includeSensitiveClipboard, and includeSensitiveClipboardInsights must be true or false"
            ])
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(AgentPreparePack.object(
                resources: resources,
                events: agentEventStore?.list(limit: AgentBrief.eventLimit) ?? [],
                activeAgents: agentPresenceStore?.list(limit: 8) ?? [],
                task: task,
                type: type,
                clipboardVisibility: clipboardVisibility,
                clipboardInsightsIncludeSensitive: includeSensitiveClipboardInsights,
                clipboardMonitoringEnabled: clipboardMonitoringState(),
                requestedLimit: query["limit"].flatMap(Int.init),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent prepare pack"
            ])
        }
    }

    func agentInstructions(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let task = (query["q"] ?? query["task"])?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !task.isEmpty else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "q or task is required"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(AgentInstructionPack.object(
                resources: resources,
                task: task,
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: query["limit"].flatMap(Int.init),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent instructions"
            ])
        }
    }

    func listAgentPresence(query: [String: String]) -> HTTPResponse {
        guard let agentPresenceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Agent presence is not available"
            ])
        }

        let limit = query["limit"].flatMap(Int.init)
        let activeWithin = query["activeWithin"].flatMap(TimeInterval.init) ?? AgentPresenceStore.defaultActiveWithin
        let records = agentPresenceStore.list(activeWithin: activeWithin, limit: limit)

        return HTTPResponse.jsonObject([
            "status": "ok",
            "activeWithinSeconds": Int(activeWithin),
            "count": records.count,
            "agents": records.map(AgentPresenceJSON.object)
        ])
    }

    func agentWorkbench(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            let activeAgents = agentPresenceStore?.list(activeWithin: 900, limit: AgentPresenceStore.maxAgents) ?? []
            return HTTPResponse.jsonObject(AgentWorkbench.object(
                resources: resources,
                activeAgents: activeAgents,
                task: query["task"],
                requestedLimit: query["limit"].flatMap(Int.init),
                apiEndpoint: apiEndpoint
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent workbench"
            ])
        }
    }

    func updateAgentPresence(_ body: Data) -> HTTPResponse {
        guard let agentPresenceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Agent presence is not available"
            ])
        }

        do {
            let request = try Self.parseAgentPresenceRequest(body)
            let record = try agentPresenceStore.upsert(request)
            return HTTPResponse.jsonObject([
                "status": "recorded",
                "agent": AgentPresenceJSON.object(record)
            ])
        } catch AgentPresenceError.missingSource {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "source is required"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid presence JSON body"
            ])
        }
    }

    func agentBrief(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(AgentBrief.object(
                resources: resources,
                events: agentEventStore?.list(limit: AgentBrief.eventLimit) ?? [],
                activeAgents: agentPresenceStore?.list(limit: 8) ?? [],
                clipboardVisibility: clipboardVisibility
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent brief"
            ])
        }
    }

    func agentRecommend(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let taskQuery = (query["q"] ?? query["task"])?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskQuery.isEmpty else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "q or task is required"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            return HTTPResponse.jsonObject(AgentRecommendation.object(
                resources: resources,
                query: taskQuery,
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: query["limit"].flatMap(Int.init)
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent recommendations"
            ])
        }
    }

    func agentResolve(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let taskQuery = (query["q"] ?? query["task"])?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskQuery.isEmpty else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "q or task is required"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            guard let object = AgentResourceResolve.object(
                resources: resources,
                query: taskQuery,
                type: type,
                clipboardVisibility: clipboardVisibility
            ) else {
                return HTTPResponse.jsonObject(statusCode: 404, reason: "Not Found", [
                    "status": "not_found",
                    "message": "No matching resource found",
                    "query": taskQuery,
                    "type": type?.rawValue ?? "all",
                    "privacy": clipboardVisibility.privacyObject
                ])
            }

            return HTTPResponse.jsonObject(object)
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not resolve agent resource"
            ])
        }
    }

    func createAgentBundle(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentBundleRequest.self, from: body)
            let resources = try resourceStore.list(type: nil, query: nil, limit: nil)
            let bundle = try AgentBundle.makeResource(from: request, resources: resources)
            try ResourceLimits.validateContent(bundle.item.content, type: .knowledge)
            let stored = try resourceStore.add(bundle.item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored),
                "included": bundle.included.map(ResourceJSON.object)
            ])
        } catch AgentBundleError.missingTitle {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "title is required"
            ])
        } catch AgentBundleError.missingSelection {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "task, q, or ids is required"
            ])
        } catch AgentBundleError.noMatches {
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "No matching resources for bundle"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid bundle JSON body"
            ])
        }
    }

    func createAgentHandoff(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentHandoffRequest.self, from: body)
            let item = try request.makeResource()
            let stored = try resourceStore.add(item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored)
            ])
        } catch AgentHandoffError.missingRequiredFields {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "title and summary are required"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid handoff JSON body"
            ])
        }
    }

    func createAgentSession(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentSessionRequest.self, from: body)
            let item = try request.makeResource()
            try ResourceLimits.validateContent(item.content, type: .knowledge)
            let stored = try resourceStore.add(item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored),
                "next": [
                    "update": "PATCH /agent/session/\(stored.id.uuidString)",
                    "list": "GET /agent/sessions?status=active&limit=10",
                    "handoff": "POST /agent/handoff when another agent should resume this task"
                ]
            ])
        } catch AgentSessionError.missingTask {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "task is required"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid session JSON body"
            ])
        }
    }

    func listAgentSessions(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let limit = query["limit"].flatMap(Int.init)
            let statusFilter = query["status"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nilIfEmpty
            let sourceFilter = query["source"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nilIfEmpty
            let sessions = try resourceStore.list(type: .knowledge, query: "session", limit: nil)
                .filter { $0.group == AgentSessionRequest.group }
            let filteredByStatus = statusFilter.map { status in
                sessions.filter { Self.sessionStatus($0) == status }
            } ?? sessions
            let filteredSessions = sourceFilter.map { source in
                filteredByStatus.filter { ($0.source ?? "").lowercased() == source }
            } ?? filteredByStatus
            let returnedSessions = limit.map { Array(filteredSessions.prefix(max(0, $0))) } ?? filteredSessions

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "status": statusFilter ?? "all",
                    "source": sourceFilter ?? "all"
                ],
                "counts": [
                    "total": sessions.count,
                    "returned": returnedSessions.count,
                    "byStatus": Self.sessionStatusCounts(sessions)
                ],
                "items": returnedSessions.map(ResourceJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read sessions"
            ])
        }
    }

    func updateAgentSession(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = sessionID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid session id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentSessionUpdateRequest.self, from: body)
            let sessions = try resourceStore.list(type: .knowledge, query: nil, limit: nil)
            guard let session = sessions.first(where: { $0.id == id && $0.group == AgentSessionRequest.group }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Session not found"
                ])
            }

            let changes = try request.makeChanges(from: session)
            if let content = changes.content {
                try ResourceLimits.validateContent(content, type: .knowledge)
            }

            guard let updated = try resourceStore.update(id: id, changes: changes) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Session not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ResourceJSON.object(updated)
            ])
        } catch AgentSessionError.noChanges {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "status, progress, currentStep, nextActions, resourceIDs, source, or pinned is required"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid session update JSON body"
            ])
        }
    }

    func createAgentMemory(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentMemoryRequest.self, from: body)
            let item = try request.makeResource()
            try ResourceLimits.validateContent(item.content, type: .knowledge)
            let stored = try resourceStore.add(item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored),
                "next": [
                    "list": "GET /agent/memories?q=\(stored.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stored.title)",
                    "context": "GET /agent/context?q=memory&limit=20",
                    "resolve": "GET /agent/resolve?q=\(stored.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stored.title)&type=knowledge"
                ]
            ])
        } catch AgentMemoryError.missingRequiredFields {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "title and content are required"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid memory JSON body"
            ])
        }
    }

    func listAgentMemories(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let limit = query["limit"].flatMap(Int.init)
            let q = query["q"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty
            let kindFilter = query["kind"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nilIfEmpty
            let sourceFilter = query["source"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nilIfEmpty
            let memories = try resourceStore.list(type: .knowledge, query: nil, limit: nil)
                .filter { $0.group == AgentMemoryRequest.group }
            let matchingMemories = q.map { queryText in
                memories.filter { Self.resourceMatches($0, query: queryText) }
            } ?? memories
            let filteredByKind = kindFilter.map { kind in
                matchingMemories.filter { AgentMemoryRequest.kind(from: $0).lowercased() == kind }
            } ?? matchingMemories
            let filteredMemories = sourceFilter.map { source in
                filteredByKind.filter { ($0.source ?? "").lowercased() == source }
            } ?? filteredByKind
            let returnedMemories = limit.map { Array(filteredMemories.prefix(max(0, $0))) } ?? filteredMemories

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "q": q ?? "",
                    "kind": kindFilter ?? "all",
                    "source": sourceFilter ?? "all"
                ],
                "counts": [
                    "total": memories.count,
                    "matched": matchingMemories.count,
                    "returned": returnedMemories.count,
                    "byKind": Self.memoryKindCounts(memories)
                ],
                "items": returnedMemories.map(ResourceJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read memories"
            ])
        }
    }

    func listAgentHandoffs(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let limit = query["limit"].flatMap(Int.init)
            let statusFilter = query["status"]?
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .nilIfEmpty
            let handoffs = try resourceStore.list(type: .knowledge, query: "handoff", limit: nil)
                .filter { $0.group == AgentHandoffRequest.group }
            let filteredHandoffs = statusFilter.map { status in
                handoffs.filter { Self.handoffStatus($0) == status }
            } ?? handoffs
            let returnedHandoffs = limit.map { Array(filteredHandoffs.prefix(max(0, $0))) } ?? filteredHandoffs

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "status": statusFilter ?? "all"
                ],
                "counts": [
                    "total": handoffs.count,
                    "returned": returnedHandoffs.count,
                    "byStatus": Self.handoffStatusCounts(handoffs)
                ],
                "items": returnedHandoffs.map(ResourceJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read handoffs"
            ])
        }
    }

    func updateAgentHandoff(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = handoffID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid handoff id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(AgentHandoffUpdateRequest.self, from: body)
            let handoffs = try resourceStore.list(type: .knowledge, query: nil, limit: nil)
            guard let handoff = handoffs.first(where: { $0.id == id && $0.group == AgentHandoffRequest.group }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Handoff not found"
                ])
            }

            let changes = try request.makeChanges(from: handoff)
            if let content = changes.content {
                try ResourceLimits.validateContent(content, type: .knowledge)
            }

            guard let updated = try resourceStore.update(id: id, changes: changes) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Handoff not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ResourceJSON.object(updated)
            ])
        } catch AgentHandoffError.noChanges {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "status, progress, source, or pinned is required"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid handoff update JSON body"
            ])
        }
    }

    func agentContext(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = query["type"].flatMap(ResourceType.init(rawValue:))
        if query["type"] != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let items = try resourceStore.list(type: type, query: query["q"], limit: nil)
            return HTTPResponse.jsonObject(AgentContextPack.object(
                resources: items,
                query: query["q"],
                type: type,
                clipboardVisibility: clipboardVisibility,
                requestedLimit: query["limit"].flatMap(Int.init)
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not build agent context"
            ])
        }
    }

    func agentResource(path: String, query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = agentResourceID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource id"
            ])
        }

        let clipboardVisibility: AgentClipboardVisibility
        do {
            clipboardVisibility = try Self.parseClipboardVisibility(query)
        } catch {
            return Self.invalidClipboardVisibilityResponse()
        }

        do {
            let items = try resourceStore.list(type: nil, query: nil, limit: nil)
            guard let item = items.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            return HTTPResponse.jsonObject(AgentResourceDetail.object(
                item: item,
                clipboardVisibility: clipboardVisibility
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read resource"
            ])
        }
    }


}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
