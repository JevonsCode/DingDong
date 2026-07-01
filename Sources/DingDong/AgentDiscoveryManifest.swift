import Foundation

struct AgentDiscoveryManifest {
    static func object(apiEndpoint: AgentAPIEndpoint = AgentAPIEndpoint()) -> [String: Any] {
        let capabilities = AgentCapabilityManifest.object(apiEndpoint: apiEndpoint)
        let endpoints = (capabilities["endpoints"] as? [[String: Any]]) ?? []

        return [
            "schemaVersion": "1.0",
            "service": "DingDong",
            "description": "Local macOS AI companion for reminders, clipboard context, shared prompts, skills, MCP references, knowledge, memories, sessions, and handoffs.",
            "baseURL": apiEndpoint.baseURL,
            "transport": apiEndpoint.runtimeObject.merging(["type": "loopback-http"]) { current, _ in current },
            "entrypoints": [
                "health": "/health",
                "status": "/system/status",
                "toolkit": "/agent/toolkit",
                "bridge": "/agent/bridge?source=AGENT&task=TASK&limit=20",
                "startup": "/agent/startup?task=TASK&limit=10",
                "workbench": "/agent/workbench?task=TASK&limit=8",
                "instructions": "/agent/instructions?task=TASK&limit=6",
                "capabilities": "/agent/capabilities",
                "templates": "/agent/templates",
                "ding": "/ding"
            ],
            "recommendedFlow": [
                "GET /health",
                "GET /agent/manifest",
                "GET /agent/bridge?source=AGENT&task=TASK&limit=20 for summary-first prompt, skill, and MCP routing",
                "GET /agent/resource/{id} before applying a selected full skill, prompt, or MCP reference",
                "GET /agent/startup?task=TASK&limit=10",
                "GET /agent/workbench?task=TASK&limit=8",
                "POST /agent/presence",
                "GET /agent/memories?q=TASK&limit=10",
                "GET /agent/context?q=TASK&limit=20",
                "GET /clipboard/insights?limit=8 before requesting clipboard content",
                "POST /agent/session for multi-step work",
                "POST /agent/memory when a durable preference, rule, or lesson is learned",
                "POST /agent/handoff before handing work to another local agent",
                "POST /ding only once per user-visible task, immediately before the final answer, when the whole task is complete, blocked, or waiting for user attention"
            ],
            "privacyDefaults": [
                "clipboardContentIncluded": false,
                "sensitiveClipboardIncluded": false,
                "clipboardRule": "Use includeClipboard=true only when the user explicitly wants clipboard-aware work.",
                "sensitiveClipboardRule": "Use includeSensitiveClipboard=true only with explicit user approval.",
                "networkRule": "DingDong listens on loopback only.",
                "knowledgeIndexing": "On-demand and bounded."
            ],
            "resourceTypes": ResourceType.allCases.map(\.rawValue),
            "sounds": DingSound.apiValues,
            "features": capabilities["features"] ?? [],
            "limits": capabilities["limits"] ?? [:],
            "performance": capabilities["performance"] ?? [:],
            "commandTemplates": AgentCommandTemplate.defaults.map { template in
                [
                    "id": template.id,
                    "title": template.title,
                    "summary": template.summary
                ]
            },
            "endpointCount": endpoints.count,
            "endpoints": endpoints
        ]
    }
}
