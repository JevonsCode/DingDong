import Foundation

struct AgentLaunchpadCommand {
    static let baseURL = "http://127.0.0.1:8765"
    static let defaultTask = "next agent task"

    static func prepare(task: String, limit: Int = 8) -> String {
        let task = normalizedTask(task)
        let encodedTask = task.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters) ?? task
        return "curl --noproxy 127.0.0.1 -sS '\(baseURL)/agent/prepare?task=\(encodedTask)&limit=\(limit)'"
    }

    static func startup(task: String, limit: Int = 10) -> String {
        let task = normalizedTask(task)
        let encodedTask = task.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters) ?? task
        return "curl --noproxy 127.0.0.1 -sS '\(baseURL)/agent/startup?task=\(encodedTask)&limit=\(limit)'"
    }

    static func workbench(task: String, limit: Int = 8) -> String {
        let task = normalizedTask(task)
        let encodedTask = task.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters) ?? task
        return "curl --noproxy 127.0.0.1 -sS '\(baseURL)/agent/workbench?task=\(encodedTask)&limit=\(limit)'"
    }

    static func toolkit() -> String {
        "curl --noproxy 127.0.0.1 -sS '\(baseURL)/agent/toolkit'"
    }

    static func presence(task: String, source: String = "Codex") -> String {
        let payload = jsonPayload([
            "source": source,
            "status": "active",
            "task": normalizedTask(task),
            "capabilities": ["code", "tests", "local-agent"]
        ])

        return """
        curl --noproxy 127.0.0.1 -sS -X POST \(baseURL)/agent/presence \\
          -H 'Content-Type: application/json' \\
          -d \(shellSingleQuote(payload))
        """
    }

    static func memory(task: String, source: String = "Codex") -> String {
        let task = normalizedTask(task)
        let payload = jsonPayload([
            "title": "Memory for \(task)",
            "content": "Replace this with a durable preference, project rule, or lesson.",
            "task": task,
            "kind": "lesson",
            "source": source,
            "tags": ["agent-memory"]
        ])

        return """
        curl --noproxy 127.0.0.1 -sS -X POST \(baseURL)/agent/memory \\
          -H 'Content-Type: application/json' \\
          -d \(shellSingleQuote(payload))
        """
    }

    static func clipboardInsights(limit: Int = 8) -> String {
        "curl --noproxy 127.0.0.1 -sS '\(baseURL)/clipboard/insights?limit=\(limit)'"
    }

    static func clipboardDigest(task: String, limit: Int = 8, includeContent: Bool = false) -> String {
        let task = normalizedTask(task)
        let encodedTask = task.addingPercentEncoding(withAllowedCharacters: queryValueAllowedCharacters) ?? task
        return "curl --noproxy 127.0.0.1 -sS '\(baseURL)/clipboard/digest?task=\(encodedTask)&limit=\(limit)&includeContent=\(includeContent)'"
    }

    static func normalizedTask(_ task: String) -> String {
        task.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? defaultTask
    }

    private static func jsonPayload(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"source":"Codex","status":"active","task":"next agent task","capabilities":["code","tests","local-agent"]}"#
        }

        return string
    }

    private static func shellSingleQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static var queryValueAllowedCharacters: CharacterSet {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?")
        return allowed
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
