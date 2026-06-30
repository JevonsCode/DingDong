import Foundation

public protocol DingDongAPIRequesting {
    func request(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?
    ) throws -> Any
}

public final class DingDongMCPServer {
    private let client: DingDongAPIRequesting
    private let config: DingDongMCPConfig

    public init(
        client: DingDongAPIRequesting,
        config: DingDongMCPConfig = DingDongMCPConfig()
    ) {
        self.client = client
        self.config = config
    }

    public func handleLine(_ line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = message["method"] as? String else {
            return errorResponse(id: NSNull(), code: -32700, message: "Parse error")
        }

        let hasID = message.keys.contains("id")
        let id = message["id"] ?? NSNull()

        if !hasID {
            return nil
        }

        do {
            switch method {
            case "initialize":
                return successResponse(id: id, result: initializeResult(message))
            case "ping":
                return successResponse(id: id, result: [:])
            case "tools/list":
                return successResponse(id: id, result: ["tools": Self.tools])
            case "tools/call":
                return successResponse(id: id, result: try callTool(message))
            default:
                return errorResponse(id: id, code: -32601, message: "Method not found")
            }
        } catch let error as MCPToolError {
            return successResponse(id: id, result: toolResult(error.object, isError: true))
        } catch {
            return successResponse(id: id, result: toolResult([
                "status": "error",
                "message": String(describing: error)
            ], isError: true))
        }
    }

    private func initializeResult(_ message: [String: Any]) -> [String: Any] {
        let params = message["params"] as? [String: Any]
        let requestedProtocol = params?["protocolVersion"] as? String

        return [
            "protocolVersion": requestedProtocol ?? "2025-06-18",
            "capabilities": [
                "tools": [
                    "listChanged": false
                ]
            ],
            "serverInfo": [
                "name": "dingdong",
                "version": "0.1.0"
            ],
            "instructions": "Use DingDong tools as the single local bridge for user-managed prompts, skills, MCP references, resources, and notifications. Call dingdong_bridge first for non-trivial tasks, then load full resources only by id when needed."
        ]
    }

    private func callTool(_ message: [String: Any]) throws -> [String: Any] {
        guard let params = message["params"] as? [String: Any],
              let name = params["name"] as? String else {
            throw MCPToolError("tools/call requires params.name")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let object: Any

        switch name {
        case "dingdong_bridge":
            object = try bridge(arguments)
        case "dingdong_search_assets":
            object = try searchAssets(arguments)
        case "dingdong_get_asset":
            object = try getAsset(arguments)
        case "dingdong_load_skill":
            object = try loadSkill(arguments)
        case "dingdong_recommend_mcp":
            object = try recommendMCP(arguments)
        case "dingdong_install_native_mcp":
            object = try installNativeMCP(arguments)
        case "dingdong_notify":
            object = try notify(arguments)
        default:
            throw MCPToolError("Unknown DingDong tool: \(name)")
        }

        return toolResult(object)
    }

    private func bridge(_ arguments: [String: Any]) throws -> Any {
        var query = [
            "source": stringArgument(arguments, "source", defaultValue: "Agent"),
            "limit": String(intArgument(arguments, "limit", defaultValue: 20)),
            "expand": stringArgument(arguments, "expand", defaultValue: "prompts")
        ]

        if let task = optionalStringArgument(arguments, "task") {
            query["task"] = task
        }

        return try client.request(method: "GET", path: "/agent/bridge", query: query, body: nil)
    }

    private func searchAssets(_ arguments: [String: Any]) throws -> Any {
        var query = [
            "q": stringArgument(arguments, "query", defaultValue: ""),
            "limit": String(intArgument(arguments, "limit", defaultValue: 20))
        ]

        if let type = optionalStringArgument(arguments, "type"), type != "all" {
            query["type"] = type
        }

        return try client.request(method: "GET", path: "/agent/context", query: query, body: nil)
    }

    private func getAsset(_ arguments: [String: Any]) throws -> Any {
        guard let id = optionalStringArgument(arguments, "id") else {
            throw MCPToolError("dingdong_get_asset requires id")
        }

        var query: [String: String] = [:]
        if boolArgument(arguments, "includeClipboard", defaultValue: false) {
            query["includeClipboard"] = "true"
        }
        if boolArgument(arguments, "includeSensitiveClipboard", defaultValue: false) {
            query["includeSensitiveClipboard"] = "true"
        }

        let mode = stringArgument(arguments, "mode", defaultValue: "summary")
        let object = try client.request(method: "GET", path: "/agent/resource/\(id)", query: query, body: nil)
        guard mode == "summary" else {
            return object
        }

        return summarizeResourceDetail(object)
    }

    private func loadSkill(_ arguments: [String: Any]) throws -> Any {
        guard let id = optionalStringArgument(arguments, "id") else {
            throw MCPToolError("dingdong_load_skill requires id")
        }

        let object = try client.request(method: "GET", path: "/agent/resource/\(id)", query: [:], body: nil)
        guard let dictionary = object as? [String: Any],
              let item = dictionary["item"] as? [String: Any] else {
            throw MCPToolError("DingDong returned an invalid resource detail")
        }

        guard item["type"] as? String == "skill" else {
            throw MCPToolError("Resource \(id) is not a skill")
        }

        return object
    }

    private func recommendMCP(_ arguments: [String: Any]) throws -> Any {
        guard let task = optionalStringArgument(arguments, "task") else {
            throw MCPToolError("dingdong_recommend_mcp requires task")
        }

        return try client.request(
            method: "GET",
            path: "/agent/recommend",
            query: [
                "q": task,
                "type": "mcp",
                "limit": String(intArgument(arguments, "limit", defaultValue: 8))
            ],
            body: nil
        )
    }

    private func notify(_ arguments: [String: Any]) throws -> Any {
        guard let message = optionalStringArgument(arguments, "message") else {
            throw MCPToolError("dingdong_notify requires message")
        }

        return try client.request(
            method: "POST",
            path: "/ding",
            query: [:],
            body: [
                "message": message,
                "source": stringArgument(arguments, "source", defaultValue: "Agent"),
                "sound": stringArgument(arguments, "sound", defaultValue: "success"),
                "flashCount": intArgument(arguments, "flashCount", defaultValue: 8)
            ]
        )
    }

    private func installNativeMCP(_ arguments: [String: Any]) throws -> Any {
        guard let id = optionalStringArgument(arguments, "id") else {
            throw MCPToolError("dingdong_install_native_mcp requires id")
        }

        let target = stringArgument(arguments, "target", defaultValue: "codex")
        guard target == "codex" || target == "claude" else {
            throw MCPToolError("target must be codex or claude")
        }

        let detail = try client.request(method: "GET", path: "/agent/resource/\(id)", query: [:], body: nil)
        guard let dictionary = detail as? [String: Any],
              let item = dictionary["item"] as? [String: Any],
              item["type"] as? String == "mcp",
              let title = item["title"] as? String,
              let content = item["content"] as? String else {
            throw MCPToolError("Resource \(id) is not a full MCP resource")
        }

        let serverName = optionalStringArgument(arguments, "serverName") ?? slug(title)
        let commandSpec = try MCPCommandSpec.parse(from: content)
        let installer = NativeMCPInstaller(config: config)
        let dryRun = boolArgument(arguments, "dryRun", defaultValue: true)
        let confirm = optionalStringArgument(arguments, "confirm")
        let writeEnabled = !dryRun && confirm == "INSTALL"
        let result = try installer.install(
            serverName: serverName,
            commandSpec: commandSpec,
            target: target,
            write: writeEnabled
        )

        return [
            "status": writeEnabled ? "installed" : "dry_run",
            "target": target,
            "serverName": serverName,
            "configPath": result.configPath.path,
            "entry": result.entry,
            "writeRequired": "Pass dryRun=false and confirm=INSTALL to update the native agent config."
        ]
    }

    private func summarizeResourceDetail(_ object: Any) -> Any {
        guard var dictionary = object as? [String: Any],
              var item = dictionary["item"] as? [String: Any],
              let content = item["content"] as? String else {
            return object
        }

        item["contentExcerpt"] = excerpt(content, limit: 600)
        item["content"] = nil
        item["contentIncluded"] = false
        item["detailMode"] = "summary"
        dictionary["item"] = item
        return dictionary
    }

    private func toolResult(_ object: Any, isError: Bool = false) -> [String: Any] {
        [
            "content": [
                [
                    "type": "text",
                    "text": Self.prettyJSONString(object)
                ]
            ],
            "structuredContent": object,
            "isError": isError
        ]
    }

    private func successResponse(id: Any, result: [String: Any]) -> String {
        Self.jsonLine([
            "jsonrpc": "2.0",
            "id": id,
            "result": result
        ])
    }

    private func errorResponse(id: Any, code: Int, message: String) -> String {
        Self.jsonLine([
            "jsonrpc": "2.0",
            "id": id,
            "error": [
                "code": code,
                "message": message
            ]
        ])
    }

    private static func jsonLine(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(data: data, encoding: .utf8)!
    }

    private static func prettyJSONString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: object)
        }

        return string
    }

    private func optionalStringArgument(_ arguments: [String: Any], _ key: String) -> String? {
        (arguments[key] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func stringArgument(_ arguments: [String: Any], _ key: String, defaultValue: String) -> String {
        optionalStringArgument(arguments, key) ?? defaultValue
    }

    private func intArgument(_ arguments: [String: Any], _ key: String, defaultValue: Int) -> Int {
        if let value = arguments[key] as? Int {
            return value
        }

        if let value = arguments[key] as? Double {
            return Int(value)
        }

        if let value = arguments[key] as? String, let parsed = Int(value) {
            return parsed
        }

        return defaultValue
    }

    private func boolArgument(_ arguments: [String: Any], _ key: String, defaultValue: Bool) -> Bool {
        if let value = arguments[key] as? Bool {
            return value
        }

        if let value = arguments[key] as? String {
            return value == "true" || value == "1"
        }

        return defaultValue
    }

    private func excerpt(_ content: String, limit: Int) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }

        return "\(trimmed.prefix(limit))..."
    }

    private func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let parts = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).description : "-"
        }
        return parts
            .joined()
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .nilIfEmpty ?? "dingdong-mcp"
    }
}

private struct MCPToolError: Error {
    let message: String

    var object: [String: Any] {
        [
            "status": "error",
            "message": message
        ]
    }

    init(_ message: String) {
        self.message = message
    }
}

extension DingDongMCPServer {
    static var tools: [[String: Any]] {
        [
        [
            "name": "dingdong_bridge",
            "title": "DingDong Bridge",
            "description": "Fetch summary-first DingDong prompt, skill, and MCP routing for the current task. Short prompts may be inlined; skills and MCP references should be loaded by id only when needed.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "task": [
                        "type": "string",
                        "description": "Short task summary used to select pinned and matching DingDong resources."
                    ],
                    "source": [
                        "type": "string",
                        "description": "Agent name, such as Codex or Claude Code."
                    ],
                    "limit": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 60,
                        "description": "Maximum resources to return."
                    ],
                    "expand": [
                        "type": "string",
                        "enum": ["none", "prompts", "all"],
                        "description": "Default prompts. Use all only for debugging or manual export."
                    ]
                ]
            ]
        ],
        [
            "name": "dingdong_search_assets",
            "title": "Search DingDong Assets",
            "description": "Search DingDong resources and return bounded metadata plus excerpts. Clipboard content remains hidden by default.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string"],
                    "type": [
                        "type": "string",
                        "enum": ["all", "prompt", "skill", "mcp", "knowledge", "clipboard"]
                    ],
                    "limit": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 80
                    ]
                ],
                "required": ["query"]
            ]
        ],
        [
            "name": "dingdong_get_asset",
            "title": "Get DingDong Asset",
            "description": "Fetch one DingDong resource by id. Summary mode removes full content from the MCP response.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "mode": [
                        "type": "string",
                        "enum": ["summary", "full"]
                    ],
                    "includeClipboard": [
                        "type": "boolean",
                        "description": "Explicitly allow clipboard content when the resource is a clipboard record."
                    ],
                    "includeSensitiveClipboard": [
                        "type": "boolean",
                        "description": "Explicitly allow sensitive clipboard content."
                    ]
                ],
                "required": ["id"]
            ]
        ],
        [
            "name": "dingdong_load_skill",
            "title": "Load DingDong Skill",
            "description": "Fetch full content for one DingDong skill by id after the bridge or search result selected it.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"]
                ],
                "required": ["id"]
            ]
        ],
        [
            "name": "dingdong_recommend_mcp",
            "title": "Recommend MCP",
            "description": "Recommend DingDong MCP references for a task without installing them natively.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "task": ["type": "string"],
                    "limit": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 20
                    ]
                ],
                "required": ["task"]
            ]
        ],
        [
            "name": "dingdong_install_native_mcp",
            "title": "Install Native MCP",
            "description": "Install a DingDong MCP reference into Codex or Claude native MCP config. Defaults to dry run; pass dryRun=false and confirm=INSTALL to write config.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "id": ["type": "string"],
                    "target": [
                        "type": "string",
                        "enum": ["codex", "claude"]
                    ],
                    "serverName": ["type": "string"],
                    "dryRun": ["type": "boolean"],
                    "confirm": ["type": "string"]
                ],
                "required": ["id", "target"]
            ]
        ],
        [
            "name": "dingdong_notify",
            "title": "Notify DingDong",
            "description": "Notify DingDong when work is complete, blocked, or needs user attention.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "message": ["type": "string"],
                    "source": ["type": "string"],
                    "sound": [
                        "type": "string",
                        "description": "DingDong sound name, such as success, muted, sparkle, or random."
                    ],
                    "flashCount": [
                        "type": "integer",
                        "minimum": 0,
                        "maximum": 20
                    ]
                ],
                "required": ["message"]
            ]
        ]
        ]
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
