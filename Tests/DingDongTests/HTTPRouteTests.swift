import Foundation
import Testing
@testable import DingDong

struct HTTPRouteTests {
    @Test func parsesHTTPRequestWithBody() throws {
        let raw = """
        POST /ding HTTP/1.1\r
        Content-Type: application/json\r
        Content-Length: 25\r
        \r
        {"message":"Task done"}
        """

        let request = try #require(HTTPRequestParser.parse(Data(raw.utf8)))

        #expect(request.method == "POST")
        #expect(request.path == "/ding")
        #expect(String(data: request.body, encoding: .utf8) == #"{"message":"Task done"}"#)
    }

    @Test func healthRouteReturnsOk() throws {
        var didDing = false
        let router = NotificationRouter { _ in didDing = true }

        let response = router.route(HTTPRequest(method: "GET", path: "/health", body: Data()))

        #expect(response.statusCode == 200)
        #expect(didDing == false)
        #expect(String(data: response.body, encoding: .utf8)?.contains(#""status":"ok""#) == true)
    }

    @Test func agentTemplatesRouteListsReusableCommands() throws {
        let router = NotificationRouter { _ in }

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/templates", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(body.contains(#""id":"ding-complete""#))
        #expect(body.contains(#""id":"import-folder""#))
        #expect(body.contains(#""id":"scan-knowledge""#))
        #expect(body.contains(#""id":"promote-clipboard""#))
        #expect(body.contains(#""id":"restore-clipboard""#))
        #expect(body.contains(#""id":"clipboard-overview""#))
        #expect(body.contains(#""id":"clipboard-insights""#))
        #expect(body.contains(#""id":"clipboard-digest""#))
        #expect(body.contains(#""id":"clipboard-collect""#))
        #expect(body.contains(#""id":"clipboard-history""#))
        #expect(body.contains(#""id":"clipboard-groups""#))
        #expect(body.contains(#""id":"clipboard-snippets""#))
        #expect(body.contains(#""id":"restore-snippet""#))
        #expect(body.contains(#""id":"show-clipboard""#))
        #expect(body.contains(#""id":"system-status""#))
        #expect(body.contains(#""id":"organize-clipboard""#))
        #expect(body.contains(#""id":"list-groups""#))
        #expect(body.contains(#""id":"export-library""#))
        #expect(body.contains(#""id":"agent-brief""#))
        #expect(body.contains(#""id":"agent-manifest""#))
        #expect(body.contains(#""id":"agent-toolkit""#))
        #expect(body.contains(#""id":"agent-startup""#))
        #expect(body.contains(#""id":"agent-bridge""#))
        #expect(body.contains(#""id":"agent-prepare""#))
        #expect(body.contains(#""id":"agent-workbench""#))
        #expect(body.contains(#""id":"agent-instructions""#))
        #expect(body.contains(#""id":"agent-presence""#))
        #expect(body.contains(#""id":"start-session""#))
        #expect(body.contains(#""id":"list-sessions""#))
        #expect(body.contains(#""id":"update-session""#))
        #expect(body.contains(#""id":"save-memory""#))
        #expect(body.contains(#""id":"list-memories""#))
        #expect(body.contains(#""id":"recommend-resources""#))
        #expect(body.contains(#""id":"resolve-resource""#))
        #expect(body.contains(#""id":"agent-resource""#))
        #expect(body.contains(#""id":"save-bundle""#))
        #expect(!body.contains(#""id":"seed-defaults""#))
        #expect(body.contains(#""id":"save-handoff""#))
        #expect(body.contains(#""id":"list-handoffs""#))
        #expect(body.contains(#""id":"update-handoff""#))
    }

    @Test func agentCapabilitiesRouteDescribesSupportedFeatures() throws {
        let router = NotificationRouter { _ in }

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/capabilities", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))
        let object = try jsonObject(response.body)
        let endpoints = try #require(object["endpoints"] as? [[String: Any]])
        let sounds = try #require(object["sounds"] as? [String])

        #expect(response.statusCode == 200)
        #expect(body.contains(#""service":"DingDong""#))
        #expect(sounds.contains("confetti"))
        #expect(sounds.contains("marimba"))
        #expect(sounds.contains("candy"))
        #expect(sounds.contains("random"))
        #expect(sounds.contains("custom"))
        #expect(body.contains(#""resourceTypes":["prompt","skill","mcp","knowledge","clipboard"]"#))
        #expect(body.contains(#""libraryImportItems":50"#))
        #expect(body.contains(#""resourceContentCharacters":100000"#))
        #expect(body.contains(#""clipboardContentCharacters":20000"#))
        #expect(body.contains(#""resourceGroupSummary""#))
        #expect(!body.contains(#""defaultResourceSeeds""#))
        #expect(body.contains(#""resourceLibraryExport""#))
        #expect(body.contains(#""systemStatus""#))
        #expect(body.contains(#""performanceStatus""#))
        #expect(body.contains(#""agentDiscoveryManifest""#))
        #expect(body.contains(#""menuBarUnreadBadge""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/system/status" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/manifest" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/.well-known/dingdong-agent.json" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/bridge" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/library/groups" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/library/export" })
        #expect(!endpoints.contains { ($0["path"] as? String) == "/library/seed-defaults" })
        #expect(body.contains(#""agentStartupBrief""#))
        #expect(body.contains(#""agentStartupPack""#))
        #expect(body.contains(#""agentMinimalBridge""#))
        #expect(body.contains(#""agentPreparePack""#))
        #expect(body.contains(#""agentWorkbench""#))
        #expect(body.contains(#""agentInstructionPack""#))
        #expect(body.contains(#""uiTabDeepLink""#))
        #expect(body.contains(#""agentPresence""#))
        #expect(body.contains(#""agentSessions""#))
        #expect(body.contains(#""agentSessionUpdates""#))
        #expect(body.contains(#""agentSessionFilters""#))
        #expect(body.contains(#""agentMemories""#))
        #expect(body.contains(#""agentMemoryFilters""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/brief" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/presence" && ($0["method"] as? String) == "GET" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/presence" && ($0["method"] as? String) == "POST" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/session" && ($0["method"] as? String) == "POST" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/session/{id}" && ($0["method"] as? String) == "PATCH" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/sessions" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/memory" && ($0["method"] as? String) == "POST" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/memories" })
        #expect(body.contains(#""agentResourceRecommendation""#))
        #expect(body.contains(#""agentResourceDetail""#))
        #expect(body.contains(#""agentResourceResolve""#))
        #expect(body.contains(#""agentResourceBundles""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/recommend" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/resolve" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/resource/{id}" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/bundle" })
        #expect(body.contains(#""agentHandoffNotes""#))
        #expect(body.contains(#""agentHandoffStatusUpdates""#))
        #expect(body.contains(#""agentHandoffStatusFilters""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/handoff" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/handoff/{id}" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/handoffs" })
        #expect(body.contains(#""agentToolkitPrompt""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/toolkit" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/startup" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/prepare" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/workbench" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/agent/instructions" })
        #expect(body.contains(#""clipboardClassification""#))
        #expect(body.contains(#""clipboardOverview""#))
        #expect(body.contains(#""clipboardInsights""#))
        #expect(body.contains(#""clipboardDigest""#))
        #expect(body.contains(#""clipboardCollection""#))
        #expect(body.contains(#""clipboardHistory""#))
        #expect(body.contains(#""clipboardGroups""#))
        #expect(body.contains(#""clipboardSnippets""#))
        #expect(body.contains(#""clipboardSnippetRestore""#))
        #expect(body.contains(#""clipboardOrganization""#))
        #expect(body.contains(#""clipboardHistoryPrivacyGuard""#))
        #expect(body.contains(#""clipboardPromotion""#))
        #expect(body.contains(#""clipboardRestore""#))
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/overview" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/insights" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/digest" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/collect" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/history" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/snippets" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/groups" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/{id}" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/restore/{id}" })
        #expect(endpoints.contains { ($0["path"] as? String) == "/clipboard/snippet/{alias}/restore" })
        #expect(body.contains(#""knowledgeIndexing""#))
    }

    @Test func agentManifestRoutesReturnMachineReadableDiscovery() throws {
        let router = NotificationRouter { _ in }

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/manifest", body: Data()))
        let wellKnown = router.route(HTTPRequest(method: "GET", path: "/.well-known/dingdong-agent.json", body: Data()))
        let object = try jsonObject(response.body)
        let transport = try #require(object["transport"] as? [String: Any])
        let entrypoints = try #require(object["entrypoints"] as? [String: String])
        let privacy = try #require(object["privacyDefaults"] as? [String: Any])
        let flow = try #require(object["recommendedFlow"] as? [String])
        let templates = try #require(object["commandTemplates"] as? [[String: Any]])
        let endpoints = try #require(object["endpoints"] as? [[String: Any]])
        let wellKnownObject = try jsonObject(wellKnown.body)

        #expect(response.statusCode == 200)
        #expect(wellKnown.statusCode == 200)
        #expect(object["schemaVersion"] as? String == "1.0")
        #expect(object["service"] as? String == "DingDong")
        #expect(object["baseURL"] as? String == "http://127.0.0.1:8765")
        #expect(transport["network"] as? String == "local-only")
        #expect(entrypoints["bridge"] == "/agent/bridge?source=AGENT&task=TASK&limit=20")
        #expect(entrypoints["startup"] == "/agent/startup?task=TASK&limit=10")
        #expect(entrypoints["workbench"] == "/agent/workbench?task=TASK&limit=8")
        #expect(entrypoints["toolkit"] == "/agent/toolkit")
        #expect(privacy["clipboardContentIncluded"] as? Bool == false)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == false)
        #expect(flow.contains("GET /agent/manifest"))
        #expect(flow.contains { $0.hasPrefix("GET /agent/bridge?source=AGENT&task=TASK&limit=20") })
        #expect(flow.contains("GET /agent/resource/{id} before applying a selected full skill, prompt, or MCP reference"))
        #expect(flow.contains("GET /agent/workbench?task=TASK&limit=8"))
        #expect(templates.contains { $0["id"] as? String == "agent-manifest" })
        #expect(endpoints.contains { $0["path"] as? String == "/clipboard/collect" })
        #expect(wellKnownObject["schemaVersion"] as? String == "1.0")
        #expect(wellKnownObject["service"] as? String == "DingDong")
    }

    @Test func agentToolkitRouteReturnsCopyableAgentOnboarding() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Review prompt", content: "Review carefully", pinned: true),
            ResourceItem(type: .clipboard, title: "Clipboard note", content: "private text"),
            try AgentSessionRequest(
                task: "Review task",
                title: nil,
                summary: "Session summary.",
                currentStep: nil,
                nextActions: nil,
                resourceIDs: nil,
                source: "Codex",
                status: "active",
                tags: nil,
                pinned: nil
            ).makeResource(),
            try AgentMemoryRequest(
                title: "Review memory",
                content: "Prefer regression tests.",
                task: "review",
                kind: "preference",
                source: "Codex",
                tags: nil,
                pinned: nil
            ).makeResource(),
            try AgentHandoffRequest(
                title: "Resume task",
                summary: "Continue the previous work.",
                nextSteps: nil,
                blockers: nil,
                artifacts: nil,
                source: "Codex",
                status: "open",
                tags: nil,
                pinned: nil
            ).makeResource()
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/toolkit", body: Data()))
        let object = try jsonObject(response.body)
        let library = try #require(object["library"] as? [String: Any])
        let privacy = try #require(object["privacy"] as? [String: Any])
        let startupFlow = try #require(object["startupFlow"] as? [String])
        let commands = try #require(object["commonCommands"] as? [[String: Any]])
        let prompt = try #require(object["agentPrompt"] as? String)

        #expect(response.statusCode == 200)
        #expect(object["status"] as? String == "ok")
        #expect(library["resourceCount"] as? Int == 5)
        #expect(library["pinnedCount"] as? Int == 1)
        #expect(library["sessionCount"] as? Int == 1)
        #expect(library["memoryCount"] as? Int == 1)
        #expect(library["handoffCount"] as? Int == 1)
        #expect(privacy["clipboardDefault"] as? String == "Clipboard records are excluded from agent brief, recommendations, and context unless includeClipboard=true.")
        #expect(startupFlow.contains { $0.contains("/system/status") })
        #expect(startupFlow.contains { $0.contains("/agent/brief") })
        #expect(startupFlow.contains { $0.contains("/agent/presence") })
        #expect(startupFlow.contains { $0.contains("/agent/sessions") })
        #expect(startupFlow.contains { $0.contains("/agent/memories") })
        #expect(commands.contains { ($0["id"] as? String) == "agent-toolkit" })
        #expect(commands.contains { ($0["id"] as? String) == "agent-presence" })
        #expect(commands.contains { ($0["id"] as? String) == "start-session" })
        #expect(commands.contains { ($0["id"] as? String) == "list-sessions" })
        #expect(commands.contains { ($0["id"] as? String) == "update-session" })
        #expect(commands.contains { ($0["id"] as? String) == "save-memory" })
        #expect(commands.contains { ($0["id"] as? String) == "list-memories" })
        #expect(prompt.contains("DingDong"))
        #expect(prompt.contains("http://127.0.0.1:8765"))
        #expect(prompt.contains("/agent/session"))
        #expect(prompt.contains("/agent/memory"))
    }

    @Test func systemStatusRouteReturnsLightweightCountsAndLimits() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Review prompt", content: "Review carefully", pinned: true),
            ResourceItem(type: .skill, title: "Review skill", content: "Use local skill"),
            ResourceItem(type: .clipboard, title: "Private clip", content: "private clipboard body", tags: ["clipboard", "text"])
        ])
        let events = AgentEventStore()
        events.record(DingRequest(message: "Build done", source: "Codex", sound: .random))
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Testing status", capabilities: ["tests"]))
        let router = NotificationRouter(
            handleDing: { _ in },
            resourceStore: store,
            agentEventStore: events,
            agentPresenceStore: presence,
            clipboardMonitoringState: { true }
        )

        let response = router.route(HTTPRequest(method: "GET", path: "/system/status", body: Data()))
        let object = try jsonObject(response.body)
        let runtime = try #require(object["runtime"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Any])
        let byType = try #require(counts["byType"] as? [String: Int])
        let clipboard = try #require(object["clipboard"] as? [String: Any])
        let limits = try #require(object["limits"] as? [String: Any])
        let performance = try #require(object["performance"] as? [String: Any])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(runtime["clipboardMonitoringEnabled"] as? Bool == true)
        #expect(counts["resources"] as? Int == 3)
        #expect(counts["pinnedResources"] as? Int == 1)
        #expect(counts["recentAgentEvents"] as? Int == 1)
        #expect(counts["activeAgents"] as? Int == 1)
        #expect(byType["prompt"] == 1)
        #expect(byType["skill"] == 1)
        #expect(byType["clipboard"] == 1)
        #expect(clipboard["total"] as? Int == 1)
        let clipboardPolicy = ResourceStore.clipboardRetentionPolicy()
        #expect(limits["clipboardHistory"] as? Int == clipboardPolicy.maxItems)
        #expect(limits["clipboardRetentionDays"] as? Int == clipboardPolicy.maxAgeDays)
        #expect(performance["knowledgeIndexing"] as? String == "on-demand only")
        #expect(!body.contains("private clipboard body"))
    }

    @Test func agentStartupRouteReturnsBriefAndContextWithoutClipboardByDefault() throws {
        let prompt = ResourceItem(
            type: .prompt,
            group: "Review",
            title: "Review prompt",
            content: "Review carefully before changing code",
            tags: ["review"],
            pinned: true
        )
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Clipboard",
            title: "Review clipboard",
            content: "private review clipboard text",
            tags: ["review"]
        )
        let store = InMemoryResourceStore(items: [prompt, clipboard])
        let events = AgentEventStore()
        events.record(DingRequest(message: "Previous build done", source: "Codex", sound: .sparkle))
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Reviewing", capabilities: ["code"]))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, agentEventStore: events, agentPresenceStore: presence)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/startup?task=review&limit=5", body: Data()))
        let object = try jsonObject(response.body)
        let brief = try #require(object["brief"] as? [String: Any])
        let context = try #require(object["context"] as? [String: Any])
        let items = try #require(context["items"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["query"] as? String == "review")
        #expect((object["commandIDs"] as? [String])?.contains("agent-startup") == true)
        #expect((brief["pinned"] as? [[String: Any]])?.first?["title"] as? String == "Review prompt")
        #expect((brief["activeAgents"] as? [[String: Any]])?.first?["source"] as? String == "Codex")
        #expect(items.count == 1)
        #expect(items.first?["type"] as? String == "prompt")
        #expect(!body.contains("private review clipboard text"))
    }

    @Test func agentStartupRouteCanIncludeClipboardExplicitly() throws {
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Clipboard",
            title: "Review clipboard",
            content: "copy this review command",
            tags: ["review"]
        )
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/startup?task=review&includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let context = try #require(object["context"] as? [String: Any])
        let items = try #require(context["items"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(items.first?["type"] as? String == "clipboard")
        #expect(items.first?["contentExcerpt"] as? String == "copy this review command")
    }

    @Test func agentBridgeRouteReturnsSummariesAndNoSkillOrMCPContentByDefault() throws {
        let prompt = ResourceItem(
            type: .prompt,
            group: "Prompts",
            title: "Sentence prefix marker",
            content: "每句话开头加一个「🔸」。",
            tags: ["style"],
            pinned: true
        )
        let skill = ResourceItem(
            type: .skill,
            group: "Skills",
            title: "user-taste",
            content: String(repeating: "Use the user's taste guidance. ", count: 60) + "FULL_SKILL_BODY",
            tags: ["taste"],
            pinned: true
        )
        let mcp = ResourceItem(
            type: .mcp,
            group: "MCP Servers",
            title: "codebase-memory-mcp",
            content: String(repeating: "Local command: codebase-memory-mcp. ", count: 60) + "FULL_MCP_BODY",
            tags: ["codebase"],
            pinned: true
        )
        let unpinnedPrompt = ResourceItem(
            type: .prompt,
            group: "Prompts",
            title: "Other prompt",
            content: "Do not include unless task matches",
            tags: []
        )
        let clipboard = ResourceItem(
            type: .clipboard,
            group: "Clipboard",
            title: "Private clipboard",
            content: "private clipboard body",
            tags: ["style"],
            pinned: true
        )
        let store = InMemoryResourceStore(items: [prompt, skill, mcp, unpinnedPrompt, clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/bridge?source=Codex&task=style&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let active = try #require(object["active"] as? [String: Any])
        let prompts = try #require(active["prompts"] as? [[String: Any]])
        let skills = try #require(active["skills"] as? [[String: Any]])
        let mcps = try #require(active["mcpServers"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["mode"] as? String == "minimal-bridge-summary")
        #expect(object["source"] as? String == "Codex")
        #expect(prompts.map { $0["title"] as? String }.contains("Sentence prefix marker"))
        #expect(prompts.first?["contentIncluded"] as? Bool == true)
        #expect(prompts.first?["content"] as? String == "每句话开头加一个「🔸」。")
        #expect(skills.first?["title"] as? String == "user-taste")
        #expect(skills.first?["contentIncluded"] as? Bool == false)
        #expect(skills.first?["content"] as? String == nil)
        #expect(skills.first?["detailURL"] as? String == "/agent/resource/\(skill.id.uuidString)")
        #expect(mcps.first?["title"] as? String == "codebase-memory-mcp")
        #expect(mcps.first?["contentIncluded"] as? Bool == false)
        #expect(mcps.first?["content"] as? String == nil)
        #expect(!body.contains("private clipboard body"))
        #expect(!body.contains("Other prompt"))
        #expect(!body.contains("FULL_SKILL_BODY"))
        #expect(!body.contains("FULL_MCP_BODY"))
    }

    @Test func agentBridgeRouteCanExpandAllContentExplicitly() throws {
        let skill = ResourceItem(
            type: .skill,
            group: "Skills",
            title: "user-taste",
            content: "FULL_SKILL_BODY",
            tags: ["taste"],
            pinned: true
        )
        let mcp = ResourceItem(
            type: .mcp,
            group: "MCP Servers",
            title: "codebase-memory-mcp",
            content: "FULL_MCP_BODY",
            tags: ["codebase"],
            pinned: true
        )
        let store = InMemoryResourceStore(items: [skill, mcp])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/bridge?source=Codex&task=taste&limit=10&expand=all", body: Data()))
        let object = try jsonObject(response.body)
        let active = try #require(object["active"] as? [String: Any])
        let skills = try #require(active["skills"] as? [[String: Any]])
        let mcps = try #require(active["mcpServers"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(skills.first?["contentIncluded"] as? Bool == true)
        #expect(skills.first?["content"] as? String == "FULL_SKILL_BODY")
        #expect(mcps.first?["contentIncluded"] as? Bool == true)
        #expect(mcps.first?["content"] as? String == "FULL_MCP_BODY")
    }

    @Test func agentPrepareRouteReturnsOneCallTaskSetupWithoutClipboardContentByDefault() throws {
        let prompt = ResourceItem(type: .prompt, group: "Review", title: "Review prompt", content: "Review carefully", tags: ["review"], pinned: true)
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "private review clipboard text", tags: ["clipboard", "review", "command"])
        let sensitive = ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        let store = InMemoryResourceStore(items: [prompt, clipboard, sensitive])
        let events = AgentEventStore()
        events.record(DingRequest(message: "Previous build done", source: "Codex", sound: .sparkle))
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Reviewing", capabilities: ["code"]))
        let router = NotificationRouter(
            handleDing: { _ in },
            resourceStore: store,
            agentEventStore: events,
            agentPresenceStore: presence,
            clipboardMonitoringState: { true }
        )

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/prepare?task=review&limit=4", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let statusSummary = try #require(object["statusSummary"] as? [String: Any])
        let startup = try #require(object["startup"] as? [String: Any])
        let recommendations = try #require(object["recommendations"] as? [String: Any])
        let clipboardInsights = try #require(object["clipboardInsights"] as? [String: Any])
        let insightsPrivacy = try #require(clipboardInsights["privacy"] as? [String: Any])
        let commandIDs = try #require(object["commandIDs"] as? [String])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["task"] as? String == "review")
        #expect(privacy["clipboardContentIncluded"] as? Bool == false)
        #expect(statusSummary["status"] as? String == "ok")
        #expect(startup["query"] as? String == "review")
        #expect((recommendations["recommendations"] as? [[String: Any]])?.first?["title"] as? String == "Review prompt")
        #expect(insightsPrivacy["contentIncluded"] as? Bool == false)
        #expect(insightsPrivacy["hiddenSensitiveItems"] as? Int == 1)
        #expect(commandIDs.contains("agent-prepare"))
        #expect(!body.contains("private review clipboard text"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func agentPrepareRouteCanIncludeClipboardContentAndSensitiveInsightMetadataExplicitly() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "copy this review command", tags: ["clipboard", "review", "alias:review"])
        let sensitive = ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review", "alias:token"])
        let store = InMemoryResourceStore(items: [clipboard, sensitive])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/prepare?task=review&includeClipboard=true&includeSensitiveClipboardInsights=true", body: Data()))
        let object = try jsonObject(response.body)
        let startup = try #require(object["startup"] as? [String: Any])
        let context = try #require(startup["context"] as? [String: Any])
        let contextItems = try #require(context["items"] as? [[String: Any]])
        let clipboardInsights = try #require(object["clipboardInsights"] as? [String: Any])
        let insightsPrivacy = try #require(clipboardInsights["privacy"] as? [String: Any])
        let snippetCandidates = try #require(clipboardInsights["snippetCandidates"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(contextItems.first?["contentExcerpt"] as? String == "copy this review command")
        #expect(insightsPrivacy["sensitiveClipboardIncluded"] as? Bool == true)
        #expect(insightsPrivacy["hiddenSensitiveItems"] as? Int == 0)
        #expect(snippetCandidates.contains { ($0["title"] as? String) == "Review token" })
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func agentWorkbenchRouteSummarizesResumableWorkWithoutClipboardContent() throws {
        let session = try AgentSessionRequest(
            task: "Review task",
            title: "Review active session",
            summary: "Keep reviewing the API.",
            currentStep: "Add tests",
            nextActions: ["Run focused tests"],
            resourceIDs: nil,
            source: "Codex",
            status: "active",
            tags: ["review"],
            pinned: true
        ).makeResource()
        let completedSession = try AgentSessionRequest(
            task: "Review done",
            title: "Review completed session",
            summary: nil,
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Codex",
            status: "done",
            tags: ["review"],
            pinned: nil
        ).makeResource()
        let handoff = try AgentHandoffRequest(
            title: "Review handoff",
            summary: "Continue the review flow.",
            nextSteps: ["Check runtime route"],
            blockers: nil,
            artifacts: nil,
            source: "Claude",
            status: "open",
            tags: ["review"],
            pinned: nil
        ).makeResource()
        let memory = try AgentMemoryRequest(
            title: "Review preference",
            content: "Prefer small focused tests before full verification.",
            task: "review",
            kind: "preference",
            source: "Codex",
            tags: ["review"],
            pinned: nil
        ).makeResource()
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "private workbench clipboard text", tags: ["review"])
        let store = InMemoryResourceStore(items: [session, completedSession, handoff, memory, clipboard])
        let presence = AgentPresenceStore()
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Review task", capabilities: ["code"]))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, agentPresenceStore: presence)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/workbench?task=review&limit=5", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Any])
        let activeAgents = try #require(object["activeAgents"] as? [[String: Any]])
        let workItems = try #require(object["workItems"] as? [[String: Any]])
        let activeSessions = try #require(object["activeSessions"] as? [[String: Any]])
        let openHandoffs = try #require(object["openHandoffs"] as? [[String: Any]])
        let relevantMemories = try #require(object["relevantMemories"] as? [[String: Any]])
        let commandIDs = try #require(object["commandIDs"] as? [String])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["task"] as? String == "review")
        #expect(privacy["clipboardContentIncluded"] as? Bool == false)
        #expect(counts["sessions"] as? Int == 2)
        #expect(counts["handoffs"] as? Int == 1)
        #expect(counts["memories"] as? Int == 1)
        #expect(activeAgents.first?["source"] as? String == "Codex")
        #expect(workItems.first?["title"] as? String == "Review active session")
        #expect(activeSessions.count == 1)
        #expect(activeSessions.first?["status"] as? String == "active")
        #expect(openHandoffs.first?["kind"] as? String == "handoff")
        #expect(relevantMemories.first?["memoryKind"] as? String == "preference")
        #expect(commandIDs.contains("agent-workbench"))
        #expect(commandIDs.contains("update-session"))
        #expect(!body.contains("private workbench clipboard text"))
    }

    @Test func agentInstructionsRouteReturnsCopyablePromptWithoutClipboardByDefault() throws {
        let prompt = ResourceItem(type: .prompt, group: "Review", title: "Code review stance", content: "Review for regressions and missing tests.", tags: ["code", "review"], pinned: true)
        let skill = ResourceItem(type: .skill, group: "Skills", title: "Review skill", content: "/Users/me/.codex/skills/review/SKILL.md", tags: ["review"])
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "private clipboard review text", tags: ["clipboard", "review"])
        let session = try AgentSessionRequest(
            task: "Code review",
            title: nil,
            summary: "Existing active session.",
            currentStep: "Run tests",
            nextActions: ["Patch failures"],
            resourceIDs: [prompt.id.uuidString],
            source: "Codex",
            status: "active",
            tags: ["review"],
            pinned: nil
        ).makeResource()
        let store = InMemoryResourceStore(items: [prompt, skill, clipboard, session])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/instructions?task=code%20review&limit=4", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let activeSessions = try #require(object["activeSessions"] as? [[String: Any]])
        let recommendedResources = try #require(object["recommendedResources"] as? [[String: Any]])
        let commandIDs = try #require(object["commandIDs"] as? [String])
        let copyablePrompt = try #require(object["copyablePrompt"] as? String)
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["task"] as? String == "code review")
        #expect(privacy["clipboardIncluded"] as? Bool == false)
        #expect(activeSessions.first?["title"] as? String == "Code review")
        #expect(recommendedResources.first?["title"] as? String == "Code review stance")
        #expect(commandIDs.contains("agent-instructions"))
        #expect(commandIDs.contains("start-session"))
        #expect(commandIDs.contains("update-session"))
        #expect(copyablePrompt.contains("DingDong"))
        #expect(copyablePrompt.contains("/agent/session"))
        #expect(copyablePrompt.contains("/agent/resolve?q=code%20review"))
        #expect(copyablePrompt.contains(prompt.id.uuidString))
        #expect(!body.contains("private clipboard review text"))
    }

    @Test func agentInstructionsRouteCanIncludeClipboardExplicitly() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "copy this review command", tags: ["clipboard", "review"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/instructions?task=review&includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let recommendedResources = try #require(object["recommendedResources"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(recommendedResources.first?["type"] as? String == "clipboard")
        #expect(recommendedResources.first?["contentExcerpt"] as? String == "copy this review command")
    }

    @Test func agentInstructionsRouteRejectsMissingOrInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTask = router.route(HTTPRequest(method: "GET", path: "/agent/instructions", body: Data()))
        let invalidType = router.route(HTTPRequest(method: "GET", path: "/agent/instructions?task=review&type=bad", body: Data()))
        let invalidClipboardFlag = router.route(HTTPRequest(method: "GET", path: "/agent/instructions?task=review&includeClipboard=maybe", body: Data()))

        #expect(missingTask.statusCode == 400)
        #expect(invalidType.statusCode == 400)
        #expect(invalidClipboardFlag.statusCode == 400)
    }

    @Test func agentPrepareRouteRejectsMissingOrInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTask = router.route(HTTPRequest(method: "GET", path: "/agent/prepare", body: Data()))
        let invalidType = router.route(HTTPRequest(method: "GET", path: "/agent/prepare?task=review&type=bad", body: Data()))
        let invalidFlag = router.route(HTTPRequest(method: "GET", path: "/agent/prepare?task=review&includeSensitiveClipboardInsights=maybe", body: Data()))

        #expect(missingTask.statusCode == 400)
        #expect(invalidType.statusCode == 400)
        #expect(invalidFlag.statusCode == 400)
    }

    @Test func agentPresenceRouteRecordsAndListsActiveAgents() throws {
        let presence = AgentPresenceStore()
        let router = NotificationRouter(handleDing: { _ in }, agentPresenceStore: presence)
        let body = Data(#"{"source":"Codex","status":"active","task":"Implement presence","capabilities":["code","tests"]}"#.utf8)

        let postResponse = router.route(HTTPRequest(method: "POST", path: "/agent/presence", body: body))
        let listResponse = router.route(HTTPRequest(method: "GET", path: "/agent/presence?activeWithin=900&limit=10", body: Data()))
        let object = try jsonObject(listResponse.body)
        let agents = try #require(object["agents"] as? [[String: Any]])
        let first = try #require(agents.first)

        #expect(postResponse.statusCode == 200)
        #expect(listResponse.statusCode == 200)
        #expect(object["count"] as? Int == 1)
        #expect(first["source"] as? String == "Codex")
        #expect(first["status"] as? String == "active")
        #expect(first["task"] as? String == "Implement presence")
        #expect(first["capabilities"] as? [String] == ["code", "tests"])
    }

    @Test func agentPresenceRouteRejectsMissingSource() throws {
        let router = NotificationRouter(handleDing: { _ in }, agentPresenceStore: AgentPresenceStore())
        let body = Data(#"{"source":"   ","status":"active"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/presence", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func agentBriefRouteReturnsStartupSummaryWithoutClipboardByDefault() throws {
        let prompt = ResourceItem(type: .prompt, group: "Review", title: "Pinned review prompt", content: "Review carefully", pinned: true)
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Private clip", content: "secret clipboard text", pinned: true)
        let store = InMemoryResourceStore(items: [prompt, clipboard])
        let events = AgentEventStore()
        let presence = AgentPresenceStore()
        events.record(DingRequest(message: "Build finished", source: "Codex", sound: .sparkle), createdAt: Date(timeIntervalSince1970: 40))
        try presence.upsert(AgentPresenceRequest(source: "Codex", status: "active", task: "Testing brief", capabilities: ["tests"]))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, agentEventStore: events, agentPresenceStore: presence)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/brief", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let pinned = try #require(object["pinned"] as? [[String: Any]])
        let groups = try #require(object["groups"] as? [[String: Any]])
        let activeAgents = try #require(object["activeAgents"] as? [[String: Any]])
        let recentEvents = try #require(object["recentAgentEvents"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(privacy["clipboardIncluded"] as? Bool == false)
        #expect(pinned.count == 1)
        #expect(pinned.first?["title"] as? String == "Pinned review prompt")
        #expect(groups.contains { ($0["group"] as? String) == "Review" })
        #expect(activeAgents.first?["source"] as? String == "Codex")
        #expect(!groups.contains { ($0["type"] as? String) == "clipboard" })
        #expect(recentEvents.first?["message"] as? String == "Build finished")
        #expect(!body.contains("secret clipboard text"))
    }

    @Test func agentBriefRouteCanIncludeClipboardExplicitly() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Clip", content: "copy this command", pinned: true)
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/brief?includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let pinned = try #require(object["pinned"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(pinned.first?["type"] as? String == "clipboard")
        #expect(pinned.first?["contentExcerpt"] as? String == "copy this command")
    }

    @Test func agentBriefRouteExcludesSensitiveClipboardUnlessExplicit() throws {
        let sensitive = ResourceItem(
            type: .clipboard,
            group: "Sensitive",
            title: "Sensitive API key",
            content: "OPENAI_API_KEY=sk-secret-value",
            tags: ["clipboard", "sensitive", "secret"],
            pinned: true
        )
        let store = InMemoryResourceStore(items: [sensitive])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/agent/brief?includeClipboard=true", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/agent/brief?includeClipboard=true&includeSensitiveClipboard=true", body: Data()))

        #expect(defaultResponse.statusCode == 200)
        #expect(!String(data: defaultResponse.body, encoding: .utf8)!.contains("sk-secret-value"))
        #expect(String(data: explicitResponse.body, encoding: .utf8)!.contains("sk-secret-value"))
    }

    @Test func agentBriefRouteRejectsInvalidClipboardFlag() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/brief?includeClipboard=maybe", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func agentRecommendRouteRanksRelevantPinnedResources() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, group: "Review", title: "Code review checklist", content: "Find regressions and missing tests", tags: ["review", "codex"], pinned: true),
            ResourceItem(type: .knowledge, group: "Docs", title: "Travel notes", content: "Trip plan", tags: ["personal"]),
            ResourceItem(type: .prompt, group: "Deploy", title: "Deploy prompt", content: "Ship release", tags: ["release"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=code%20review&limit=2", body: Data()))
        let object = try jsonObject(response.body)
        let recommendations = try #require(object["recommendations"] as? [[String: Any]])
        let first = try #require(recommendations.first)

        #expect(response.statusCode == 200)
        #expect(recommendations.count == 1)
        #expect(first["title"] as? String == "Code review checklist")
        #expect(first["type"] as? String == "prompt")
        #expect(first["score"] as? Int ?? 0 > 0)
        #expect((first["reasons"] as? [String])?.contains("title:code") == true)
    }

    @Test func agentRecommendRouteFiltersTypeAndExcludesClipboardByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .skill, group: "Review", title: "Review skill", content: "Use this skill", tags: ["review"]),
            ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "private review text", tags: ["review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=review&type=skill", body: Data()))
        let object = try jsonObject(response.body)
        let recommendations = try #require(object["recommendations"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(recommendations.count == 1)
        #expect(recommendations.first?["type"] as? String == "skill")
        #expect(!body.contains("private review text"))
    }

    @Test func agentRecommendRouteCanIncludeClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "copy this review command", tags: ["review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?task=review&includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let recommendations = try #require(object["recommendations"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(recommendations.first?["type"] as? String == "clipboard")
        #expect(recommendations.first?["contentExcerpt"] as? String == "copy this review command")
    }

    @Test func agentRecommendRouteExcludesSensitiveClipboardUnlessExplicit() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "review token sk-secret-value", tags: ["review", "sensitive", "secret"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=review&includeClipboard=true", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=review&includeClipboard=true&includeSensitiveClipboard=true", body: Data()))
        let defaultObject = try jsonObject(defaultResponse.body)
        let explicitObject = try jsonObject(explicitResponse.body)
        let defaultRecommendations = try #require(defaultObject["recommendations"] as? [[String: Any]])
        let explicitRecommendations = try #require(explicitObject["recommendations"] as? [[String: Any]])

        #expect(defaultResponse.statusCode == 200)
        #expect(defaultRecommendations.isEmpty)
        #expect(explicitRecommendations.first?["contentExcerpt"] as? String == "review token sk-secret-value")
    }

    @Test func agentRecommendRouteRejectsMissingOrInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingQuery = router.route(HTTPRequest(method: "GET", path: "/agent/recommend", body: Data()))
        let invalidType = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=review&type=bad", body: Data()))
        let invalidClipboardFlag = router.route(HTTPRequest(method: "GET", path: "/agent/recommend?q=review&includeClipboard=maybe", body: Data()))

        #expect(missingQuery.statusCode == 400)
        #expect(invalidType.statusCode == 400)
        #expect(invalidClipboardFlag.statusCode == 400)
    }

    @Test func agentResolveRouteReturnsBestMatchingResourceDetail() throws {
        let weaker = ResourceItem(type: .prompt, group: "General", title: "Review", content: "General review prompt")
        let stronger = ResourceItem(type: .prompt, group: "Engineering", title: "Code review checklist", content: "Use this code review checklist", tags: ["code", "review"], pinned: true)
        let store = InMemoryResourceStore(items: [weaker, stronger])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=code%20review&type=prompt", body: Data()))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])
        let resolution = try #require(object["resolution"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(object["status"] as? String == "ok")
        #expect(object["query"] as? String == "code review")
        #expect(item["id"] as? String == stronger.id.uuidString)
        #expect(item["content"] as? String == "Use this code review checklist")
        #expect(resolution["matched"] as? Bool == true)
        #expect((resolution["score"] as? Int ?? 0) > 0)
    }

    @Test func agentResolveRouteExcludesClipboardByDefault() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "private review text", tags: ["clipboard", "review"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))
        let object = try jsonObject(response.body)

        #expect(response.statusCode == 404)
        #expect(object["status"] as? String == "not_found")
        #expect(!body.contains("private review text"))
    }

    @Test func agentResolveRouteCanIncludeClipboardExplicitly() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Review clipboard", content: "copy this review command", tags: ["clipboard", "review"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review&includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(item["type"] as? String == "clipboard")
        #expect(item["content"] as? String == "copy this review command")
    }

    @Test func agentResolveRouteExcludesSensitiveClipboardUnlessExplicit() throws {
        let sensitive = ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "review token sk-secret-value", tags: ["clipboard", "review", "sensitive"])
        let store = InMemoryResourceStore(items: [sensitive])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review&includeClipboard=true", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review&includeClipboard=true&includeSensitiveClipboard=true", body: Data()))
        let defaultBody = try #require(String(data: defaultResponse.body, encoding: .utf8))
        let explicitObject = try jsonObject(explicitResponse.body)
        let explicitItem = try #require(explicitObject["item"] as? [String: Any])

        #expect(defaultResponse.statusCode == 404)
        #expect(!defaultBody.contains("sk-secret-value"))
        #expect(explicitResponse.statusCode == 200)
        #expect(explicitItem["content"] as? String == "review token sk-secret-value")
    }

    @Test func agentResolveRouteRejectsMissingOrInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingQuery = router.route(HTTPRequest(method: "GET", path: "/agent/resolve", body: Data()))
        let invalidType = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review&type=bad", body: Data()))
        let invalidClipboardFlag = router.route(HTTPRequest(method: "GET", path: "/agent/resolve?q=review&includeClipboard=maybe", body: Data()))

        #expect(missingQuery.statusCode == 400)
        #expect(invalidType.statusCode == 400)
        #expect(invalidClipboardFlag.statusCode == 400)
    }

    @Test func agentResourceRouteReturnsSharedResourceContent() throws {
        let prompt = ResourceItem(type: .prompt, group: "Review", title: "Review prompt", content: "Use this review prompt", tags: ["review"], pinned: true)
        let store = InMemoryResourceStore(items: [prompt])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(prompt.id.uuidString)", body: Data()))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])
        let privacy = try #require(object["privacy"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(item["id"] as? String == prompt.id.uuidString)
        #expect(item["type"] as? String == "prompt")
        #expect(item["content"] as? String == "Use this review prompt")
        #expect(item["contentCharacterCount"] as? Int == prompt.content.count)
        #expect(privacy["contentIncluded"] as? Bool == true)
    }

    @Test func agentResourceRouteHidesClipboardContentByDefault() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Commands", title: "Deploy command", content: "curl -sS https://example.com/deploy", tags: ["clipboard", "command"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(clipboard.id.uuidString)", body: Data()))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])
        let privacy = try #require(object["privacy"] as? [String: Any])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(item["id"] as? String == clipboard.id.uuidString)
        #expect(item["type"] as? String == "clipboard")
        #expect(item["classification"] as? String == "command")
        #expect(item["content"] == nil)
        #expect(privacy["contentIncluded"] as? Bool == false)
        #expect(privacy["clipboardContentIncluded"] as? Bool == false)
        #expect(!body.contains("https://example.com/deploy"))
    }

    @Test func agentResourceRouteCanIncludeClipboardContentExplicitly() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Commands", title: "Deploy command", content: "make deploy", tags: ["clipboard", "command"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(clipboard.id.uuidString)?includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])
        let privacy = try #require(object["privacy"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(item["content"] as? String == "make deploy")
        #expect(privacy["contentIncluded"] as? Bool == true)
        #expect(privacy["clipboardContentIncluded"] as? Bool == true)
    }

    @Test func agentResourceRouteRequiresSensitiveClipboardFlagForSensitiveContent() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "token=sk-secret-value", tags: ["clipboard", "sensitive", "secret"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(clipboard.id.uuidString)?includeClipboard=true", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(clipboard.id.uuidString)?includeClipboard=true&includeSensitiveClipboard=true", body: Data()))
        let defaultObject = try jsonObject(defaultResponse.body)
        let explicitObject = try jsonObject(explicitResponse.body)
        let defaultItem = try #require(defaultObject["item"] as? [String: Any])
        let explicitItem = try #require(explicitObject["item"] as? [String: Any])
        let defaultBody = try #require(String(data: defaultResponse.body, encoding: .utf8))

        #expect(defaultResponse.statusCode == 200)
        #expect(defaultItem["sensitive"] as? Bool == true)
        #expect(defaultItem["content"] == nil)
        #expect(!defaultBody.contains("sk-secret-value"))
        #expect(explicitResponse.statusCode == 200)
        #expect(explicitItem["content"] as? String == "token=sk-secret-value")
    }

    @Test func agentResourceRouteRejectsInvalidInputs() throws {
        let prompt = ResourceItem(type: .prompt, title: "Prompt", content: "Use this")
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore(items: [prompt]))

        let invalidID = router.route(HTTPRequest(method: "GET", path: "/agent/resource/not-a-uuid", body: Data()))
        let missingResource = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(UUID().uuidString)", body: Data()))
        let invalidClipboardFlag = router.route(HTTPRequest(method: "GET", path: "/agent/resource/\(prompt.id.uuidString)?includeClipboard=maybe", body: Data()))

        #expect(invalidID.statusCode == 400)
        #expect(missingResource.statusCode == 404)
        #expect(invalidClipboardFlag.statusCode == 400)
    }

    @Test func agentBundleRouteCreatesKnowledgeBundleWithoutClipboardByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(
                type: .prompt,
                group: "Review",
                title: "Code review checklist",
                content: "Use this code review checklist for correctness and tests.",
                tags: ["code", "review"],
                pinned: true
            ),
            ResourceItem(
                type: .clipboard,
                group: "Clipboard",
                title: "Code review clipboard",
                content: "private code review clipboard text",
                tags: ["code", "review"]
            )
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Code review bundle",
          "task":"code review",
          "limit":5,
          "source":"Codex",
          "tags":["review"]
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/bundle", body: body))
        let stored = try store.list(type: .knowledge, query: "Code review bundle", limit: nil)
        let bundle = try #require(stored.first)
        let responseText = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 201)
        #expect(bundle.group == "Agent Bundles")
        #expect(bundle.source == "Codex")
        #expect(bundle.pinned == true)
        #expect(bundle.tags.contains("agent-bundle"))
        #expect(bundle.tags.contains("task:code"))
        #expect(bundle.content.contains("Code review checklist"))
        #expect(!bundle.content.contains("private code review clipboard text"))
        #expect(!responseText.contains("private code review clipboard text"))
    }

    @Test func agentBundleRouteCanIncludeClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(
                type: .clipboard,
                group: "Clipboard",
                title: "Code review clipboard",
                content: "copy this code review command",
                tags: ["code", "review"]
            )
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Clipboard review bundle",
          "task":"code review",
          "includeClipboard":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/bundle", body: body))
        let stored = try store.list(type: .knowledge, query: "Clipboard review bundle", limit: nil)
        let bundle = try #require(stored.first)

        #expect(response.statusCode == 201)
        #expect(bundle.content.contains("copy this code review command"))
        #expect(bundle.content.contains("Clipboard included: true"))
    }

    @Test func agentBundleRouteRejectsMissingSelection() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())
        let body = Data(#"{"title":"Empty bundle"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/bundle", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func agentSessionRouteCreatesSharedTaskSession() throws {
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "task":"Code review",
          "summary":"Review current changes.",
          "currentStep":"Inspect repository",
          "nextActions":["Run tests","Record findings"],
          "resourceIDs":["resource-1"],
          "source":"Codex",
          "status":"active",
          "tags":["review"],
          "pinned":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/session", body: body))
        let stored = try store.list(type: .knowledge, query: "Code review", limit: nil)
        let session = try #require(stored.first)
        let object = try jsonObject(response.body)
        let next = try #require(object["next"] as? [String: Any])

        #expect(response.statusCode == 201)
        #expect(session.group == "Agent Sessions")
        #expect(session.title == "Code review")
        #expect(session.source == "Codex")
        #expect(session.pinned == true)
        #expect(session.tags.contains("session"))
        #expect(session.tags.contains("status:active"))
        #expect(session.tags.contains("source:codex"))
        #expect(session.tags.contains("review"))
        #expect(session.content.contains("- Task: Code review"))
        #expect(session.content.contains("## Current Step"))
        #expect(session.content.contains("- Run tests"))
        #expect(session.content.contains("- resource-1"))
        #expect((next["update"] as? String)?.contains("/agent/session/\(session.id.uuidString)") == true)
    }

    @Test func agentSessionsRouteFiltersByStatusAndSource() throws {
        let activeCodex = try AgentSessionRequest(
            task: "Review active",
            title: nil,
            summary: nil,
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Codex",
            status: "active",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 30))
        let activeClaude = try AgentSessionRequest(
            task: "Other active",
            title: nil,
            summary: nil,
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Claude",
            status: "active",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let doneCodex = try AgentSessionRequest(
            task: "Done task",
            title: nil,
            summary: nil,
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Codex",
            status: "done",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 10))
        let otherKnowledge = ResourceItem(type: .knowledge, group: "Knowledge", title: "Docs", content: "session word only")
        let store = InMemoryResourceStore(items: [otherKnowledge, activeCodex, activeClaude, doneCodex])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/sessions?status=active&source=Codex&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let items = try #require(object["items"] as? [[String: Any]])
        let counts = try #require(object["counts"] as? [String: Any])
        let byStatus = try #require(counts["byStatus"] as? [String: Int])
        let filter = try #require(object["filter"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(items.count == 1)
        #expect(items.first?["title"] as? String == "Review active")
        #expect(items.first?["group"] as? String == "Agent Sessions")
        #expect(filter["status"] as? String == "active")
        #expect(filter["source"] as? String == "codex")
        #expect(counts["total"] as? Int == 3)
        #expect(counts["returned"] as? Int == 1)
        #expect(byStatus["active"] == 2)
        #expect(byStatus["done"] == 1)
    }

    @Test func agentSessionPatchAppendsProgressAndStatus() throws {
        let session = try AgentSessionRequest(
            task: "Review session",
            title: nil,
            summary: "Start review.",
            currentStep: nil,
            nextActions: nil,
            resourceIDs: nil,
            source: "Codex",
            status: "active",
            tags: ["api"],
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let store = InMemoryResourceStore(items: [session])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "status":"blocked",
          "progress":"Waiting for design approval.",
          "currentStep":"Ask user for direction",
          "nextActions":["Resume after answer"],
          "resourceIDs":["resource-2"],
          "source":"Claude",
          "pinned":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/agent/session/\(session.id.uuidString)", body: body))
        let stored = try #require(try store.list(type: .knowledge, query: "Review session", limit: nil).first)

        #expect(response.statusCode == 200)
        #expect(stored.pinned == true)
        #expect(stored.source == "Claude")
        #expect(stored.tags.contains("session"))
        #expect(stored.tags.contains("api"))
        #expect(stored.tags.contains("status:blocked"))
        #expect(!stored.tags.contains("status:active"))
        #expect(stored.tags.contains("source:claude"))
        #expect(stored.content.contains("## Checkpoint"))
        #expect(stored.content.contains("- Status: blocked"))
        #expect(stored.content.contains("- Current Step: Ask user for direction"))
        #expect(stored.content.contains("Waiting for design approval."))
        #expect(stored.content.contains("- Resume after answer"))
        #expect(stored.content.contains("- resource-2"))
    }

    @Test func agentSessionRoutesRejectInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTask = router.route(HTTPRequest(method: "POST", path: "/agent/session", body: Data(#"{"task":""}"#.utf8)))
        let invalidID = router.route(HTTPRequest(method: "PATCH", path: "/agent/session/not-a-uuid", body: Data(#"{"status":"done"}"#.utf8)))
        let missingSession = router.route(HTTPRequest(method: "PATCH", path: "/agent/session/\(UUID().uuidString)", body: Data(#"{"status":"done"}"#.utf8)))

        #expect(missingTask.statusCode == 400)
        #expect(invalidID.statusCode == 400)
        #expect(missingSession.statusCode == 404)
    }

    @Test func agentMemoryRouteCreatesDurableKnowledgeMemory() throws {
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Review preference",
          "content":"Always check regression tests before reporting completion.",
          "task":"code review",
          "kind":"preference",
          "source":"Codex",
          "tags":["review","tests"],
          "pinned":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/memory", body: body))
        let stored = try store.list(type: .knowledge, query: "Review preference", limit: nil)
        let memory = try #require(stored.first)

        #expect(response.statusCode == 201)
        #expect(memory.group == "Agent Memories")
        #expect(memory.title == "Review preference")
        #expect(memory.source == "Codex")
        #expect(memory.pinned == true)
        #expect(memory.tags.contains("memory"))
        #expect(memory.tags.contains("kind:preference"))
        #expect(memory.tags.contains("source:codex"))
        #expect(memory.tags.contains("task:code-review"))
        #expect(memory.tags.contains("review"))
        #expect(memory.content.contains("## Memory"))
        #expect(memory.content.contains("Always check regression tests"))
    }

    @Test func agentMemoriesRouteFiltersByQueryKindAndSource() throws {
        let review = try AgentMemoryRequest(
            title: "Review preference",
            content: "Always run regression tests.",
            task: "code review",
            kind: "preference",
            source: "Codex",
            tags: ["review"],
            pinned: true
        ).makeResource(now: Date(timeIntervalSince1970: 30))
        let release = try AgentMemoryRequest(
            title: "Release rule",
            content: "Package before release.",
            task: "release",
            kind: "rule",
            source: "Claude",
            tags: ["release"],
            pinned: false
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let otherKnowledge = ResourceItem(type: .knowledge, group: "Knowledge", title: "Memory word", content: "memory only")
        let store = InMemoryResourceStore(items: [otherKnowledge, release, review])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/memories?q=review&kind=preference&source=Codex&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let filter = try #require(object["filter"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(filter["q"] as? String == "review")
        #expect(filter["kind"] as? String == "preference")
        #expect(filter["source"] as? String == "codex")
        #expect(counts["total"] as? Int == 2)
        #expect(counts["returned"] as? Int == 1)
        #expect(items.first?["title"] as? String == "Review preference")
        #expect(items.first?["group"] as? String == "Agent Memories")
        #expect(items.first?["content"] as? String != nil)
    }

    @Test func agentMemoryRoutesRejectMissingRequiredFields() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTitle = router.route(HTTPRequest(method: "POST", path: "/agent/memory", body: Data(#"{"content":"Use this"}"#.utf8)))
        let missingContent = router.route(HTTPRequest(method: "POST", path: "/agent/memory", body: Data(#"{"title":"Memory"}"#.utf8)))

        #expect(missingTitle.statusCode == 400)
        #expect(missingContent.statusCode == 400)
    }

    @Test func agentHandoffRouteCreatesSharedKnowledgeNote() throws {
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Continue UI polish",
          "summary":"Panel is functional; visual QA remains.",
          "nextSteps":["Open panel","Check spacing"],
          "blockers":["Need screenshot review"],
          "artifacts":["/tmp/dingdong.png"],
          "source":"Codex",
          "status":"open",
          "tags":["ui"],
          "pinned":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/handoff", body: body))
        let stored = try store.list(type: .knowledge, query: "handoff", limit: nil)
        let handoff = try #require(stored.first)

        #expect(response.statusCode == 201)
        #expect(stored.count == 1)
        #expect(handoff.group == "Agent Handoffs")
        #expect(handoff.title == "Continue UI polish")
        #expect(handoff.source == "Codex")
        #expect(handoff.pinned == true)
        #expect(handoff.tags.contains("handoff"))
        #expect(handoff.tags.contains("status:open"))
        #expect(handoff.tags.contains("source:codex"))
        #expect(handoff.content.contains("## Next Steps"))
        #expect(handoff.content.contains("- Open panel"))
        #expect(handoff.content.contains("## Blockers"))
        #expect(handoff.content.contains("/tmp/dingdong.png"))
    }

    @Test func agentHandoffsRouteListsOnlyHandoffNotes() throws {
        let handoff = try AgentHandoffRequest(
            title: "Resume API work",
            summary: "Continue route testing.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let otherKnowledge = ResourceItem(type: .knowledge, group: "Knowledge", title: "Docs", content: "handoff word only")
        let store = InMemoryResourceStore(items: [otherKnowledge, handoff])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/handoffs?limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let items = try #require(object["items"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(items.count == 1)
        #expect(items.first?["title"] as? String == "Resume API work")
        #expect(items.first?["group"] as? String == "Agent Handoffs")
    }

    @Test func agentHandoffsRouteFiltersByStatusAndReturnsCounts() throws {
        let open = try AgentHandoffRequest(
            title: "Open task",
            summary: "Continue this task.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 30))
        let done = try AgentHandoffRequest(
            title: "Done task",
            summary: "Already finished.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "done",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let blocked = try AgentHandoffRequest(
            title: "Blocked task",
            summary: "Needs input.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "blocked",
            tags: nil,
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 10))
        let store = InMemoryResourceStore(items: [open, done, blocked])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/handoffs?status=open&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let items = try #require(object["items"] as? [[String: Any]])
        let counts = try #require(object["counts"] as? [String: Any])
        let byStatus = try #require(counts["byStatus"] as? [String: Int])
        let filter = try #require(object["filter"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(filter["status"] as? String == "open")
        #expect(items.count == 1)
        #expect(items.first?["title"] as? String == "Open task")
        #expect(counts["total"] as? Int == 3)
        #expect(counts["returned"] as? Int == 1)
        #expect(byStatus["open"] == 1)
        #expect(byStatus["done"] == 1)
        #expect(byStatus["blocked"] == 1)
    }

    @Test func agentHandoffPatchUpdatesStatusAndProgress() throws {
        let handoff = try AgentHandoffRequest(
            title: "Resume API work",
            summary: "Continue route testing.",
            nextSteps: nil,
            blockers: nil,
            artifacts: nil,
            source: "Codex",
            status: "open",
            tags: ["api"],
            pinned: nil
        ).makeResource(now: Date(timeIntervalSince1970: 20))
        let store = InMemoryResourceStore(items: [handoff])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"status":"done","progress":"Verified the endpoint.","source":"Claude","pinned":true}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/agent/handoff/\(handoff.id.uuidString)", body: body))
        let stored = try #require(try store.list(type: .knowledge, query: "Resume API", limit: nil).first)

        #expect(response.statusCode == 200)
        #expect(stored.pinned == true)
        #expect(stored.source == "Claude")
        #expect(stored.tags.contains("status:done"))
        #expect(!stored.tags.contains("status:open"))
        #expect(stored.tags.contains("source:claude"))
        #expect(stored.tags.contains("api"))
        #expect(stored.content.contains("## Status Update"))
        #expect(stored.content.contains("- Status: done"))
        #expect(stored.content.contains("## Progress"))
        #expect(stored.content.contains("Claude: Verified the endpoint."))
    }

    @Test func agentHandoffPatchRejectsMissingOrInvalidHandoff() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())
        let emptyBody = Data(#"{}"#.utf8)
        let updateBody = Data(#"{"status":"done"}"#.utf8)

        let noChanges = router.route(HTTPRequest(method: "PATCH", path: "/agent/handoff/\(UUID().uuidString)", body: emptyBody))
        let missing = router.route(HTTPRequest(method: "PATCH", path: "/agent/handoff/\(UUID().uuidString)", body: updateBody))

        #expect(noChanges.statusCode == 404)
        #expect(missing.statusCode == 404)
    }

    @Test func agentHandoffRouteRejectsMissingRequiredFields() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())
        let body = Data(#"{"title":"   ","summary":"Body"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/agent/handoff", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func agentContextRouteReturnsBoundedPackWithoutClipboardByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Review prompt", content: String(repeating: "A", count: 1_500), pinned: true),
            ResourceItem(type: .skill, title: "Review skill", content: "Use the local review skill"),
            ResourceItem(type: .clipboard, title: "Clipboard secret", content: "private clipboard text")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/context?q=review&limit=1", body: Data()))
        let object = try jsonObject(response.body)
        let items = try #require(object["items"] as? [[String: Any]])
        let privacy = try #require(object["privacy"] as? [String: Any])
        let firstItem = try #require(items.first)
        let excerpt = try #require(firstItem["contentExcerpt"] as? String)

        #expect(response.statusCode == 200)
        #expect(items.count == 1)
        #expect(firstItem["title"] as? String == "Review prompt")
        #expect((privacy["clipboardIncluded"] as? Bool) == false)
        #expect(excerpt.count == AgentContextPack.contentExcerptLimit + "\n[truncated]".count)
        #expect(!String(data: response.body, encoding: .utf8)!.contains("private clipboard text"))
    }

    @Test func agentContextRouteCanIncludeClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, title: "Clipboard note", content: "copy this command")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/context?includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let items = try #require(object["items"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(items.first?["type"] as? String == "clipboard")
        #expect(items.first?["title"] as? String == "Clipboard note")
    }

    @Test func agentContextRouteExcludesSensitiveClipboardUnlessExplicit() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Clipboard token", content: "token=sk-secret-value", tags: ["clipboard", "sensitive", "secret"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/agent/context?includeClipboard=true", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/agent/context?includeClipboard=true&includeSensitiveClipboard=true", body: Data()))
        let defaultObject = try jsonObject(defaultResponse.body)
        let explicitObject = try jsonObject(explicitResponse.body)
        let defaultItems = try #require(defaultObject["items"] as? [[String: Any]])
        let explicitItems = try #require(explicitObject["items"] as? [[String: Any]])

        #expect(defaultResponse.statusCode == 200)
        #expect(defaultItems.isEmpty)
        #expect(explicitItems.first?["contentExcerpt"] as? String == "token=sk-secret-value")
    }

    @Test func agentContextRouteRejectsInvalidClipboardFlag() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "GET", path: "/agent/context?includeClipboard=maybe", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func eventsRouteListsRecordedDingEvents() throws {
        let eventStore = AgentEventStore()
        let router = NotificationRouter(handleDing: { _ in }, agentEventStore: eventStore)
        let body = Data(#"{"message":"Deploy done","source":"Codex","sound":"muted"}"#.utf8)

        _ = router.route(HTTPRequest(method: "POST", path: "/ding", body: body))
        let response = router.route(HTTPRequest(method: "GET", path: "/events?limit=5", body: Data()))
        let responseBody = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(responseBody.contains("Deploy done"))
        #expect(responseBody.contains("Codex"))
    }

    @Test func dingRouteTriggersHandler() throws {
        var received: DingRequest?
        let router = NotificationRouter { request in received = request }
        let body = Data(#"{"message":"Deploy complete","sound":"system"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/ding", body: body))

        #expect(response.statusCode == 200)
        #expect(received?.message == "Deploy complete")
        #expect(received?.sound == .system)
    }

    @Test func badJsonReturnsBadRequest() throws {
        let router = NotificationRouter { _ in }

        let response = router.route(HTTPRequest(method: "POST", path: "/ding", body: Data("{".utf8)))

        #expect(response.statusCode == 400)
    }

    @Test func unknownRouteReturnsNotFound() throws {
        let router = NotificationRouter { _ in }

        let response = router.route(HTTPRequest(method: "GET", path: "/missing", body: Data()))

        #expect(response.statusCode == 404)
    }

    @Test func libraryPostCreatesResource() throws {
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {"type":"prompt","title":"Bug triage","content":"Find risky changes","tags":["review"],"source":"Codex","pinned":true}
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/library", body: body))
        let stored = try store.list(type: .prompt)

        #expect(response.statusCode == 201)
        #expect(stored.count == 1)
        #expect(stored.first?.title == "Bug triage")
        #expect(stored.first?.group == "Prompts")
    }

    @Test func libraryPostRejectsOversizedContent() throws {
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let oversized = String(repeating: "A", count: ResourceLimits.maxResourceContentCharacters + 1)
        let body = Data("""
        {"type":"prompt","title":"Too large","content":"\(oversized)"}
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/library", body: body))
        let stored = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(response.statusCode == 413)
        #expect(stored.isEmpty)
    }

    @Test func libraryImportRouteAddsResources() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-route-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "Prompt body".write(to: root.appendingPathComponent("prompt.txt"), atomically: true, encoding: .utf8)
        let store = InMemoryResourceStore()
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {"type":"prompt","path":"\(root.path)","tags":["bulk"],"source":"Codex"}
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/library/import", body: body))
        let stored = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(response.statusCode == 200)
        #expect(stored.count == 1)
        #expect(stored.first?.title == "prompt")
        #expect(stored.first?.tags == ["bulk"])
    }

    @Test func libraryImportRouteRejectsClipboardType() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())
        let body = Data(#"{"type":"clipboard","path":"/tmp"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/library/import", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func librarySeedDefaultsRouteIsCompatibilityNoop() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "User prompt", content: "Keep this")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let firstResponse = router.route(HTTPRequest(method: "POST", path: "/library/seed-defaults", body: Data()))
        let firstObject = try jsonObject(firstResponse.body)
        let firstDefaults = try #require(firstObject["defaults"] as? [String: Any])
        let secondResponse = router.route(HTTPRequest(method: "POST", path: "/library/seed-defaults", body: Data()))
        let secondObject = try jsonObject(secondResponse.body)
        let secondDefaults = try #require(secondObject["defaults"] as? [String: Any])
        let resources = try store.list(type: nil, query: nil, limit: nil)

        #expect(firstResponse.statusCode == 200)
        #expect(firstDefaults["inserted"] as? Int == 0)
        #expect(secondResponse.statusCode == 200)
        #expect(secondDefaults["inserted"] as? Int == 0)
        #expect(resources.map(\.title) == ["User prompt"])
    }

    @Test func libraryGetFiltersByType() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Prompt", content: "Prompt body"),
            ResourceItem(type: .mcp, title: "MCP", content: "MCP body")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library?type=mcp", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(body.contains(#""title":"MCP""#))
        #expect(!body.contains(#""title":"Prompt""#))
    }

    @Test func libraryGetSupportsQueryAndLimit() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, title: "Review A", content: "Prompt body"),
            ResourceItem(type: .prompt, title: "Review B", content: "Prompt body"),
            ResourceItem(type: .prompt, title: "Deploy", content: "Prompt body")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library?type=prompt&q=review&limit=1", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(body.contains("Review"))
        #expect(!body.contains("Deploy"))
    }

    @Test func libraryRejectsInvalidTypeFilter() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "GET", path: "/library?type=bad", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func libraryGroupsRouteSummarizesResourceGroups() throws {
        let olderDate = Date(timeIntervalSince1970: 10)
        let newerDate = Date(timeIntervalSince1970: 20)
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, group: "Review", title: "A", content: "Body", pinned: true, updatedAt: olderDate),
            ResourceItem(type: .prompt, group: "Review", title: "B", content: "Body", updatedAt: newerDate),
            ResourceItem(type: .skill, group: "Automation", title: "Skill", content: "Repo", updatedAt: newerDate)
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library/groups", body: Data()))
        let object = try jsonObject(response.body)
        let groups = try #require(object["groups"] as? [[String: Any]])
        let review = try #require(groups.first { ($0["group"] as? String) == "Review" })

        #expect(response.statusCode == 200)
        #expect(groups.count == 2)
        #expect(review["type"] as? String == "prompt")
        #expect(review["count"] as? Int == 2)
        #expect(review["pinnedCount"] as? Int == 1)
        #expect((review["latestUpdatedAt"] as? String)?.contains("1970-01-01T00:00:20") == true)
    }

    @Test func libraryGroupsRouteFiltersByType() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, group: "Review", title: "Prompt", content: "Body"),
            ResourceItem(type: .mcp, group: "Servers", title: "MCP", content: "npx server")
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library/groups?type=mcp", body: Data()))
        let object = try jsonObject(response.body)
        let groups = try #require(object["groups"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(groups.count == 1)
        #expect(groups.first?["type"] as? String == "mcp")
        #expect(groups.first?["group"] as? String == "Servers")
    }

    @Test func libraryGroupsRouteRejectsInvalidType() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "GET", path: "/library/groups?type=bad", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func libraryExportRouteExcludesClipboardByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .prompt, group: "Review", title: "Review prompt", content: "Review carefully", tags: ["review"], pinned: true),
            ResourceItem(type: .skill, group: "Review", title: "Review skill", content: "Use local skill", tags: ["review"]),
            ResourceItem(type: .clipboard, group: "Clipboard", title: "Private clip", content: "private clipboard body", tags: ["clipboard", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library/export?q=review&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Any])
        let byType = try #require(counts["byType"] as? [String: Int])
        let items = try #require(object["items"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["schemaVersion"] as? Int == LibraryExport.schemaVersion)
        #expect(privacy["clipboardIncluded"] as? Bool == false)
        #expect(privacy["hiddenClipboardItems"] as? Int == 1)
        #expect(counts["matched"] as? Int == 3)
        #expect(counts["visible"] as? Int == 2)
        #expect(counts["returned"] as? Int == 2)
        #expect(byType["prompt"] == 1)
        #expect(byType["skill"] == 1)
        #expect(byType["clipboard"] == 0)
        #expect(items.map { $0["title"] as? String }.contains("Review prompt"))
        #expect(!body.contains("private clipboard body"))
    }

    @Test func libraryExportRouteCanIncludeClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Clipboard", title: "Clip", content: "copy this", tags: ["clipboard", "text"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/library/export?includeClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])

        #expect(response.statusCode == 200)
        #expect(privacy["clipboardIncluded"] as? Bool == true)
        #expect(items.first?["type"] as? String == "clipboard")
        #expect(items.first?["content"] as? String == "copy this")
    }

    @Test func libraryExportRouteRejectsInvalidQueryValues() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let invalidType = router.route(HTTPRequest(method: "GET", path: "/library/export?type=bad", body: Data()))
        let invalidClipboard = router.route(HTTPRequest(method: "GET", path: "/library/export?includeClipboard=maybe", body: Data()))

        #expect(invalidType.statusCode == 400)
        #expect(invalidClipboard.statusCode == 400)
    }

    @Test func libraryPatchUpdatesPinnedState() throws {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Body")
        let store = InMemoryResourceStore(items: [item])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"pinned":true}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/library/\(item.id.uuidString)", body: body))
        let stored = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(response.statusCode == 200)
        #expect(stored.first?.pinned == true)
    }

    @Test func libraryPatchUpdatesEditableFields() throws {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Body")
        let store = InMemoryResourceStore(items: [item])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {"type":"mcp","group":"Servers","title":"Local MCP","content":"npx server","tags":["mcp","local"],"source":"Codex","pinned":true}
        """.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/library/\(item.id.uuidString)", body: body))
        let stored = try store.list(type: .mcp, query: nil, limit: nil)

        #expect(response.statusCode == 200)
        #expect(stored.first?.group == "Servers")
        #expect(stored.first?.title == "Local MCP")
        #expect(stored.first?.tags == ["mcp", "local"])
        #expect(stored.first?.pinned == true)
    }

    @Test func libraryPatchRejectsOversizedContent() throws {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Body")
        let store = InMemoryResourceStore(items: [item])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let oversized = String(repeating: "B", count: ResourceLimits.maxResourceContentCharacters + 1)
        let body = Data("""
        {"content":"\(oversized)"}
        """.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/library/\(item.id.uuidString)", body: body))
        let stored = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(response.statusCode == 413)
        #expect(stored.first?.content == "Body")
    }

    @Test func libraryPatchRejectsEmptyBody() throws {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Body")
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore(items: [item]))
        let body = Data(#"{}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/library/\(item.id.uuidString)", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func libraryPatchRejectsBlankTitle() throws {
        let item = ResourceItem(type: .prompt, title: "Prompt", content: "Body")
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore(items: [item]))
        let body = Data(#"{"title":"   "}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/library/\(item.id.uuidString)", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func libraryDeleteRemovesResource() throws {
        let item = ResourceItem(type: .skill, title: "Skill", content: "Repo")
        let store = InMemoryResourceStore(items: [item])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "DELETE", path: "/library/\(item.id.uuidString)", body: Data()))
        let stored = try store.list(type: .skill, query: nil, limit: nil)

        #expect(response.statusCode == 200)
        #expect(stored.isEmpty)
    }

    @Test func libraryDeleteRejectsMissingResource() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "DELETE", path: "/library/\(UUID().uuidString)", body: Data()))

        #expect(response.statusCode == 404)
    }

    @Test func knowledgeIndexRouteIndexesPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-route-knowledge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "Knowledge note".write(to: root.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
        let encodedPath = try #require(root.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
        let router = NotificationRouter(handleDing: { _ in })

        let response = router.route(HTTPRequest(method: "GET", path: "/knowledge/index?path=\(encodedPath)&limit=5", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(body.contains(#""relativePath":"note.md""#))
        #expect(body.contains("Knowledge note"))
    }

    @Test func knowledgeIndexRouteUsesKnowledgeResourceContentAsPath() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-route-knowledge-id-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "Indexed through resource".write(to: root.appendingPathComponent("agent.txt"), atomically: true, encoding: .utf8)
        let item = ResourceItem(type: .knowledge, title: "Docs", content: root.path)
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore(items: [item]))

        let response = router.route(HTTPRequest(method: "GET", path: "/knowledge/index?id=\(item.id.uuidString)", body: Data()))
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(body.contains(#""relativePath":"agent.txt""#))
    }

    @Test func knowledgeIndexRouteRejectsMissingInput() throws {
        let router = NotificationRouter(handleDing: { _ in })

        let response = router.route(HTTPRequest(method: "GET", path: "/knowledge/index", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func clipboardCaptureAddsClipboardResource() throws {
        let store = InMemoryResourceStore()
        let recorder = ClipboardRecorder(reader: StubHTTPClipboardReader(value: "Useful copied prompt"))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, clipboardRecorder: recorder)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/capture", body: Data()))
        let stored = try store.list(type: .clipboard)

        #expect(response.statusCode == 201)
        #expect(stored.first?.title == "Useful copied prompt")
    }

    @Test func clipboardCaptureDoesNotStoreDuplicateContent() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, title: "Existing", content: "Repeated clipboard")
        ])
        let recorder = ClipboardRecorder(reader: StubHTTPClipboardReader(value: "Repeated clipboard"))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, clipboardRecorder: recorder)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/capture", body: Data()))
        let stored = try store.list(type: .clipboard, query: nil, limit: nil)

        #expect(response.statusCode == 200)
        #expect(stored.count == 1)
    }

    @Test func clipboardCaptureRejectsOversizedContent() throws {
        let store = InMemoryResourceStore()
        let oversized = String(repeating: "C", count: ResourceLimits.maxClipboardContentCharacters + 1)
        let recorder = ClipboardRecorder(reader: StubHTTPClipboardReader(value: oversized))
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, clipboardRecorder: recorder)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/capture", body: Data()))
        let stored = try store.list(type: .clipboard, query: nil, limit: nil)

        #expect(response.statusCode == 413)
        #expect(stored.isEmpty)
    }

    @Test func clipboardOverviewRouteReturnsCountsWithoutContent() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "URLs", title: "URL", content: "https://secret.example.com", tags: ["clipboard", "url", "domain:secret.example.com"], pinned: true),
            ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -H token=secret", tags: ["clipboard", "command", "curl"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Sensitive: API key or token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "secret", "api-key"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/overview", body: Data()))
        let object = try jsonObject(response.body)
        let overview = try #require(object["overview"] as? [String: Any])
        let counts = try #require(overview["classificationCounts"] as? [String: Int])
        let privacy = try #require(overview["privacy"] as? [String: Any])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(overview["total"] as? Int == 3)
        #expect(overview["pinned"] as? Int == 1)
        #expect(counts["url"] == 1)
        #expect(counts["command"] == 1)
        #expect(counts["sensitive"] == 1)
        #expect(privacy["contentIncluded"] as? Bool == false)
        #expect(!body.contains("sk-secret-value"))
        #expect(!body.contains("token=secret"))
    }

    @Test func clipboardInsightsRouteReturnsActionableMetadataWithoutContent() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Commands", title: "Deploy command", content: "deploy secret command", tags: ["clipboard", "command", "alias:deploy"], pinned: true),
            ResourceItem(type: .clipboard, group: "Code", title: "Code sample", content: "func run() {}", tags: ["clipboard", "code"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "secret"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/insights?limit=4", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Int])
        let recommendations = try #require(object["recommendations"] as? [[String: Any]])
        let snippets = try #require(object["snippetCandidates"] as? [[String: Any]])
        let promote = try #require(object["promoteCandidates"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(privacy["contentIncluded"] as? Bool == false)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == false)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 1)
        #expect(counts["total"] == 3)
        #expect(counts["visible"] == 2)
        #expect(counts["snippetCandidates"] == 1)
        #expect(counts["promoteCandidates"] == 1)
        #expect(recommendations.contains { ($0["id"] as? String) == "alias-frequent-commands" })
        #expect(recommendations.contains { ($0["id"] as? String) == "review-sensitive" })
        #expect(snippets.first?["aliases"] as? [String] == ["deploy"])
        #expect(promote.first?["title"] as? String == "Code sample")
        #expect(!body.contains("deploy secret command"))
        #expect(!body.contains("func run() {}"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardInsightsRouteCanIncludeSensitiveMetadataExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "alias:token"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/insights?includeSensitiveClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let snippets = try #require(object["snippetCandidates"] as? [[String: Any]])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == true)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 0)
        #expect(snippets.first?["title"] as? String == "Token")
        #expect(snippets.first?["contentCharacterCount"] as? Int == "sk-secret-value".count)
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardInsightsRouteRejectsInvalidSensitiveFlag() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/insights?includeSensitiveClipboard=maybe", body: Data()))

        #expect(response.statusCode == 400)
    }

    @Test func clipboardDigestRouteReturnsTaskScopedMetadataWithoutContentByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Review", title: "Review command", content: "swift test --filter Secret", tags: ["clipboard", "command", "review", "alias:test"], pinned: true),
            ResourceItem(type: .clipboard, group: "Review", title: "Review code", content: "func secretReview() {}", tags: ["clipboard", "code", "review"]),
            ResourceItem(type: .clipboard, group: "Research", title: "Research URL", content: "https://example.com/review", tags: ["clipboard", "url", "review"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest?task=review&limit=3", body: Data()))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Any])
        let byGroup = try #require(object["byGroup"] as? [[String: Any]])
        let candidates = try #require(object["candidates"] as? [[String: Any]])
        let actions = try #require(object["agentActions"] as? [String])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(object["task"] as? String == "review")
        #expect(privacy["contentIncluded"] as? Bool == false)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == false)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 1)
        #expect(counts["matched"] as? Int == 4)
        #expect(counts["visible"] as? Int == 3)
        #expect(counts["returned"] as? Int == 3)
        #expect(byGroup.first?["group"] as? String == "Review")
        #expect(candidates.first?["title"] as? String == "Review command")
        #expect(candidates.first?["content"] == nil)
        #expect(candidates.first?["aliases"] as? [String] == ["test"])
        #expect(actions.contains { $0.contains("/clipboard/promote/") })
        #expect(actions.contains { $0.contains("/clipboard/snippet/test/restore") })
        #expect(!body.contains("swift test --filter Secret"))
        #expect(!body.contains("func secretReview"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardDigestRouteCanIncludeNonSensitiveContentExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Review", title: "Review command", content: "swift test", tags: ["clipboard", "command", "review"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest?task=review&includeContent=true&limit=5", body: Data()))
        let object = try jsonObject(response.body)
        let candidates = try #require(object["candidates"] as? [[String: Any]])
        let privacy = try #require(object["privacy"] as? [String: Any])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(privacy["contentIncluded"] as? Bool == true)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == false)
        #expect(candidates.first?["content"] as? String == "swift test")
        #expect(body.contains("swift test"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardDigestRouteCanIncludeSensitiveClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest?task=review&includeContent=true&includeSensitiveClipboard=true", body: Data()))
        let object = try jsonObject(response.body)
        let candidates = try #require(object["candidates"] as? [[String: Any]])
        let privacy = try #require(object["privacy"] as? [String: Any])

        #expect(response.statusCode == 200)
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == true)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 0)
        #expect(candidates.first?["content"] as? String == "sk-secret-value")
    }

    @Test func clipboardDigestRouteRejectsMissingOrInvalidInputs() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTask = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest", body: Data()))
        let invalidContent = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest?task=review&includeContent=maybe", body: Data()))
        let invalidSensitive = router.route(HTTPRequest(method: "GET", path: "/clipboard/digest?task=review&includeSensitiveClipboard=maybe", body: Data()))

        #expect(missingTask.statusCode == 400)
        #expect(invalidContent.statusCode == 400)
        #expect(invalidSensitive.statusCode == 400)
    }

    @Test func clipboardCollectRouteCreatesKnowledgeCollectionWithoutSensitiveByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Review", title: "Review command", content: "swift test --filter Review", tags: ["clipboard", "command", "review"], pinned: true),
            ResourceItem(type: .clipboard, group: "Review", title: "Review code", content: "func reviewPatch() {}", tags: ["clipboard", "code", "review"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Review clipboard collection",
          "task":"review",
          "limit":10,
          "source":"Codex",
          "tags":["review"]
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/collect", body: body))
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])
        let included = try #require(object["included"] as? [[String: Any]])
        let stored = try store.list(type: .knowledge, query: "Review clipboard collection", limit: nil)
        let collection = try #require(stored.first)
        let responseText = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 201)
        #expect(collection.group == ClipboardCollection.group)
        #expect(collection.source == "Codex")
        #expect(collection.pinned == true)
        #expect(collection.tags.contains("clipboard-collection"))
        #expect(collection.tags.contains("task:review"))
        #expect(collection.content.contains("swift test --filter Review"))
        #expect(collection.content.contains("func reviewPatch"))
        #expect(collection.content.contains("Hidden sensitive clipboard: 1"))
        #expect(!collection.content.contains("sk-secret-value"))
        #expect(!responseText.contains("sk-secret-value"))
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == false)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 1)
        #expect(included.count == 2)
    }

    @Test func clipboardCollectRouteCanIncludeSensitiveClipboardExplicitly() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Review token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "review"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data("""
        {
          "title":"Sensitive clipboard collection",
          "task":"review",
          "includeSensitiveClipboard":true
        }
        """.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/collect", body: body))
        let stored = try store.list(type: .knowledge, query: "Sensitive clipboard collection", limit: nil)
        let collection = try #require(stored.first)
        let object = try jsonObject(response.body)
        let privacy = try #require(object["privacy"] as? [String: Any])

        #expect(response.statusCode == 201)
        #expect(collection.content.contains("sk-secret-value"))
        #expect(collection.content.contains("Sensitive clipboard included: true"))
        #expect(privacy["sensitiveClipboardIncluded"] as? Bool == true)
        #expect(privacy["hiddenSensitiveItems"] as? Int == 0)
    }

    @Test func clipboardCollectRouteRejectsMissingRequiredSelection() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let missingTitle = router.route(HTTPRequest(method: "POST", path: "/clipboard/collect", body: Data(#"{"task":"review"}"#.utf8)))
        let missingSelection = router.route(HTTPRequest(method: "POST", path: "/clipboard/collect", body: Data(#"{"title":"No selection"}"#.utf8)))

        #expect(missingTitle.statusCode == 400)
        #expect(missingSelection.statusCode == 400)
    }

    @Test func clipboardHistoryRouteReturnsMetadataWithoutContentByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "URLs", title: "URL", content: "https://example.com/docs", tags: ["clipboard", "url", "domain:example.com"], pinned: true),
            ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -H token=secret", tags: ["clipboard", "command", "curl"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "secret", "api-key"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/history?filter=command&q=curl&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let filter = try #require(object["filter"] as? [String: Any])
        let counts = try #require(object["counts"] as? [String: Int])
        let privacy = try #require(object["privacy"] as? [String: Any])
        let items = try #require(object["items"] as? [[String: Any]])
        let first = try #require(items.first)
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(filter["filter"] as? String == "command")
        #expect(filter["includeContent"] as? Bool == false)
        #expect(counts["matched"] == 1)
        #expect(counts["visible"] == 1)
        #expect(counts["returned"] == 1)
        #expect(privacy["contentIncluded"] as? Bool == false)
        #expect(first["title"] as? String == "Command")
        #expect(first["classification"] as? String == "command")
        #expect(first["contentCharacterCount"] as? Int == "curl -H token=secret".count)
        #expect(first["content"] == nil)
        #expect(!body.contains("curl -H token=secret"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardHistoryRouteHidesSensitiveRecordsUnlessExplicit() throws {
        let normal = ResourceItem(type: .clipboard, group: "Commands", title: "Command", content: "curl -sS http://127.0.0.1:8765/health", tags: ["clipboard", "command", "curl"])
        let sensitive = ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "secret", "api-key"])
        let store = InMemoryResourceStore(items: [normal, sensitive])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let defaultResponse = router.route(HTTPRequest(method: "GET", path: "/clipboard/history?includeContent=true&limit=10", body: Data()))
        let defaultObject = try jsonObject(defaultResponse.body)
        let defaultCounts = try #require(defaultObject["counts"] as? [String: Int])
        let defaultItems = try #require(defaultObject["items"] as? [[String: Any]])
        let defaultBody = try #require(String(data: defaultResponse.body, encoding: .utf8))

        let explicitResponse = router.route(HTTPRequest(method: "GET", path: "/clipboard/history?includeContent=true&includeSensitiveClipboard=true&limit=10", body: Data()))
        let explicitBody = try #require(String(data: explicitResponse.body, encoding: .utf8))

        #expect(defaultResponse.statusCode == 200)
        #expect(defaultCounts["matched"] == 2)
        #expect(defaultCounts["visible"] == 1)
        #expect(defaultCounts["hiddenSensitive"] == 1)
        #expect(defaultItems.count == 1)
        #expect(defaultItems.first?["content"] as? String == normal.content)
        #expect(!defaultBody.contains("sk-secret-value"))
        #expect(explicitResponse.statusCode == 200)
        #expect(explicitBody.contains("sk-secret-value"))
    }

    @Test func clipboardHistoryRouteRejectsInvalidQueryValues() throws {
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: InMemoryResourceStore())

        let invalidBool = router.route(HTTPRequest(method: "GET", path: "/clipboard/history?includeContent=maybe", body: Data()))
        let invalidFilter = router.route(HTTPRequest(method: "GET", path: "/clipboard/history?filter=unknown", body: Data()))

        #expect(invalidBool.statusCode == 400)
        #expect(invalidFilter.statusCode == 400)
    }

    @Test func clipboardSnippetsRouteListsAliasMetadataWithoutContentByDefault() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Commands", title: "Deploy", content: "deploy secret command", tags: ["clipboard", "command", "alias:deploy"], pinned: true),
            ResourceItem(type: .clipboard, group: "Notes", title: "Draft", content: "draft body", tags: ["clipboard", "text"]),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "alias:deploy"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/snippets?alias=deploy&limit=10", body: Data()))
        let object = try jsonObject(response.body)
        let aliases = try #require(object["aliases"] as? [[String: Any]])
        let counts = try #require(object["counts"] as? [String: Int])
        let items = try #require(object["items"] as? [[String: Any]])
        let first = try #require(items.first)
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(counts["matched"] == 2)
        #expect(counts["visible"] == 1)
        #expect(counts["hiddenSensitive"] == 1)
        #expect(aliases.first?["alias"] as? String == "deploy")
        #expect(first["title"] as? String == "Deploy")
        #expect(first["aliases"] as? [String] == ["deploy"])
        #expect(first["content"] == nil)
        #expect(!body.contains("deploy secret command"))
        #expect(!body.contains("sk-secret-value"))
    }

    @Test func clipboardSnippetRestoreUsesPinnedAliasRecord() throws {
        let older = Date().addingTimeInterval(-10)
        let newer = Date()
        let pinned = ResourceItem(type: .clipboard, title: "Pinned", content: "Pinned snippet", tags: ["clipboard", "alias:deploy"], pinned: true, updatedAt: older)
        let recent = ResourceItem(type: .clipboard, title: "Recent", content: "Recent snippet", tags: ["clipboard", "alias:deploy"], updatedAt: newer)
        let store = InMemoryResourceStore(items: [recent, pinned])
        var restored: String?
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, writePasteboard: { restored = $0; return true })

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/snippet/deploy/restore", body: Data()))
        let object = try jsonObject(response.body)

        #expect(response.statusCode == 200)
        #expect(object["status"] as? String == "restored")
        #expect(object["alias"] as? String == "deploy")
        #expect(object["title"] as? String == "Pinned")
        #expect(restored == "Pinned snippet")
    }

    @Test func clipboardSnippetRestoreHidesSensitiveUnlessExplicit() throws {
        let sensitive = ResourceItem(type: .clipboard, title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive", "alias:token"])
        let store = InMemoryResourceStore(items: [sensitive])
        var restored: String?
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store, writePasteboard: { restored = $0; return true })

        let defaultResponse = router.route(HTTPRequest(method: "POST", path: "/clipboard/snippet/token/restore", body: Data()))
        let explicitResponse = router.route(HTTPRequest(method: "POST", path: "/clipboard/snippet/token/restore?includeSensitiveClipboard=true", body: Data()))

        #expect(defaultResponse.statusCode == 404)
        #expect(explicitResponse.statusCode == 200)
        #expect(restored == "sk-secret-value")
    }

    @Test func clipboardGroupsRouteReturnsGroupSummariesWithoutContent() throws {
        let store = InMemoryResourceStore(items: [
            ResourceItem(type: .clipboard, group: "Research", title: "Research URL", content: "https://example.com/research", tags: ["clipboard", "url"]),
            ResourceItem(type: .clipboard, group: "Research", title: "Research Command", content: "curl -sS", tags: ["clipboard", "command"], pinned: true),
            ResourceItem(type: .clipboard, group: "Sensitive", title: "Token", content: "sk-secret-value", tags: ["clipboard", "sensitive"])
        ])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "GET", path: "/clipboard/groups", body: Data()))
        let object = try jsonObject(response.body)
        let groups = try #require(object["groups"] as? [[String: Any]])
        let overview = try #require(object["overview"] as? [String: Any])
        let body = try #require(String(data: response.body, encoding: .utf8))

        #expect(response.statusCode == 200)
        #expect(groups.contains { ($0["group"] as? String) == "Research" && ($0["count"] as? Int) == 2 })
        #expect(overview["total"] as? Int == 3)
        #expect(!body.contains("sk-secret-value"))
        #expect(!body.contains("curl -sS"))
    }

    @Test func clipboardPatchRouteOrganizesClipboardRecordWithoutContent() throws {
        let clipboard = ResourceItem(type: .clipboard, group: "Clipboard", title: "Clip", content: "Keep original", tags: ["clipboard", "text"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"group":"Agent Research","tags":["clipboard","research"],"pinned":true}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/clipboard/\(clipboard.id.uuidString)", body: body))
        let object = try jsonObject(response.body)
        let item = try #require(object["item"] as? [String: Any])
        let stored = try #require(store.list(type: .clipboard, query: nil, limit: nil).first)

        #expect(response.statusCode == 200)
        #expect(item["group"] as? String == "Agent Research")
        #expect(item["content"] == nil)
        #expect(stored.group == "Agent Research")
        #expect(stored.tags == ["clipboard", "text", "research"])
        #expect(stored.pinned == true)
        #expect(stored.content == "Keep original")
    }

    @Test func clipboardPatchRouteRejectsContentTypeAndSourceChanges() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Clip", content: "Keep original")
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"content":"replace","type":"prompt","source":"Agent"}"#.utf8)

        let response = router.route(HTTPRequest(method: "PATCH", path: "/clipboard/\(clipboard.id.uuidString)", body: body))
        let stored = try #require(store.list(type: .clipboard, query: nil, limit: nil).first)

        #expect(response.statusCode == 400)
        #expect(stored.content == "Keep original")
        #expect(stored.type == .clipboard)
    }

    @Test func clipboardPromoteRouteCreatesSharedResource() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Review prompt", content: "Review this diff", tags: ["clipboard", "text"])
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"targetType":"prompt","pinned":true}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/promote/\(clipboard.id.uuidString)", body: body))
        let prompts = try store.list(type: .prompt, query: nil, limit: nil)

        #expect(response.statusCode == 201)
        #expect(prompts.count == 1)
        #expect(prompts.first?.title == "Review prompt")
        #expect(prompts.first?.content == "Review this diff")
        #expect(prompts.first?.tags.contains("from-clipboard") == true)
        #expect(prompts.first?.pinned == true)
    }

    @Test func clipboardPromoteRouteRejectsClipboardTarget() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Clip", content: "Body")
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)
        let body = Data(#"{"targetType":"clipboard"}"#.utf8)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/promote/\(clipboard.id.uuidString)", body: body))

        #expect(response.statusCode == 400)
    }

    @Test func clipboardRestoreRouteWritesClipboardContent() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Clip", content: "Restore this text")
        let store = InMemoryResourceStore(items: [clipboard])
        var restoredContent: String?
        let router = NotificationRouter(
            handleDing: { _ in },
            resourceStore: store,
            writePasteboard: { content in
                restoredContent = content
                return true
            }
        )

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/restore/\(clipboard.id.uuidString)", body: Data()))
        let object = try jsonObject(response.body)

        #expect(response.statusCode == 200)
        #expect(object["status"] as? String == "restored")
        #expect(object["title"] as? String == "Clip")
        #expect(restoredContent == "Restore this text")
    }

    @Test func clipboardRestoreRouteRejectsMissingClipboardRecord() throws {
        let prompt = ResourceItem(type: .prompt, title: "Prompt", content: "Not clipboard")
        let store = InMemoryResourceStore(items: [prompt])
        let router = NotificationRouter(handleDing: { _ in }, resourceStore: store)

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/restore/\(prompt.id.uuidString)", body: Data()))

        #expect(response.statusCode == 404)
    }

    @Test func clipboardRestoreRouteReportsPasteboardWriteFailure() throws {
        let clipboard = ResourceItem(type: .clipboard, title: "Clip", content: "Body")
        let store = InMemoryResourceStore(items: [clipboard])
        let router = NotificationRouter(
            handleDing: { _ in },
            resourceStore: store,
            writePasteboard: { _ in false }
        )

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/restore/\(clipboard.id.uuidString)", body: Data()))

        #expect(response.statusCode == 500)
    }

    @Test func showUIRouteTriggersHandler() throws {
        var didShow = false
        var receivedTab: CompanionTab?
        let router = NotificationRouter(handleDing: { _ in }, handleShowPanel: { tab in
            didShow = true
            receivedTab = tab
        })

        let response = router.route(HTTPRequest(method: "POST", path: "/ui/show", body: Data()))
        let object = try jsonObject(response.body)

        #expect(response.statusCode == 200)
        #expect(didShow == true)
        #expect(receivedTab == nil)
        #expect(object["tab"] as? String == "current")
    }

    @Test func showUIRouteCanOpenSpecificTab() throws {
        var receivedTab: CompanionTab?
        let router = NotificationRouter(handleDing: { _ in }, handleShowPanel: { receivedTab = $0 })

        let response = router.route(HTTPRequest(method: "POST", path: "/ui/show?tab=clipboard", body: Data()))
        let object = try jsonObject(response.body)

        #expect(response.statusCode == 200)
        #expect(receivedTab == .clipboard)
        #expect(object["tab"] as? String == "clipboard")
    }

    @Test func showUIRouteRejectsInvalidTab() throws {
        var didShow = false
        let router = NotificationRouter(handleDing: { _ in }, handleShowPanel: { _ in didShow = true })

        let response = router.route(HTTPRequest(method: "POST", path: "/ui/show?tab=settings", body: Data()))

        #expect(response.statusCode == 400)
        #expect(didShow == false)
    }

    @Test func clipboardMonitorRouteTogglesHandler() throws {
        var received: Bool?
        let router = NotificationRouter(handleDing: { _ in }, handleClipboardMonitoring: { received = $0 })

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/monitor?enabled=true", body: Data()))

        #expect(response.statusCode == 200)
        #expect(received == true)
    }

    @Test func clipboardMonitorRouteRejectsMissingState() throws {
        let router = NotificationRouter(handleDing: { _ in })

        let response = router.route(HTTPRequest(method: "POST", path: "/clipboard/monitor", body: Data()))

        #expect(response.statusCode == 400)
    }
}

private func jsonObject(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private struct StubHTTPClipboardReader: ClipboardReading {
    var value: String?
    var changeCount = 1

    func stringValue() -> String? {
        value
    }

    func fileURLs() -> [URL] {
        []
    }

    func imageData() -> ClipboardImageData? {
        nil
    }
}
