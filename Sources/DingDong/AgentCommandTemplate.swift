import Foundation

struct AgentCommandTemplate: Equatable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var command: String

    static let defaults: [AgentCommandTemplate] = [
        AgentCommandTemplate(
            id: "ding-complete",
            title: "Task Complete",
            summary: "Notify DingDong when an agent finishes a task.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/ding \\
              -H 'Content-Type: application/json' \\
              -d '{"message":"Agent task complete","source":"Agent","sound":"random","flashCount":10}'
            """
        ),
        AgentCommandTemplate(
            id: "show-panel",
            title: "Show Panel",
            summary: "Open the DingDong companion panel from an agent.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/ui/show?tab=today'"
        ),
        AgentCommandTemplate(
            id: "show-clipboard",
            title: "Show Clipboard",
            summary: "Open DingDong directly to the clipboard list.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/ui/show?tab=clipboard'"
        ),
        AgentCommandTemplate(
            id: "system-status",
            title: "System Status",
            summary: "Check resource counts, clipboard monitoring, limits, and low-overhead status before heavier agent calls.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/system/status'"
        ),
        AgentCommandTemplate(
            id: "search-library",
            title: "Search Library",
            summary: "Find shared prompts, skills, MCP servers, or knowledge entries.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library?type=prompt&q=review&limit=10'"
        ),
        AgentCommandTemplate(
            id: "list-groups",
            title: "List Groups",
            summary: "Inspect shared resource groups and counts before searching.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library/groups?type=prompt'"
        ),
        AgentCommandTemplate(
            id: "export-library",
            title: "Export Library",
            summary: "Export a bounded prompts, skills, MCP, and knowledge snapshot without clipboard content by default.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library/export?limit=200'"
        ),
        AgentCommandTemplate(
            id: "agent-brief",
            title: "Agent Brief",
            summary: "Get a fast startup summary of resources, groups, pinned items, and recent agent activity.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/brief'"
        ),
        AgentCommandTemplate(
            id: "agent-manifest",
            title: "Agent Manifest",
            summary: "Fetch the machine-readable discovery manifest for local AI agents.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/manifest'"
        ),
        AgentCommandTemplate(
            id: "agent-toolkit",
            title: "Agent Toolkit",
            summary: "Fetch copyable onboarding instructions and commands for a local AI agent.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/toolkit'"
        ),
        AgentCommandTemplate(
            id: "agent-startup",
            title: "Agent Startup Pack",
            summary: "Fetch a one-call brief plus task-scoped context for a local AI agent.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/startup?task=code%20review&limit=12'"
        ),
        AgentCommandTemplate(
            id: "agent-bridge",
            title: "Agent Bridge Config",
            summary: "Fetch DingDong-managed prompts, skills, and MCP references for the minimal bridge adapter.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/bridge?source=Codex&task=code%20review&limit=20'"
        ),
        AgentCommandTemplate(
            id: "agent-prepare",
            title: "Agent Prepare Pack",
            summary: "Fetch status, startup context, resource recommendations, and clipboard insights before starting work.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/prepare?task=code%20review&limit=8'"
        ),
        AgentCommandTemplate(
            id: "agent-workbench",
            title: "Agent Workbench",
            summary: "Read active sessions, open handoffs, related memories, active agents, and next commands before starting or resuming work.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/workbench?task=code%20review&limit=8'"
        ),
        AgentCommandTemplate(
            id: "agent-instructions",
            title: "Agent Instructions",
            summary: "Fetch a copyable startup prompt for a local AI agent and task.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/instructions?task=code%20review&limit=6'"
        ),
        AgentCommandTemplate(
            id: "agent-presence",
            title: "Agent Presence",
            summary: "Register or refresh the local agent's current task so other agents can see who is active.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/presence \\
              -H 'Content-Type: application/json' \\
              -d '{"source":"Codex","status":"active","task":"Working on DingDong","capabilities":["code","tests"]}'
            """
        ),
        AgentCommandTemplate(
            id: "start-session",
            title: "Start Session",
            summary: "Create a shared task session so multiple local agents can coordinate progress.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/session \\
              -H 'Content-Type: application/json' \\
              -d '{"task":"Code review","summary":"Review the current code changes.","currentStep":"Inspect repository state","nextActions":["Run tests","Record findings"],"source":"Codex","status":"active","tags":["review"]}'
            """
        ),
        AgentCommandTemplate(
            id: "list-sessions",
            title: "List Sessions",
            summary: "Read active task sessions before starting or resuming local agent work.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/sessions?status=active&limit=10'"
        ),
        AgentCommandTemplate(
            id: "update-session",
            title: "Update Session",
            summary: "Append progress, current step, next actions, or resource ids to an active session.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/agent/session/SESSION_ID \\
              -H 'Content-Type: application/json' \\
              -d '{"status":"active","progress":"Implemented the route and added tests.","currentStep":"Run verification","nextActions":["Package app","Verify runtime API"],"source":"Codex"}'
            """
        ),
        AgentCommandTemplate(
            id: "save-memory",
            title: "Save Memory",
            summary: "Save a durable preference, rule, or lesson for future local agents.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/memory \\
              -H 'Content-Type: application/json' \\
              -d '{"title":"Code review preference","content":"Always run regression tests before reporting completion.","task":"code review","kind":"preference","source":"Codex","tags":["review","tests"],"pinned":true}'
            """
        ),
        AgentCommandTemplate(
            id: "list-memories",
            title: "List Memories",
            summary: "Read durable local memories before starting related agent work.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/memories?q=code%20review&limit=10'"
        ),
        AgentCommandTemplate(
            id: "recommend-resources",
            title: "Recommend Resources",
            summary: "Ask DingDong which prompts, skills, MCP references, or knowledge entries fit a task.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/recommend?q=code%20review&type=prompt&limit=5'"
        ),
        AgentCommandTemplate(
            id: "resolve-resource",
            title: "Resolve Resource",
            summary: "Resolve the best matching shared resource and return guarded detail in one call.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/resolve?q=code%20review&type=prompt'"
        ),
        AgentCommandTemplate(
            id: "agent-resource",
            title: "Agent Resource",
            summary: "Fetch one shared resource by id with clipboard content guarded by explicit flags.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/resource/RESOURCE_ID'"
        ),
        AgentCommandTemplate(
            id: "save-bundle",
            title: "Save Bundle",
            summary: "Save a reusable task bundle made from matching shared resources.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/bundle \\
              -H 'Content-Type: application/json' \\
              -d '{"title":"Code review bundle","task":"code review","limit":12,"source":"Codex","tags":["review","bundle"]}'
            """
        ),
        AgentCommandTemplate(
            id: "save-handoff",
            title: "Save Handoff",
            summary: "Leave a structured task note that future local agents can pick up.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/handoff \\
              -H 'Content-Type: application/json' \\
              -d '{"title":"Continue UI polish","summary":"Panel layout is implemented; visual QA is still needed.","nextSteps":["Open the panel","Check mobile-sized window layout"],"source":"Codex","status":"open","tags":["ui"]}'
            """
        ),
        AgentCommandTemplate(
            id: "list-handoffs",
            title: "List Handoffs",
            summary: "Read open agent handoff notes before continuing work.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/handoffs?status=open&limit=10'"
        ),
        AgentCommandTemplate(
            id: "update-handoff",
            title: "Update Handoff",
            summary: "Mark a handoff as open, done, or blocked and append progress for the next local agent.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/agent/handoff/HANDOFF_ID \\
              -H 'Content-Type: application/json' \\
              -d '{"status":"done","progress":"Implemented and verified the requested change.","source":"Codex"}'
            """
        ),
        AgentCommandTemplate(
            id: "agent-context",
            title: "Agent Context",
            summary: "Fetch a bounded local context pack before choosing prompts, skills, MCP, or knowledge.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/context?q=review&limit=20'"
        ),
        AgentCommandTemplate(
            id: "scan-knowledge",
            title: "Scan Knowledge",
            summary: "Get lightweight file summaries for a local knowledge directory.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/knowledge/index?path=/ABSOLUTE/PATH&limit=20'"
        ),
        AgentCommandTemplate(
            id: "clipboard-monitor-on",
            title: "Clipboard Watch On",
            summary: "Enable low-frequency clipboard capture.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/clipboard/monitor?enabled=true'"
        ),
        AgentCommandTemplate(
            id: "clipboard-overview",
            title: "Clipboard Overview",
            summary: "Inspect clipboard groups, tags, and classification counts without reading clipboard content.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/overview'"
        ),
        AgentCommandTemplate(
            id: "clipboard-insights",
            title: "Clipboard Insights",
            summary: "Get clipboard candidates and recommended agent actions without reading clipboard content.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/insights?limit=8'"
        ),
        AgentCommandTemplate(
            id: "clipboard-digest",
            title: "Clipboard Digest",
            summary: "Get task-scoped clipboard groups, candidates, and agent actions with content hidden by default.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/digest?task=code%20review&limit=8'"
        ),
        AgentCommandTemplate(
            id: "clipboard-collect",
            title: "Collect Clipboard",
            summary: "Save task-scoped clipboard records as reusable knowledge for future agents.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/collect \\
              -H 'Content-Type: application/json' \\
              -d '{"title":"Code review clipboard collection","task":"code review","limit":10,"source":"Codex","tags":["review","clipboard"]}'
            """
        ),
        AgentCommandTemplate(
            id: "clipboard-history",
            title: "Clipboard History",
            summary: "Search clipboard metadata by smart type without reading content unless explicitly requested.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/history?filter=command&q=curl&limit=10'"
        ),
        AgentCommandTemplate(
            id: "clipboard-groups",
            title: "Clipboard Groups",
            summary: "Inspect clipboard groups and classification counts before organizing clipboard records.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/groups'"
        ),
        AgentCommandTemplate(
            id: "clipboard-snippets",
            title: "Clipboard Snippets",
            summary: "List reusable clipboard records tagged with alias:name.",
            command: "curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/snippets?alias=deploy&limit=10'"
        ),
        AgentCommandTemplate(
            id: "organize-clipboard",
            title: "Organize Clipboard",
            summary: "Move a clipboard record into a group, update tags, or pin it without changing clipboard content.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/clipboard/CLIPBOARD_ID \\
              -H 'Content-Type: application/json' \\
              -d '{"group":"Agent Research","tags":["clipboard","research"],"pinned":true}'
            """
        ),
        AgentCommandTemplate(
            id: "promote-clipboard",
            title: "Promote Clipboard",
            summary: "Turn a clipboard record into a shared prompt, skill, MCP, or knowledge resource.",
            command: """
            curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/promote/CLIPBOARD_ID \\
              -H 'Content-Type: application/json' \\
              -d '{"targetType":"prompt","pinned":true}'
            """
        ),
        AgentCommandTemplate(
            id: "restore-clipboard",
            title: "Restore Clipboard",
            summary: "Put a saved clipboard record back onto the system clipboard.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/restore/CLIPBOARD_ID"
        ),
        AgentCommandTemplate(
            id: "restore-snippet",
            title: "Restore Snippet",
            summary: "Restore a reusable clipboard snippet by alias.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/snippet/deploy/restore"
        ),
        AgentCommandTemplate(
            id: "clipboard-monitor-off",
            title: "Clipboard Watch Off",
            summary: "Disable clipboard capture.",
            command: "curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/clipboard/monitor?enabled=false'"
        )
    ]
}
