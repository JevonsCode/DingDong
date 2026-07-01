import Foundation
import Testing
@testable import DingDongMCPCore

struct DingDongMCPServerTests {
    @Test func initializeReturnsToolCapability() throws {
        let server = DingDongMCPServer(client: FakeDingDongAPIClient())
        let response = try object(from: server.handleLine(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#))
        let result = try #require(response["result"] as? [String: Any])
        let capabilities = try #require(result["capabilities"] as? [String: Any])
        let serverInfo = try #require(result["serverInfo"] as? [String: Any])

        #expect(result["protocolVersion"] as? String == "2025-06-18")
        #expect(capabilities["tools"] is [String: Any])
        #expect(serverInfo["name"] as? String == "dingdong")
        #expect((result["instructions"] as? String)?.contains("At the start of each user request, call dingdong_bridge") == true)
        #expect((result["instructions"] as? String)?.contains("call dingdong_notify once") == true)
    }

    @Test func initializedNotificationDoesNotRespond() {
        let server = DingDongMCPServer(client: FakeDingDongAPIClient())

        #expect(server.handleLine(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)
    }

    @Test func toolsListContainsDingDongTools() throws {
        let server = DingDongMCPServer(client: FakeDingDongAPIClient())
        let response = try object(from: server.handleLine(#"{"jsonrpc":"2.0","id":"tools","method":"tools/list"}"#))
        let result = try #require(response["result"] as? [String: Any])
        let tools = try #require(result["tools"] as? [[String: Any]])
        let names = tools.compactMap { $0["name"] as? String }

        #expect(names.contains("dingdong_bridge"))
        #expect(names.contains("dingdong_get_asset"))
        #expect(names.contains("dingdong_notify"))
        #expect(names.contains("dingdong_install_native_mcp"))
        let bridge = try #require(tools.first { ($0["name"] as? String) == "dingdong_bridge" })
        #expect((bridge["description"] as? String)?.contains("Call this first at the start of each user request") == true)
    }

    @Test func bridgeToolCallsAgentBridgeWithSummaryDefaults() throws {
        let client = FakeDingDongAPIClient()
        client.nextObject = ["status": "ok", "mode": "minimal-bridge-summary"]
        let server = DingDongMCPServer(client: client)

        let line = #"""
        {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"dingdong_bridge","arguments":{"task":"review UI","source":"Codex"}}}
        """#.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try object(from: server.handleLine(line))
        let result = try #require(response["result"] as? [String: Any])
        let structured = try #require(result["structuredContent"] as? [String: Any])

        #expect(client.requests.first?.method == "GET")
        #expect(client.requests.first?.path == "/agent/bridge")
        #expect(client.requests.first?.query["task"] == "review UI")
        #expect(client.requests.first?.query["source"] == "Codex")
        #expect(client.requests.first?.query["expand"] == "prompts")
        #expect(structured["status"] as? String == "ok")
    }

    @Test func getAssetSummaryStripsContent() throws {
        let client = FakeDingDongAPIClient()
        client.nextObject = [
            "status": "ok",
            "item": [
                "id": "resource-1",
                "type": "skill",
                "title": "Skill",
                "content": "Full skill body that should not be returned in summary mode."
            ]
        ]
        let server = DingDongMCPServer(client: client)
        let line = #"""
        {"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"dingdong_get_asset","arguments":{"id":"resource-1","mode":"summary"}}}
        """#.trimmingCharacters(in: .whitespacesAndNewlines)

        let response = try object(from: server.handleLine(line))
        let result = try #require(response["result"] as? [String: Any])
        let structured = try #require(result["structuredContent"] as? [String: Any])
        let item = try #require(structured["item"] as? [String: Any])

        #expect(client.requests.first?.path == "/agent/resource/resource-1")
        #expect(item["content"] == nil)
        #expect(item["contentIncluded"] as? Bool == false)
        #expect((item["contentExcerpt"] as? String)?.contains("Full skill body") == true)
    }

    @Test func loadSkillRejectsNonSkillResource() throws {
        let client = FakeDingDongAPIClient()
        client.nextObject = [
            "status": "ok",
            "item": [
                "id": "resource-1",
                "type": "mcp",
                "title": "Not a skill",
                "content": "body"
            ]
        ]
        let server = DingDongMCPServer(client: client)
        let line = #"""
        {"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"dingdong_load_skill","arguments":{"id":"resource-1"}}}
        """#.trimmingCharacters(in: .whitespacesAndNewlines)

        let response = try object(from: server.handleLine(line))
        let result = try #require(response["result"] as? [String: Any])

        #expect(result["isError"] as? Bool == true)
    }

    @Test func installNativeMCPDryRunDoesNotWriteConfig() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-mcp-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let client = FakeDingDongAPIClient()
        client.nextObject = [
            "status": "ok",
            "item": [
                "id": "resource-1",
                "type": "mcp",
                "title": "Codebase Memory MCP",
                "content": "Local command: /usr/local/bin/codebase-memory-mcp --stdio"
            ]
        ]
        let config = DingDongMCPConfig(
            codexConfigURL: root.appendingPathComponent("config.toml"),
            claudeMCPConfigURL: root.appendingPathComponent(".mcp.json")
        )
        let server = DingDongMCPServer(client: client, config: config)
        let line = #"""
        {"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"dingdong_install_native_mcp","arguments":{"id":"resource-1","target":"codex"}}}
        """#.trimmingCharacters(in: .whitespacesAndNewlines)

        let response = try object(from: server.handleLine(line))
        let result = try #require(response["result"] as? [String: Any])
        let structured = try #require(result["structuredContent"] as? [String: Any])
        let entry = try #require(structured["entry"] as? [String: Any])

        #expect(structured["status"] as? String == "dry_run")
        #expect(entry["command"] as? String == "/usr/local/bin/codebase-memory-mcp")
        #expect(entry["args"] as? [String] == ["--stdio"])
        #expect(!FileManager.default.fileExists(atPath: config.codexConfigURL.path))
    }

    private func object(from line: String?) throws -> [String: Any] {
        let line = try #require(line)
        let data = try #require(line.data(using: .utf8))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private final class FakeDingDongAPIClient: DingDongAPIRequesting {
    struct Request {
        var method: String
        var path: String
        var query: [String: String]
        var body: [String: Any]?
    }

    var requests: [Request] = []
    var nextObject: Any = ["status": "ok"]

    func request(
        method: String,
        path: String,
        query: [String: String],
        body: [String: Any]?
    ) throws -> Any {
        requests.append(Request(method: method, path: path, query: query, body: body))
        return nextObject
    }
}
