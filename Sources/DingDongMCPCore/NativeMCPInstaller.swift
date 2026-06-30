import Foundation

struct MCPCommandSpec: Equatable {
    var command: String
    var args: [String]

    static func parse(from content: String) throws -> MCPCommandSpec {
        if let jsonSpec = parseJSONSpec(content) {
            return jsonSpec
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["Local command:", "Command:", "command:"] where trimmed.hasPrefix(prefix) {
                let raw = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return try parseCommandLine(raw)
            }
        }

        throw MCPInstallError.missingCommand
    }

    private static func parseJSONSpec(_ content: String) -> MCPCommandSpec? {
        guard let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = object["command"] as? String else {
            return nil
        }

        return MCPCommandSpec(
            command: command,
            args: object["args"] as? [String] ?? []
        )
    }

    private static func parseCommandLine(_ raw: String) throws -> MCPCommandSpec {
        let words = splitShellWords(raw)
        guard let command = words.first, !command.isEmpty else {
            throw MCPInstallError.missingCommand
        }

        return MCPCommandSpec(command: command, args: Array(words.dropFirst()))
    }

    private static func splitShellWords(_ raw: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var isEscaped = false

        for character in raw {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
                continue
            }

            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                continue
            }

            if character.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
                continue
            }

            current.append(character)
        }

        if !current.isEmpty {
            words.append(current)
        }

        return words
    }
}

struct NativeMCPInstallResult {
    var configPath: URL
    var entry: [String: Any]
}

struct NativeMCPInstaller {
    var config: DingDongMCPConfig

    func install(
        serverName: String,
        commandSpec: MCPCommandSpec,
        target: String,
        write: Bool
    ) throws -> NativeMCPInstallResult {
        switch target {
        case "codex":
            return try installCodex(serverName: serverName, commandSpec: commandSpec, write: write)
        case "claude":
            return try installClaude(serverName: serverName, commandSpec: commandSpec, write: write)
        default:
            throw MCPInstallError.invalidTarget
        }
    }

    private func installCodex(
        serverName: String,
        commandSpec: MCPCommandSpec,
        write: Bool
    ) throws -> NativeMCPInstallResult {
        let entry: [String: Any] = [
            "type": "stdio",
            "command": commandSpec.command,
            "args": commandSpec.args,
            "enabled": true
        ]

        if write {
            let existing = (try? String(contentsOf: config.codexConfigURL, encoding: .utf8)) ?? ""
            let updated = appendOrReplaceCodexBlock(
                serverName: serverName,
                commandSpec: commandSpec,
                content: existing
            )
            try FileManager.default.createDirectory(
                at: config.codexConfigURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try updated.write(to: config.codexConfigURL, atomically: true, encoding: .utf8)
        }

        return NativeMCPInstallResult(configPath: config.codexConfigURL, entry: entry)
    }

    private func installClaude(
        serverName: String,
        commandSpec: MCPCommandSpec,
        write: Bool
    ) throws -> NativeMCPInstallResult {
        var entry: [String: Any] = [
            "command": commandSpec.command
        ]
        if !commandSpec.args.isEmpty {
            entry["args"] = commandSpec.args
        }

        if write {
            let root = try readClaudeConfig()
            var servers = root["mcpServers"] as? [String: Any] ?? [:]
            servers[serverName] = entry

            var updated = root
            updated["mcpServers"] = servers
            let data = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys])
            try FileManager.default.createDirectory(
                at: config.claudeMCPConfigURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: config.claudeMCPConfigURL, options: [.atomic])
        }

        return NativeMCPInstallResult(configPath: config.claudeMCPConfigURL, entry: entry)
    }

    private func appendOrReplaceCodexBlock(
        serverName: String,
        commandSpec: MCPCommandSpec,
        content: String
    ) -> String {
        let header = "[mcp_servers.\(serverName)]"
        var lines = content.components(separatedBy: .newlines)
        if let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == header }) {
            var end = start + 1
            while end < lines.count {
                let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    break
                }
                end += 1
            }
            lines.removeSubrange(start..<end)
        }

        while lines.last == "" {
            lines.removeLast()
        }

        lines.append("")
        lines.append(header)
        lines.append("type = \"stdio\"")
        lines.append("command = \"\(tomlEscape(commandSpec.command))\"")
        if !commandSpec.args.isEmpty {
            lines.append("args = [\(commandSpec.args.map { "\"\(tomlEscape($0))\"" }.joined(separator: ", "))]")
        }
        lines.append("enabled = true")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func readClaudeConfig() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: config.claudeMCPConfigURL.path) else {
            return ["mcpServers": [:]]
        }

        let data = try Data(contentsOf: config.claudeMCPConfigURL)
        guard !data.isEmpty else {
            return ["mcpServers": [:]]
        }

        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? ["mcpServers": [:]]
    }

    private func tomlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum MCPInstallError: Error, CustomStringConvertible {
    case missingCommand
    case invalidTarget

    var description: String {
        switch self {
        case .missingCommand:
            "MCP resource does not include a command or Local command line"
        case .invalidTarget:
            "Unsupported native MCP target"
        }
    }
}
