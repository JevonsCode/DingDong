import Testing
@testable import DingDong

struct AgentLaunchpadCommandTests {
    @Test func prepareCommandEncodesTaskAndLimit() {
        let command = AgentLaunchpadCommand.prepare(task: "code review & release", limit: 6)

        #expect(command == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/prepare?task=code%20review%20%26%20release&limit=6'")
    }

    @Test func prepareCommandUsesDefaultTaskForBlankInput() {
        let command = AgentLaunchpadCommand.prepare(task: "   ")

        #expect(command.contains("task=next%20agent%20task"))
        #expect(command.contains("limit=8"))
    }

    @Test func startupAndToolkitCommandsUseLoopbackAPI() {
        let startup = AgentLaunchpadCommand.startup(task: "code review & release", limit: 4)
        let workbench = AgentLaunchpadCommand.workbench(task: "code review & release", limit: 5)
        let toolkit = AgentLaunchpadCommand.toolkit()

        #expect(startup == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/startup?task=code%20review%20%26%20release&limit=4'")
        #expect(workbench == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/workbench?task=code%20review%20%26%20release&limit=5'")
        #expect(toolkit == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/toolkit'")
    }

    @Test func presenceCommandBuildsActiveAgentPayload() {
        let command = AgentLaunchpadCommand.presence(task: "review user's patch", source: "Claude")

        #expect(command.contains("POST http://127.0.0.1:8765/agent/presence"))
        #expect(command.contains(#""source":"Claude""#))
        #expect(command.contains(#""status":"active""#))
        #expect(command.contains(#""task":"review user"#))
        #expect(command.contains(#"'\''s patch""#))
        #expect(command.contains(#""capabilities":["code","tests","local-agent"]"#))
        #expect(command.contains(#"-d '{"#))
    }

    @Test func memoryCommandBuildsDurableMemoryPayload() {
        let command = AgentLaunchpadCommand.memory(task: "review user's patch", source: "Codex")

        #expect(command.contains("POST http://127.0.0.1:8765/agent/memory"))
        #expect(command.contains(#""title":"Memory for review user"#))
        #expect(command.contains(#"'\''s patch""#))
        #expect(command.contains(#""kind":"lesson""#))
        #expect(command.contains(#""source":"Codex""#))
        #expect(command.contains(#""tags":["agent-memory"]"#))
    }

    @Test func clipboardCommandsBuildMetadataOnlyAgentCalls() {
        let insights = AgentLaunchpadCommand.clipboardInsights(limit: 6)
        let digest = AgentLaunchpadCommand.clipboardDigest(task: "release notes & review", limit: 5)

        #expect(insights == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/insights?limit=6'")
        #expect(digest == "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/digest?task=release%20notes%20%26%20review&limit=5&includeContent=false'")
    }
}
