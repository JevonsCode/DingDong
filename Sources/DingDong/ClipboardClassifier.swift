import Foundation

struct ClipboardClassification: Equatable {
    var group: String
    var title: String
    var tags: [String]
}

enum ClipboardClassifier {
    static func classify(_ text: String) -> ClipboardClassification {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let sensitiveKind = sensitiveKind(for: trimmed) {
            return ClipboardClassification(
                group: "Sensitive",
                title: "Sensitive: \(sensitiveTitle(for: sensitiveKind))",
                tags: ["clipboard", "sensitive", "secret", sensitiveKind]
            )
        }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme),
           let host = url.host {
            return ClipboardClassification(
                group: "URLs",
                title: "URL: \(urlTitle(host: host, path: url.path))",
                tags: ["clipboard", "url", "domain:\(host.lowercased())"]
            )
        }

        if let jsonTitle = jsonTitle(for: trimmed) {
            return ClipboardClassification(
                group: "JSON",
                title: "JSON: \(jsonTitle)",
                tags: ["clipboard", "json", "structured"]
            )
        }

        if let command = commandName(for: trimmed) {
            return ClipboardClassification(
                group: "Commands",
                title: "Command: \(lineTitle(for: trimmed))",
                tags: ["clipboard", "command", command]
            )
        }

        if let language = codeLanguage(for: trimmed) {
            return ClipboardClassification(
                group: "Code",
                title: "Code: \(lineTitle(for: trimmed))",
                tags: ["clipboard", "code", language]
            )
        }

        if let email = emailAddress(in: trimmed) {
            return ClipboardClassification(
                group: "Email",
                title: "Email: \(email)",
                tags: ["clipboard", "email"]
            )
        }

        if looksLikeFilePath(trimmed) {
            return ClipboardClassification(
                group: "Paths",
                title: "Path: \(lineTitle(for: trimmed))",
                tags: ["clipboard", "path"]
            )
        }

        return ClipboardClassification(
            group: ResourceType.clipboard.defaultGroup,
            title: lineTitle(for: trimmed),
            tags: ["clipboard", "text"]
        )
    }

    private static func urlTitle(host: String, path: String) -> String {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleanPath.isEmpty else {
            return host
        }
        return lineTitle(for: "\(host)/\(cleanPath)", maxLength: 56)
    }

    private static func jsonTitle(for text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let dictionary = object as? [String: Any], !dictionary.isEmpty {
            let keys = dictionary.keys.sorted().prefix(3).joined(separator: ", ")
            return keys.isEmpty ? "object" : keys
        }

        if let array = object as? [Any] {
            return "array \(array.count)"
        }

        return "value"
    }

    private static func commandName(for text: String) -> String? {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstToken = trimmed.split(separator: " ").first.map(String.init) ?? ""
        let knownCommands = [
            "curl", "git", "swift", "npm", "pnpm", "yarn", "node", "python", "python3",
            "brew", "docker", "kubectl", "gh", "ssh", "scp", "rsync", "mkdir", "cp", "mv",
            "rm", "cat", "rg", "grep", "sed", "awk", "chmod", "open"
        ]

        guard knownCommands.contains(firstToken) || trimmed.hasPrefix("./") else {
            return nil
        }

        return firstToken.trimmingCharacters(in: CharacterSet(charactersIn: "./")).nilIfEmpty ?? "script"
    }

    private static func codeLanguage(for text: String) -> String? {
        let lowercased = text.lowercased()
        if lowercased.contains("func ") || lowercased.contains("import swiftui") || lowercased.contains("import foundation") {
            return "swift"
        }
        if lowercased.contains("function ") || lowercased.contains("const ") || lowercased.contains("let ") || lowercased.contains("=>") {
            return "javascript"
        }
        if lowercased.contains("def ") || lowercased.contains("import ") && lowercased.contains(":") {
            return "python"
        }
        if lowercased.contains("<html") || lowercased.contains("<div") || lowercased.contains("</") {
            return "html"
        }
        if lowercased.contains("{") && lowercased.contains("}") && lowercased.contains(";") {
            return "code"
        }
        return nil
    }

    private static func emailAddress(in text: String) -> String? {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        guard text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil else {
            return nil
        }
        return text
    }

    private static func looksLikeFilePath(_ text: String) -> Bool {
        text.hasPrefix("/")
            || text.hasPrefix("~/")
            || text.hasPrefix("./")
            || text.hasPrefix("../")
    }

    private static func sensitiveKind(for text: String) -> String? {
        if text.range(of: #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#, options: [.regularExpression]) != nil {
            return "private-key"
        }

        if text.range(of: #"\bAKIA[0-9A-Z]{16}\b"#, options: [.regularExpression]) != nil {
            return "aws-key"
        }

        if text.range(of: #"\bgh[pousr]_[A-Za-z0-9_]{24,}\b"#, options: [.regularExpression]) != nil {
            return "github-token"
        }

        if text.range(of: #"\bsk-[A-Za-z0-9_-]{20,}\b"#, options: [.regularExpression]) != nil {
            return "api-key"
        }

        let assignmentPattern = #"\b(api[_-]?key|secret|token|password|passwd|pwd|authorization|bearer)\b\s*[:=]\s*\S{8,}"#
        if text.range(of: assignmentPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return "api-key"
        }

        return nil
    }

    private static func sensitiveTitle(for kind: String) -> String {
        switch kind {
        case "private-key":
            "Private key"
        case "aws-key":
            "AWS key"
        case "github-token":
            "GitHub token"
        case "api-key":
            "API key or token"
        default:
            "Secret"
        }
    }

    private static func lineTitle(for text: String, maxLength: Int = 48) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? text

        guard firstLine.count > maxLength else {
            return firstLine
        }

        return String(firstLine.prefix(maxLength - 3)) + "..."
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
