import Foundation

struct AgentToolkit {
    static func object(resources: [ResourceItem], libraryAvailable: Bool) -> [String: Any] {
        [
            "service": "DingDong",
            "baseURL": "http://127.0.0.1:8765",
            "generatedAt": timestamp(Date()),
            "purpose": "Paste this toolkit into local AI agent startup prompts so every agent uses the same DingDong desktop capabilities.",
            "library": [
                "available": libraryAvailable,
                "resourceCount": resources.count,
                "byType": countsByType(resources),
                "pinnedCount": resources.filter(\.pinned).count,
                "sessionCount": resources.filter { $0.group == AgentSessionRequest.group }.count,
                "memoryCount": resources.filter { $0.group == AgentMemoryRequest.group }.count,
                "handoffCount": resources.filter { $0.group == AgentHandoffRequest.group }.count
            ],
            "privacy": [
                "network": "Loopback only at 127.0.0.1.",
                "clipboardDefault": "Clipboard records are excluded from agent brief, recommendations, and context unless includeClipboard=true.",
                "clipboardRule": "Use includeClipboard=true only when the user explicitly asks for clipboard history or the task clearly requires it.",
                "sensitiveClipboardDefault": "Clipboard records tagged sensitive are excluded even when includeClipboard=true unless includeSensitiveClipboard=true.",
                "knowledgeRule": "Knowledge indexing is on-demand and bounded; call /knowledge/index before reading saved local folders."
            ],
            "agentPrompt": promptSnippet,
            "startupFlow": [
                "Call GET /health to confirm DingDong is running.",
                "Call GET /system/status to inspect local limits, counts, and clipboard monitor state.",
                "Call GET /agent/instructions?task=TASK&limit=6 when you need a copyable startup prompt for another local AI agent.",
                "Call POST /agent/presence to announce the agent source, status, and current task.",
                "Call GET /agent/sessions?status=active&limit=10 before starting so you can avoid duplicating active agent work.",
                "Call POST /agent/session when starting a multi-step task, then PATCH /agent/session/{id} as progress changes.",
                "Call GET /agent/memories?q=TASK&limit=10 before work that may depend on prior preferences or lessons.",
                "Call GET /agent/brief for resource groups, pinned resources, and recent agent events.",
                "Call GET /agent/context?q=TASK&limit=20 before choosing prompts, skills, MCP references, or knowledge.",
                "Call GET /agent/recommend?q=TASK&type=prompt when a narrow recommendation is enough.",
                "Call POST /agent/bundle to save a reusable task bundle for future local agents.",
                "Call POST /agent/memory when you learn a durable preference, rule, or lesson that future agents should reuse.",
                "Call POST /agent/handoff before handing work to another local agent.",
                "Call POST /ding when work is complete, blocked, or needs user attention."
            ],
            "commonCommands": AgentCommandTemplate.defaults.map(commandObject),
            "copyablePrompt": copyablePrompt
        ]
    }

    private static let promptSnippet = """
    You have access to DingDong, a local macOS AI companion at http://127.0.0.1:8765.
    Use it to share prompts, skills, MCP references, local knowledge paths, clipboard records, and handoff notes with other local agents.
    For a task-specific startup prompt, fetch /agent/instructions?task=TASK&limit=6 and follow its copyablePrompt.
    Start by fetching /agent/brief, then use /agent/context or /agent/recommend for task-specific resources.
    Register your current work with /agent/presence so other local agents can see who is active.
    For multi-step work, create or update /agent/session so other agents can see progress, current step, resources, and next actions.
    Use /agent/memories to load durable preferences and /agent/memory to save lessons that future agents should remember.
    Clipboard history is private by default; do not include it unless the user explicitly wants clipboard-aware work.
    Sensitive clipboard records stay hidden unless the user explicitly asks for sensitive clipboard access.
    Save reusable findings through /library and save resumable state through /agent/handoff.
    Call /ding when your task is complete, blocked, or needs the user's attention.
    """

    private static let copyablePrompt = """
    Before starting, run:
    curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/system/status

    Then fetch task context:
    curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/brief

    To announce your current task, run:
    curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/presence -H 'Content-Type: application/json' -d '{"source":"Agent","status":"active","task":"Starting work"}'

    To fetch a task-specific copyable prompt for another local agent:
    curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/instructions?task=TASK&limit=6'

    To inspect active shared sessions:
    curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/sessions?status=active&limit=10'

    To create a shared session for multi-step work:
    curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/session -H 'Content-Type: application/json' -d '{"task":"TASK","summary":"Starting task context","source":"Agent","status":"active"}'

    To read durable agent memories:
    curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/memories?q=TASK&limit=10'

    When you need shared local resources, run:
    curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/context?q=TASK&limit=20'

    To save a durable lesson for future local agents, run:
    curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/memory -H 'Content-Type: application/json' -d '{"title":"TASK lesson","content":"What future agents should remember.","task":"TASK","kind":"lesson","source":"Agent"}'

    To save a reusable task bundle for other local agents, run:
    curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/bundle -H 'Content-Type: application/json' -d '{"title":"TASK bundle","task":"TASK","limit":12,"source":"Agent"}'

    When finished or blocked, notify the user:
    curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/ding -H 'Content-Type: application/json' -d '{"message":"Agent task complete","source":"Agent","sound":"random","flashCount":10}'
    """

    private static func commandObject(_ template: AgentCommandTemplate) -> [String: Any] {
        [
            "id": template.id,
            "title": template.title,
            "summary": template.summary,
            "command": template.command
        ]
    }

    private static func countsByType(_ resources: [ResourceItem]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for type in ResourceType.allCases {
            counts[type.rawValue] = resources.filter { $0.type == type }.count
        }
        return counts
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
