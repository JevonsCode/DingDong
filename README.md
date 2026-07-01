# DingDong

<p align="center">
  <img src="docs/assets/dingdong-icon.png" width="96" alt="DingDong icon">
</p>

DingDong is a native macOS menu bar utility for AI agent completion reminders. It exposes a loopback-only HTTP API. When an agent calls the API, the menu bar icon flashes and the app plays the built-in ding dong sound or a custom audio file selected by the user.

It is evolving into a lightweight AI companion: one local desktop service where multiple AI agents can share prompts, skills, MCP references, local knowledge references, and clipboard records.

Website: https://xn--8ovp9s.xn--m8txu.com/DingDong/

Latest release metadata: https://xn--8ovp9s.xn--m8txu.com/DingDong/dingdong-release.json

## Run

```bash
swift run DingDong
```

The app appears in the macOS menu bar. Click the bell icon to open the control panel.

The control panel supports English and Chinese display. Use the `EN` / `中` switch in the header to change language; the preference is saved locally.

When clipboard monitoring is enabled, press `Command + Shift + V` to open the DingDong clipboard list from the menu bar popover.

## Build App Bundles

Build the default architecture app bundle:

```bash
scripts/package_app.sh
```

Build both Apple Silicon and Intel release archives:

```bash
scripts/build_release_archives.sh 0.1.0
```

The release archives are written to `dist/release/`.

## MCP Setup

Install the single DingDong MCP bridge into Codex or Claude Code:

```json
{
  "mcpServers": {
    "dingdong": {
      "command": "/Applications/DingDong.app/Contents/MacOS/dingdong-mcp"
    }
  }
}
```

DingDong keeps resources in the app. Agents ask the bridge for summaries first and load full prompt, skill, or MCP content only when needed.

## Releases and Website

The static website lives in `docs/` and is deployed by GitHub Pages.

The app checks `docs/dingdong-release.json` through GitHub Pages and shows the current/latest version in Settings. Update this JSON whenever a release is published.

Pushing a tag like `v0.1.0` runs `.github/workflows/release.yml`, builds Apple Silicon and Intel zip archives, and attaches them to a GitHub Release.

## Trigger From An Agent

```bash
curl -X POST http://127.0.0.1:8765/ding \
  -H 'Content-Type: application/json' \
  -d '{"message":"Agent task complete","source":"Codex","sound":"random","flashCount":10}'
```

Supported fields:

- `message`: Text shown in the control panel.
- `source`: Optional agent name shown in recent activity.
- `sound`: `default`, `joy`, `levelUp`, `taDa`, `bubble`, `coin`, `fanfare`, `arcade`, `bloom`, `sunrise`, `popcorn`, `glimmer`, `rocket`, `sparkle`, `success`, `celebrate`, `random`, `custom`, `system`, or `muted`.
- `flashCount`: Number of icon flash steps, clamped from `2` to `30`.

Each agent-triggered `/ding` increments the unread number next to the menu bar icon. Opening the menu bar popover clears the number.

Recent agent activity is kept in memory with a small cap:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/events?limit=10'
```

Health check:

```bash
curl http://127.0.0.1:8765/health
```

Lightweight runtime status for agents:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/system/status
```

Use this before large imports or knowledge indexing. It returns resource counts, clipboard overview counts, clipboard monitoring state, bounded limits, and performance notes without scanning local knowledge folders.

## Codex Prompt Snippet

Add this to a Codex prompt or project instruction:

```text
Only once, immediately before the final answer for the whole user-visible task, call DingDong:

curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/ding \
  -H 'Content-Type: application/json' \
  -d '{"message":"Codex task complete","source":"Codex","sound":"random","flashCount":12}'
```

For richer messages:

```text
After the whole user-visible task is finished, call DingDong once. Do not call it for intermediate steps, tool batches, partial subtasks, or streaming segments. Set message to a concise summary of what changed. If the task failed, say why in message.
```

## Agent Command Templates

Open the API tab to copy common agent commands, or fetch them as JSON:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/templates
```

Fetch the structured capability manifest:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/capabilities
```

Fetch the machine-readable local agent discovery manifest:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/manifest
```

The same manifest is also available at `/.well-known/dingdong-agent.json`. Use this as the first call for external local agents that need the base URL, privacy defaults, entrypoints, recommended flow, command template ids, and supported endpoints without guessing DingDong's API shape.

Fetch copyable onboarding instructions for Codex, Claude Code, Cursor agents, or local scripts:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/toolkit
```

Use this when writing an agent prompt. It returns the local privacy rules, suggested startup flow, resource counts, and common commands.

Fetch a one-call startup pack for an agent task:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/startup?task=code%20review&limit=12'
```

Use this at the start of an agent run when you want a single lightweight response with the startup brief, active agents, pinned resources, and task-scoped context excerpts. It keeps clipboard content hidden by default; pass `includeClipboard=true` only when the user explicitly wants clipboard-aware work.

Fetch a full task preparation pack before an agent starts work:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/prepare?task=code%20review&limit=8'
```

Use this when an agent needs the strongest one-call setup. It combines system status, startup context, resource recommendations, clipboard insights, command ids, and next actions. Clipboard content remains hidden by default, and clipboard insights stay metadata-only. Sensitive clipboard metadata is hidden unless `includeSensitiveClipboardInsights=true` is passed.

Fetch a lightweight local agent workbench before starting or resuming work:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/workbench?task=code%20review&limit=8'
```

Use this when multiple local agents may be working on the same Mac. It returns active agents, active sessions, open or blocked handoffs, related durable memories, command ids, and next actions without returning clipboard content.

Fetch a copyable task startup prompt for another local agent:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/instructions?task=code%20review&limit=6'
```

Use this when you want Codex, Claude Code, Cursor, or a local script to follow the same DingDong workflow. It returns `copyablePrompt`, active sessions to consider, recommended resource ids, command ids, and privacy rules. Clipboard records are excluded by default; pass `includeClipboard=true` only when the user explicitly wants clipboard-aware work.

Register or refresh the current local agent presence:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/presence \
  -H 'Content-Type: application/json' \
  -d '{"source":"Codex","status":"active","task":"Working on DingDong","capabilities":["code","tests"]}'
```

List recently active local agents:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/presence?activeWithin=900&limit=10'
```

Create a shared multi-step task session:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/session \
  -H 'Content-Type: application/json' \
  -d '{
    "task": "Code review",
    "summary": "Review the current code changes before handoff.",
    "currentStep": "Inspect repository state",
    "nextActions": ["Run tests", "Record findings"],
    "source": "Codex",
    "status": "active",
    "tags": ["review"]
  }'
```

List or filter active sessions before starting work:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/sessions?status=active&limit=10'
```

Append progress to a session:

```bash
curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/agent/session/SESSION_ID \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "active",
    "progress": "Implemented the route and added regression tests.",
    "currentStep": "Run package and runtime checks",
    "nextActions": ["Install app", "Verify API from the running instance"],
    "source": "Codex"
  }'
```

Sessions are saved as `knowledge` resources in the `Agent Sessions` group. They are meant for active multi-agent coordination: current step, progress, resources, and next actions. Use handoff notes when the work should be resumed later by another agent.

Save a durable memory for future local agents:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/memory \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Code review preference",
    "content": "Always run regression tests before reporting completion.",
    "task": "code review",
    "kind": "preference",
    "source": "Codex",
    "tags": ["review", "tests"],
    "pinned": true
  }'
```

Read memories before starting related work:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/memories?q=code%20review&kind=preference&limit=10'
```

Memories are saved as `knowledge` resources in the `Agent Memories` group. Use sessions for active progress, handoffs for resumable work, and memories for durable preferences, rules, lessons, or project conventions that future agents should reuse.

Fetch a fast startup brief for an agent:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/agent/brief
```

Ask DingDong to recommend shared resources for a task:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/recommend?q=code%20review&type=prompt&limit=5'
```

Resolve the best matching shared resource and return its guarded detail in one call:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/resolve?q=code%20review&type=prompt'
```

Use `/agent/resolve` when an agent wants the strongest single best prompt, skill, MCP reference, or knowledge entry without first calling `/agent/recommend` and then `/agent/resource/{id}`.

Fetch one shared resource by id after a recommendation, context pack, or UI copy action:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/resource/RESOURCE_ID'
```

For prompts, skills, MCP references, and knowledge records, `/agent/resolve` and the direct resource route return the full resource body. Clipboard records remain hidden by default; pass `includeClipboard=true` only when the user explicitly wants clipboard-aware work, and add `includeSensitiveClipboard=true` for sensitive clipboard records.

Save the resources that mattered to a task as a reusable bundle:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/bundle \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Code review bundle",
    "task": "code review",
    "limit": 12,
    "source": "Codex",
    "tags": ["review", "bundle"]
  }'
```

Bundles are saved as `knowledge` resources in the `Agent Bundles` group, so later agents can find them through `/library`, `/library/groups`, `/agent/context`, or `/agent/startup`. The bundle endpoint excludes clipboard records by default; use `includeClipboard=true` only when the user explicitly wants clipboard-aware bundle content.

Leave a structured handoff note for future local agents:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/agent/handoff \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Continue UI polish",
    "summary": "The panel is functional; visual QA and spacing cleanup remain.",
    "nextSteps": ["Open DingDong panel", "Check compact layout", "Run swift test"],
    "source": "Codex",
    "status": "open",
    "tags": ["ui", "handoff"]
  }'
```

Read recent handoff notes:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/handoffs?status=open&limit=10'
```

Use `status=open`, `status=done`, or `status=blocked` to narrow the queue. The response includes `counts.byStatus` so agents can see the remaining handoff backlog without reading every note.

Update a handoff after another agent makes progress:

```bash
curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/agent/handoff/HANDOFF_ID \
  -H 'Content-Type: application/json' \
  -d '{
    "status": "done",
    "progress": "Implemented and verified the requested change.",
    "source": "Codex",
    "pinned": true
  }'
```

Fetch a bounded local context pack for an agent:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/agent/context?q=review&limit=20'
```

Clipboard records are excluded from the startup brief, recommendations, and context pack by default. Use `includeClipboard=true` only when the agent explicitly needs clipboard history. Prefer `/clipboard/history` when an agent only needs searchable clipboard metadata. Clipboard records tagged as sensitive, such as API keys, tokens, passwords, and private keys, remain excluded unless the agent also passes `includeSensitiveClipboard=true`.

Templates include task completion alerts, opening the panel, checking system status, fetching an agent toolkit, fetching a one-call startup pack, fetching an agent workbench, fetching copyable agent instructions, registering agent presence, creating/listing/updating task sessions, saving/listing durable memories, fetching an agent brief, recommending resources, resolving one best resource, fetching one resource by id, saving reusable task bundles, saving and listing handoffs, listing resource groups, searching the resource library, inspecting clipboard digests and history metadata, collecting clipboard records into reusable knowledge, importing folders, scanning knowledge paths, and toggling clipboard monitoring.

## Shared AI Resource Library

The Library tab can save prompts, skill repository notes, MCP server references, and local knowledge paths without using the API. Use groups and tags to keep entries easy for agents to query. Each resource row can be copied, edited, pinned or unpinned, and deleted from the UI. The Library toolbar can also import a folder of prompts, skills, MCP references, or knowledge paths. Knowledge rows can be scanned from the panel to show file summaries and copy file paths.

New empty libraries are seeded with default AI companion resources for agent startup, engineering review, skills repository slots, MCP repository slots, local knowledge, agent bundles, and clipboard snippets. Existing libraries can install missing defaults without overwriting user data:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/library/seed-defaults
```

Add a reusable prompt:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/library \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "prompt",
    "title": "Code review checklist",
    "content": "Review for correctness, regressions, missing tests, and performance risks.",
    "tags": ["review", "codex"],
    "source": "Codex",
    "pinned": true
  }'
```

List all resources:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/library
```

Filter by type:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library?type=prompt'
```

List resource groups with counts so an agent can choose a narrower search:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library/groups?type=prompt'
```

Export a bounded resource snapshot for backup, migration, or another local agent:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/library/export?limit=200'
```

The export includes resource content for prompts, skills, MCP references, and knowledge records. Clipboard records are excluded by default; pass `includeClipboard=true` only when the user explicitly wants clipboard resources exported, and `includeSensitiveClipboard=true` only for sensitive clipboard records.

Edit, pin, or unpin a resource. `PATCH` accepts any subset of `type`, `group`, `title`, `content`, `tags`, `source`, and `pinned`:

```bash
curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/library/RESOURCE_ID \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "mcp",
    "group": "Servers",
    "title": "Local MCP server",
    "content": "npx @example/server",
    "tags": ["mcp", "local"],
    "pinned": true
  }'
```

Delete a resource:

```bash
curl --noproxy 127.0.0.1 -sS -X DELETE http://127.0.0.1:8765/library/RESOURCE_ID
```

Supported resource types:

- `prompt`
- `skill`
- `mcp`
- `knowledge`
- `clipboard`

Bulk import a folder. Import scans direct children only, skips duplicates, and imports at most 50 items per request:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/library/import \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "knowledge",
    "path": "/Users/me/project",
    "group": "Project Docs",
    "tags": ["project", "docs"],
    "limit": 20
  }'
```

Index a local knowledge directory directly:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/knowledge/index?path=/Users/me/project/docs&limit=20'
```

Index a saved `knowledge` resource by id:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/knowledge/index?id=RESOURCE_ID'
```

Knowledge indexing is on demand. It returns lightweight file metadata plus short text summaries for common text/code files, capped at 40 files per request.

Capture current text clipboard as a resource:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/capture
```

Inspect clipboard classification counts, groups, and tags without returning clipboard content:

```bash
curl --noproxy 127.0.0.1 -sS http://127.0.0.1:8765/clipboard/overview
```

Inspect clipboard candidates and recommended agent actions without returning clipboard content:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/insights?limit=8'
```

The insights route is the preferred first clipboard call for agents. It returns metadata-only snippet candidates, promote candidates, and recommended actions such as adding `alias:name`, promoting durable context, restoring a snippet, or reviewing sensitive records. Clipboard content is never returned by this route. Sensitive clipboard metadata is hidden unless `includeSensitiveClipboard=true` is passed.

Fetch a task-scoped clipboard digest for an agent:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/digest?task=code%20review&limit=8'
```

The digest route is stronger than plain history search when an agent is working on a task. It returns matching groups, classifications, candidate ids, aliases, restore/promote actions, and metadata summaries. Clipboard content is hidden by default; pass `includeContent=true` only when the user explicitly wants clipboard-aware work, and add `includeSensitiveClipboard=true` only for sensitive clipboard records with explicit approval.

Save task-scoped clipboard records as reusable local knowledge:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/collect \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Code review clipboard collection",
    "task": "code review",
    "limit": 10,
    "source": "Codex",
    "tags": ["review", "clipboard"]
  }'
```

Collections are saved as `knowledge` resources in the `Clipboard Collections` group, so later agents can find them through `/library`, `/agent/context`, `/agent/startup`, or `/agent/resolve`. Sensitive clipboard records are excluded by default; pass `includeSensitiveClipboard=true` only with explicit user approval.

Search clipboard history metadata without returning clipboard content:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/history?filter=command&q=curl&limit=10'
```

`filter` can be `all`, `url`, `command`, `code`, `json`, `path`, `email`, or `sensitive`. The history route returns ids, titles, groups, tags, classification, timestamps, pin state, and character counts. It does not return `content` unless `includeContent=true` is passed. Sensitive clipboard records are hidden unless `includeSensitiveClipboard=true` is also passed.

Inspect clipboard groups:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/groups'
```

List reusable clipboard snippets. A clipboard record becomes a snippet when its tags include `alias:name`:

```bash
curl --noproxy 127.0.0.1 -sS 'http://127.0.0.1:8765/clipboard/snippets?alias=deploy&limit=10'
```

Restore the newest pinned snippet with a matching alias back to the system clipboard:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/snippet/deploy/restore
```

Snippet routes return metadata only by default and hide sensitive clipboard records unless `includeSensitiveClipboard=true` is passed.

Organize a clipboard record without changing its original content:

```bash
curl --noproxy 127.0.0.1 -sS -X PATCH http://127.0.0.1:8765/clipboard/CLIPBOARD_ID \
  -H 'Content-Type: application/json' \
  -d '{"group":"Agent Research","tags":["clipboard","research","alias:deploy"],"pinned":true}'
```

The clipboard patch route only edits `title`, `group`, `tags`, and `pinned`. It rejects `content`, `type`, and `source` changes so agents can organize clipboard history safely. Existing classification tags are preserved when new tags are added.

Clipboard capture skips duplicate text records and keeps the latest 200 clipboard entries so the local JSON store does not grow without bound. Captured text is classified locally with lightweight string rules. DingDong adds searchable groups and tags for URLs, domains, JSON, shell commands, code snippets, email addresses, file paths, and sensitive secrets without calling any AI model or external service.

Examples:

- `https://example.com/docs` becomes searchable by `url` and `domain:example.com`.
- `curl -sS http://127.0.0.1:8765/health` becomes searchable by `command` and `curl`.
- JSON snippets become searchable by `json` and `structured`.
- API keys, tokens, passwords, and private keys become searchable by `sensitive` and stay hidden from Agent context unless explicitly included.

Classified clipboard records also get useful groups such as `URLs`, `Commands`, `Code`, `JSON`, `Paths`, `Email`, and `Sensitive`, while plain text remains in `Clipboard`.

The Clipboard tab also has smart filter chips for `URL`, `Command`, `Code`, `JSON`, `Path`, `Email`, and `Sensitive`, so common clipboard types can be reviewed without remembering the tag names.

Promote a clipboard record into a shared AI resource:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/promote/CLIPBOARD_ID \
  -H 'Content-Type: application/json' \
  -d '{"targetType":"prompt","pinned":true}'
```

`targetType` can be `prompt`, `skill`, `mcp`, or `knowledge`. In the Clipboard tab, use the wand button on a clipboard row to save it as a prompt.

Restore a saved clipboard record back to the system clipboard:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/clipboard/restore/CLIPBOARD_ID
```

Enable low-overhead clipboard monitoring:

```bash
curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/clipboard/monitor?enabled=true'
```

Disable clipboard monitoring:

```bash
curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/clipboard/monitor?enabled=false'
```

Show the DingDong panel from an agent:

```bash
curl --noproxy 127.0.0.1 -sS -X POST 'http://127.0.0.1:8765/ui/show?tab=today'
```

Use `tab=today`, `tab=library`, `tab=clipboard`, or `tab=api` to open the panel directly to the view relevant to the agent's next action.

The resource library is stored locally in:

```text
~/Library/Application Support/DingDong/resource-library.json
```

DingDong rejects oversized writes before storing them locally: shared resource content is capped at 100,000 characters, and captured clipboard content is capped at 20,000 characters. This keeps the menu bar process and JSON store lightweight even when agents or the clipboard produce large payloads.

## Sound Themes

DingDong includes lightweight built-in sound themes. `joy`, `levelUp`, `taDa`, `bubble`, `coin`, `fanfare`, `arcade`, `bloom`, `sunrise`, `popcorn`, `glimmer`, and `rocket` are short locally synthesized chimes, while `sparkle`, `success`, and `celebrate` are made from short macOS system sound sequences. Use `random` when an agent should pick a cheerful theme automatically. Agents can choose a theme through the `sound` field:

```bash
curl --noproxy 127.0.0.1 -sS -X POST http://127.0.0.1:8765/ding \
  -H 'Content-Type: application/json' \
  -d '{"message":"Build passed","source":"Codex","sound":"joy","flashCount":12}'
```

Open the API tab in the DingDong control panel to try the built-in sound themes. You can also choose a custom audio file. The selected path is stored in user defaults. If a custom file is missing or cannot be played, DingDong falls back to the system sound.

## Development

```bash
swift test
swift build
```

Package and install:

```bash
scripts/package_app.sh
rm -rf /Applications/DingDong.app
ditto dist/DingDong.app /Applications/DingDong.app
open /Applications/DingDong.app
```
