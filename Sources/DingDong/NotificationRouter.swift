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

    private func listResources(typeName: String?, query: String?, limit: Int?) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = typeName.flatMap(ResourceType.init(rawValue:))
        if typeName != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        do {
            let items = try resourceStore.list(type: type, query: query, limit: limit)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "items": items.map(ResourceJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read resource library"
            ])
        }
    }

    private func showUI(query: [String: String]) -> HTTPResponse {
        let tab = query["tab"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty

        let selectedTab = tab.flatMap(CompanionTab.init(apiValue:))
        if tab != nil, selectedTab == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "tab must be today, library, clipboard, or api"
            ])
        }

        handleShowPanel?(selectedTab)
        return HTTPResponse.jsonObject([
            "status": "shown",
            "tab": selectedTab?.apiValue ?? "current"
        ])
    }

    private func listResourceGroups(typeName: String?) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let type = typeName.flatMap(ResourceType.init(rawValue:))
        if typeName != nil, type == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource type"
            ])
        }

        do {
            let items = try resourceStore.list(type: type, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "groups": LibraryGroupSummary.summaries(from: items).map(ResourceGroupJSON.object)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read resource groups"
            ])
        }
    }

    private func exportResources(query: [String: String]) -> HTTPResponse {
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
            let resources = try resourceStore.list(type: type, query: query["q"], limit: nil)
            return HTTPResponse.jsonObject(LibraryExport.object(
                resources: resources,
                type: type,
                query: query["q"],
                requestedLimit: query["limit"].flatMap(Int.init),
                clipboardVisibility: clipboardVisibility
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not export resource library"
            ])
        }
    }

    private func listEvents(limit: Int?) -> HTTPResponse {
        guard let agentEventStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Agent events are not available"
            ])
        }

        return HTTPResponse.jsonObject([
            "status": "ok",
            "events": agentEventStore.list(limit: limit).map(AgentEventJSON.object)
        ])
    }

    private func agentToolkit() -> HTTPResponse {
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

    private func systemStatus() -> HTTPResponse {
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

    private func agentStartup(query: [String: String]) -> HTTPResponse {
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

    private func agentBridge(query: [String: String]) -> HTTPResponse {
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

    private func agentPrepare(query: [String: String]) -> HTTPResponse {
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

    private func agentInstructions(query: [String: String]) -> HTTPResponse {
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

    private func listAgentPresence(query: [String: String]) -> HTTPResponse {
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

    private func agentWorkbench(query: [String: String]) -> HTTPResponse {
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

    private func updateAgentPresence(_ body: Data) -> HTTPResponse {
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

    private func agentBrief(query: [String: String]) -> HTTPResponse {
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

    private func agentRecommend(query: [String: String]) -> HTTPResponse {
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

    private func agentResolve(query: [String: String]) -> HTTPResponse {
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

    private func createAgentBundle(_ body: Data) -> HTTPResponse {
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

    private func createAgentHandoff(_ body: Data) -> HTTPResponse {
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

    private func createAgentSession(_ body: Data) -> HTTPResponse {
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

    private func listAgentSessions(query: [String: String]) -> HTTPResponse {
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

    private func updateAgentSession(path: String, body: Data) -> HTTPResponse {
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

    private func createAgentMemory(_ body: Data) -> HTTPResponse {
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

    private func listAgentMemories(query: [String: String]) -> HTTPResponse {
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

    private func listAgentHandoffs(query: [String: String]) -> HTTPResponse {
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

    private func updateAgentHandoff(path: String, body: Data) -> HTTPResponse {
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

    private func agentContext(query: [String: String]) -> HTTPResponse {
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

    private func agentResource(path: String, query: [String: String]) -> HTTPResponse {
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

    private func addResource(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceCreateRequest.self, from: body)
            guard !request.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !request.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title and content are required"
                ])
            }

            try ResourceLimits.validateContent(request.content, type: request.type)
            let item = try resourceStore.add(request.makeItem())
            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(item)
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource JSON body"
            ])
        }
    }

    private func importResources(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(LibraryImportRequest.self, from: body)
            guard request.type != .clipboard else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "clipboard resources cannot be bulk imported"
                ])
            }

            guard !request.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "path is required"
                ])
            }

            let existing = try resourceStore.list(type: request.type, query: nil, limit: nil)
            let result = try libraryImporter.candidates(from: request, existing: existing)
            let stored = try result.imported.map { try resourceStore.add($0) }

            return HTTPResponse.jsonObject([
                "status": "imported",
                "importedCount": stored.count,
                "skippedCount": result.skippedCount,
                "scannedCount": result.scannedCount,
                "items": stored.map(ResourceJSON.object)
            ])
        } catch LibraryImportError.missingDirectory {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Import path is not a directory"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid import JSON body"
            ])
        }
    }

    private func updateResource(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = resourceID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceUpdateRequest.self, from: body)
            guard request.hasChanges else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "At least one resource field is required"
                ])
            }

            if let title = request.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title cannot be empty"
                ])
            }

            if let content = request.content, content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "content cannot be empty"
                ])
            }

            let existingItem = try resourceStore.list(type: nil, query: nil, limit: nil).first { $0.id == id }
            guard let existingItem else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            if let content = request.content {
                try ResourceLimits.validateContent(content, type: request.type ?? existingItem.type)
            }

            guard let item = try resourceStore.update(id: id, changes: request) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ResourceJSON.object(item)
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource JSON body"
            ])
        }
    }

    private func deleteResource(path: String) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = resourceID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid resource id"
            ])
        }

        do {
            guard try resourceStore.delete(id: id) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Resource not found"
                ])
            }

            return .json(object: [
                "status": "deleted",
                "id": id.uuidString
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not delete resource"
            ])
        }
    }

    private func seedDefaultResources() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let result = try DefaultResourceSeeds.install(into: resourceStore, onlyIfEmpty: false)
            return HTTPResponse.jsonObject([
                "status": "seeded",
                "defaults": result.object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not seed default resources"
            ])
        }
    }

    private func indexKnowledge(idValue: String?, pathValue: String?, limitValue: String?) -> HTTPResponse {
        do {
            let rootPath = try knowledgeRootPath(idValue: idValue, pathValue: pathValue)
            let result = try knowledgeIndexer.index(rootPath: rootPath, maxFiles: limitValue.flatMap(Int.init) ?? KnowledgeIndexer.defaultMaxFiles)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "root": result.root,
                "scannedCount": result.scannedCount,
                "skippedCount": result.skippedCount,
                "truncated": result.truncated,
                "files": result.files.map(KnowledgeIndexJSON.object)
            ])
        } catch KnowledgeIndexRouteError.missingInput {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "id or path is required"
            ])
        } catch KnowledgeIndexRouteError.invalidID {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid knowledge resource id"
            ])
        } catch KnowledgeIndexRouteError.notFound {
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "Knowledge resource not found"
            ])
        } catch KnowledgeIndexRouteError.notKnowledge {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Resource is not a knowledge item"
            ])
        } catch KnowledgeIndexError.missingDirectory {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Knowledge path is not a directory"
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not index knowledge path"
            ])
        }
    }

    private func knowledgeRootPath(idValue: String?, pathValue: String?) throws -> String {
        if let path = pathValue?.removingPercentEncoding?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return path
        }

        guard let idValue, !idValue.isEmpty else {
            throw KnowledgeIndexRouteError.missingInput
        }

        guard let id = UUID(uuidString: idValue), let resourceStore else {
            throw KnowledgeIndexRouteError.invalidID
        }

        let items = try resourceStore.list(type: .knowledge, query: nil, limit: nil)
        guard let item = items.first(where: { $0.id == id }) else {
            let allItems = try resourceStore.list(type: nil, query: nil, limit: nil)
            if allItems.contains(where: { $0.id == id }) {
                throw KnowledgeIndexRouteError.notKnowledge
            }
            throw KnowledgeIndexRouteError.notFound
        }

        return item.content
    }

    private func captureClipboard() -> HTTPResponse {
        guard let resourceStore, let clipboardRecorder else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Clipboard capture is not available"
            ])
        }

        guard let item = clipboardRecorder.capture(source: "API") else {
            return .json(statusCode: 204, reason: "No Content", object: [
                "status": "empty",
                "message": "Clipboard has no text"
            ])
        }

        do {
            try ResourceLimits.validateContent(item.content, type: .clipboard)
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not validate clipboard"
            ])
        }

        do {
            let existingClipboard = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            if existingClipboard.contains(where: { $0.content == item.content }) {
                return HTTPResponse.jsonObject([
                    "status": "duplicate",
                    "message": "Clipboard record already exists"
                ])
            }

            let stored = try resourceStore.add(item)
            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "captured",
                "item": ResourceJSON.object(stored)
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not save clipboard record"
            ])
        }
    }

    private func clipboardOverview() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "service": "DingDong",
                "overview": ClipboardOverview(items: items).object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard overview"
            ])
        }
    }

    private func clipboardInsights(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeSensitiveClipboard: Bool
        do {
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject(ClipboardInsights.object(
                items: items,
                requestedLimit: query["limit"].flatMap(Int.init),
                includeSensitiveClipboard: includeSensitiveClipboard
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard insights"
            ])
        }
    }

    private func clipboardDigest(query: [String: String]) -> HTTPResponse {
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

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject(ClipboardDigest.object(
                items: items,
                task: task,
                requestedLimit: query["limit"].flatMap(Int.init),
                includeContent: includeContent,
                includeSensitiveClipboard: includeSensitiveClipboard
            ))
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard digest"
            ])
        }
    }

    private func collectClipboard(_ body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ClipboardCollectionRequest.self, from: body)
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            let collection = try ClipboardCollection.makeResource(from: request, clipboardItems: clipboardItems)
            try ResourceLimits.validateContent(collection.item.content, type: .knowledge)
            let stored = try resourceStore.add(collection.item)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "created",
                "item": ResourceJSON.object(stored),
                "included": collection.included.map(ResourceJSON.object),
                "privacy": [
                    "sensitiveClipboardIncluded": request.includeSensitiveClipboard ?? false,
                    "hiddenSensitiveItems": collection.hiddenSensitive,
                    "default": "clipboard collections exclude sensitive clipboard records unless includeSensitiveClipboard=true"
                ],
                "next": [
                    "find": "GET /library?type=knowledge&q=\(Self.encodedQuery(stored.title))",
                    "context": "GET /agent/context?q=\(Self.encodedQuery(stored.title))&limit=10"
                ]
            ])
        } catch ClipboardCollectionError.missingTitle {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "title is required"
            ])
        } catch ClipboardCollectionError.missingSelection {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "task, q, or ids is required"
            ])
        } catch ClipboardCollectionError.noMatches {
            return .json(statusCode: 404, reason: "Not Found", object: [
                "status": "error",
                "message": "No matching clipboard records"
            ])
        } catch ResourceLimitError.contentTooLarge(let maxCharacters) {
            return Self.contentTooLargeResponse(maxCharacters: maxCharacters)
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard collection JSON body"
            ])
        }
    }

    private func clipboardHistory(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        let filter = query["filter"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .nilIfEmpty
        let selectedFilter = filter.flatMap(ClipboardSmartFilter.init(rawValue:)) ?? .all
        if filter != nil, ClipboardSmartFilter(rawValue: filter!) == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "filter must be one of all, url, command, code, json, path, image, file, email, or sensitive"
            ])
        }

        let group = query["group"]?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let requestedLimit = query["limit"].flatMap(Int.init) ?? 20
        let limit = min(max(requestedLimit, 0), 50)

        do {
            var items = try resourceStore.list(type: .clipboard, query: query["q"], limit: nil)

            if let group {
                items = items.filter { $0.group.localizedCaseInsensitiveCompare(group) == .orderedSame }
            }

            if let tagQuery = selectedFilter.tagQuery {
                items = items.filter { $0.tags.contains(tagQuery) }
            }

            let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : items.filter(\.isSensitiveClipboard).count
            let visibleItems = includeSensitiveClipboard ? items : items.filter { !$0.isSensitiveClipboard }
            let returnedItems = Array(visibleItems.prefix(limit))

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "q": query["q"] ?? "",
                    "group": group ?? "all",
                    "filter": selectedFilter.rawValue,
                    "limit": limit,
                    "includeContent": includeContent,
                    "includeSensitiveClipboard": includeSensitiveClipboard
                ],
                "counts": [
                    "matched": items.count,
                    "visible": visibleItems.count,
                    "returned": returnedItems.count,
                    "hiddenSensitive": hiddenSensitiveCount
                ],
                "privacy": [
                    "contentIncluded": includeContent,
                    "sensitiveClipboardIncluded": includeSensitiveClipboard,
                    "default": "clipboard history returns metadata only; pass includeContent=true to read content",
                    "sensitiveDefault": "sensitive clipboard records are hidden unless includeSensitiveClipboard=true"
                ],
                "items": returnedItems.map {
                    ClipboardHistoryJSON.object($0, includeContent: includeContent)
                }
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard history"
            ])
        }
    }

    private func clipboardSnippets(query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        let includeContent: Bool
        let includeSensitiveClipboard: Bool
        do {
            includeContent = try Self.parseBoolQuery(query, key: "includeContent") ?? false
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeContent and includeSensitiveClipboard must be true or false"
            ])
        }

        let alias = query["alias"].flatMap(Self.normalizedClipboardAlias)
        if query["alias"] != nil, alias == nil {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "alias cannot be empty"
            ])
        }

        let requestedLimit = query["limit"].flatMap(Int.init) ?? 20
        let limit = min(max(requestedLimit, 0), 50)

        do {
            let allItems = try resourceStore.list(type: .clipboard, query: query["q"], limit: nil)
            let snippetItems = allItems.filter { !Self.clipboardAliases(for: $0).isEmpty }
            let aliasItems = alias.map { selectedAlias in
                snippetItems.filter { Self.clipboardAliases(for: $0).contains(selectedAlias) }
            } ?? snippetItems
            let hiddenSensitiveCount = includeSensitiveClipboard ? 0 : aliasItems.filter(\.isSensitiveClipboard).count
            let visibleItems = includeSensitiveClipboard ? aliasItems : aliasItems.filter { !$0.isSensitiveClipboard }
            let returnedItems = Array(visibleItems.prefix(limit))

            return HTTPResponse.jsonObject([
                "status": "ok",
                "filter": [
                    "alias": alias ?? "all",
                    "q": query["q"] ?? "",
                    "limit": limit,
                    "includeContent": includeContent,
                    "includeSensitiveClipboard": includeSensitiveClipboard
                ],
                "counts": [
                    "snippetRecords": snippetItems.count,
                    "matched": aliasItems.count,
                    "visible": visibleItems.count,
                    "returned": returnedItems.count,
                    "hiddenSensitive": hiddenSensitiveCount
                ],
                "aliases": Self.clipboardAliasSummaries(from: visibleItems),
                "privacy": [
                    "contentIncluded": includeContent,
                    "sensitiveClipboardIncluded": includeSensitiveClipboard,
                    "default": "clipboard snippets return metadata only; pass includeContent=true to read content",
                    "sensitiveDefault": "sensitive clipboard snippets are hidden unless includeSensitiveClipboard=true"
                ],
                "items": returnedItems.map {
                    ClipboardHistoryJSON.object($0, includeContent: includeContent, aliases: Self.clipboardAliases(for: $0))
                }
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard snippets"
            ])
        }
    }

    private func clipboardGroups() -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        do {
            let items = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            return HTTPResponse.jsonObject([
                "status": "ok",
                "groups": LibraryGroupSummary.summaries(from: items).map(ResourceGroupJSON.object),
                "overview": ClipboardOverview(items: items).object
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard groups"
            ])
        }
    }

    private func updateClipboard(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardRecordID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let request = try JSONDecoder().decode(ResourceUpdateRequest.self, from: body)
            guard request.title != nil || request.group != nil || request.tags != nil || request.pinned != nil else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title, group, tags, or pinned is required"
                ])
            }

            guard request.type == nil, request.content == nil, request.source == nil else {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "clipboard patch cannot change type, content, or source"
                ])
            }

            if let title = request.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .json(statusCode: 400, reason: "Bad Request", object: [
                    "status": "error",
                    "message": "title cannot be empty"
                ])
            }

            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let existingItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            let changes = Self.clipboardOrganizationChanges(request, existingItem: existingItem)
            guard let item = try resourceStore.update(id: id, changes: changes) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "updated",
                "item": ClipboardHistoryJSON.object(item, includeContent: false)
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard patch JSON body"
            ])
        }
    }

    private static func clipboardOrganizationChanges(_ request: ResourceUpdateRequest, existingItem: ResourceItem) -> ResourceUpdateRequest {
        guard let tags = request.tags else {
            return request
        }

        let mergedTags = uniqueTags(existingItem.tags + tags)
        return ResourceUpdateRequest(
            group: request.group,
            title: request.title,
            tags: mergedTags,
            pinned: request.pinned
        )
    }

    private static func uniqueTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let key = trimmed.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private static func clipboardAliases(for item: ResourceItem) -> [String] {
        let aliases = item.tags.compactMap { tag -> String? in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("alias:") else {
                return nil
            }

            return normalizedClipboardAlias(String(trimmed.dropFirst("alias:".count)))
        }

        return uniqueTags(aliases).map { $0.lowercased() }
    }

    private static func normalizedClipboardAlias(_ value: String) -> String? {
        let trimmed = value
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed.lowercased()
    }

    private static func clipboardAliasSummaries(from items: [ResourceItem]) -> [[String: Any]] {
        var buckets: [String: [ResourceItem]] = [:]
        for item in items {
            for alias in clipboardAliases(for: item) {
                buckets[alias, default: []].append(item)
            }
        }

        return buckets
            .map { alias, items in
                [
                    "alias": alias,
                    "count": items.count,
                    "pinnedCount": items.filter(\.pinned).count,
                    "latestUpdatedAt": isoTimestamp(items.map(\.updatedAt).max() ?? Date(timeIntervalSince1970: 0))
                ] as [String: Any]
            }
            .sorted { lhs, rhs in
                (lhs["alias"] as? String ?? "") < (rhs["alias"] as? String ?? "")
            }
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func promoteClipboard(path: String, body: Data) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let clipboardItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            let request = try Self.parsePromotionRequest(body)
            let promoted = try request.makeResource(from: clipboardItem)
            let stored = try resourceStore.add(promoted)

            return HTTPResponse.jsonObject(statusCode: 201, reason: "Created", [
                "status": "promoted",
                "sourceID": clipboardItem.id.uuidString,
                "item": ResourceJSON.object(stored)
            ])
        } catch ClipboardPromotionError.invalidTargetType {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "targetType cannot be clipboard"
            ])
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid promotion JSON body"
            ])
        }
    }

    private func restoreClipboard(path: String) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let id = clipboardRestoreID(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard id"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            guard let clipboardItem = clipboardItems.first(where: { $0.id == id }) else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard record not found"
                ])
            }

            guard writePasteboard(clipboardItem.content) else {
                return .json(statusCode: 500, reason: "Internal Server Error", object: [
                    "status": "error",
                    "message": "Could not restore clipboard"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "restored",
                "id": clipboardItem.id.uuidString,
                "title": clipboardItem.title,
                "contentCharacterCount": clipboardItem.content.count
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard record"
            ])
        }
    }

    private func restoreClipboardSnippet(path: String, query: [String: String]) -> HTTPResponse {
        guard let resourceStore else {
            return .json(statusCode: 503, reason: "Service Unavailable", object: [
                "status": "error",
                "message": "Resource library is not available"
            ])
        }

        guard let alias = clipboardSnippetAlias(from: path) else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "Invalid clipboard snippet alias"
            ])
        }

        let includeSensitiveClipboard: Bool
        do {
            includeSensitiveClipboard = try Self.parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        } catch {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "includeSensitiveClipboard must be true or false"
            ])
        }

        do {
            let clipboardItems = try resourceStore.list(type: .clipboard, query: nil, limit: nil)
            let matches = clipboardItems
                .filter { Self.clipboardAliases(for: $0).contains(alias) }
                .filter { includeSensitiveClipboard || !$0.isSensitiveClipboard }
                .sorted { lhs, rhs in
                    if lhs.pinned != rhs.pinned {
                        return lhs.pinned && !rhs.pinned
                    }

                    return lhs.updatedAt > rhs.updatedAt
                }

            guard let item = matches.first else {
                return .json(statusCode: 404, reason: "Not Found", object: [
                    "status": "error",
                    "message": "Clipboard snippet not found"
                ])
            }

            guard writePasteboard(item.content) else {
                return .json(statusCode: 500, reason: "Internal Server Error", object: [
                    "status": "error",
                    "message": "Could not restore clipboard snippet"
                ])
            }

            return HTTPResponse.jsonObject([
                "status": "restored",
                "alias": alias,
                "id": item.id.uuidString,
                "title": item.title,
                "contentCharacterCount": item.content.count
            ])
        } catch {
            return .json(statusCode: 500, reason: "Internal Server Error", object: [
                "status": "error",
                "message": "Could not read clipboard snippet"
            ])
        }
    }

    private func setClipboardMonitoring(enabledValue: String?, body: Data) -> HTTPResponse {
        let enabled = enabledValue.flatMap(Self.parseBool) ?? Self.parseMonitorBody(body)
        guard let enabled else {
            return .json(statusCode: 400, reason: "Bad Request", object: [
                "status": "error",
                "message": "enabled must be true or false"
            ])
        }

        handleClipboardMonitoring?(enabled)
        return .json(object: [
            "status": enabled ? "enabled" : "disabled",
            "feature": "clipboard-monitor"
        ])
    }

    private static func parseBool(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true", "1", "yes", "on":
            true
        case "false", "0", "no", "off":
            false
        default:
            nil
        }
    }

    private static func defaultClipboardMonitoringState() -> Bool {
        UserDefaults.standard.bool(forKey: "dingdong.clipboard.monitoring")
    }

    private static func parseClipboardVisibility(_ query: [String: String]) throws -> AgentClipboardVisibility {
        let includeClipboard = try parseBoolQuery(query, key: "includeClipboard") ?? false
        let includeSensitiveClipboard = try parseBoolQuery(query, key: "includeSensitiveClipboard") ?? false
        return AgentClipboardVisibility(
            includeClipboard: includeClipboard,
            includeSensitiveClipboard: includeSensitiveClipboard
        )
    }

    private static func parseBoolQuery(_ query: [String: String], key: String) throws -> Bool? {
        guard let rawValue = query[key] else {
            return nil
        }

        guard let value = parseBool(rawValue) else {
            throw ClipboardVisibilityError.invalidBoolean
        }

        return value
    }

    private static func invalidClipboardVisibilityResponse() -> HTTPResponse {
        .json(statusCode: 400, reason: "Bad Request", object: [
            "status": "error",
            "message": "includeClipboard and includeSensitiveClipboard must be true or false"
        ])
    }

    private static func handoffStatus(_ item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    private static func handoffStatusCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[handoffStatus(item), default: 0] += 1
        }
        return counts
    }

    private static func sessionStatus(_ item: ResourceItem) -> String {
        item.tags.first { $0.lowercased().hasPrefix("status:") }?
            .dropFirst("status:".count)
            .description
            .lowercased()
            .nilIfEmpty ?? "unknown"
    }

    private static func sessionStatusCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[sessionStatus(item), default: 0] += 1
        }
        return counts
    }

    private static func memoryKindCounts(_ items: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for item in items {
            counts[AgentMemoryRequest.kind(from: item), default: 0] += 1
        }
        return counts
    }

    private static func resourceMatches(_ item: ResourceItem, query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        return item.title.lowercased().contains(lowercasedQuery)
            || item.content.lowercased().contains(lowercasedQuery)
            || item.group.lowercased().contains(lowercasedQuery)
            || item.tags.contains { $0.lowercased().contains(lowercasedQuery) }
    }

    private static func encodedQuery(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    private static func contentTooLargeResponse(maxCharacters: Int) -> HTTPResponse {
        .json(statusCode: 413, reason: "Payload Too Large", object: [
            "status": "error",
            "message": "content exceeds \(maxCharacters) characters"
        ])
    }

    private static func parseMonitorBody(_ body: Data) -> Bool? {
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

    private func resourceID(from path: String) -> UUID? {
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

    private func clipboardID(from path: String) -> UUID? {
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

    private func clipboardRestoreID(from path: String) -> UUID? {
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

    private func clipboardSnippetAlias(from path: String) -> String? {
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

    private func clipboardRecordID(from path: String) -> UUID? {
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

    private func handoffID(from path: String) -> UUID? {
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

    private func sessionID(from path: String) -> UUID? {
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

    private func agentResourceID(from path: String) -> UUID? {
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

    private static func writeSystemPasteboard(_ content: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(content, forType: .string)
    }

    private static func parsePromotionRequest(_ body: Data) throws -> ClipboardPromotionRequest {
        guard !body.isEmpty else {
            return ClipboardPromotionRequest()
        }

        return try JSONDecoder().decode(ClipboardPromotionRequest.self, from: body)
    }

    private static func parseAgentPresenceRequest(_ body: Data) throws -> AgentPresenceRequest {
        guard !body.isEmpty else {
            throw AgentPresenceError.missingSource
        }

        return try JSONDecoder().decode(AgentPresenceRequest.self, from: body)
    }
}

private struct ParsedRoute {
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

private enum ResourceJSON {
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

private enum ClipboardHistoryJSON {
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

    private static func classification(for item: ResourceItem) -> String {
        for candidate in ["url", "command", "code", "json", "path", "email", "sensitive", "text"] {
            if item.tags.contains(candidate) {
                return candidate
            }
        }
        return "unknown"
    }
}

private enum ResourceGroupJSON {
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

private enum KnowledgeIndexJSON {
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

private enum AgentCommandTemplateJSON {
    static func object(_ template: AgentCommandTemplate) -> [String: Any] {
        [
            "id": template.id,
            "title": template.title,
            "summary": template.summary,
            "command": template.command
        ]
    }
}

private enum AgentEventJSON {
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

private enum AgentPresenceJSON {
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

private enum KnowledgeIndexRouteError: Error {
    case missingInput
    case invalidID
    case notFound
    case notKnowledge
}

private enum ClipboardVisibilityError: Error {
    case invalidBoolean
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
