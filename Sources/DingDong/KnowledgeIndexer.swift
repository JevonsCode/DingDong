import Foundation

struct KnowledgeIndexEntry: Equatable {
    var path: String
    var name: String
    var relativePath: String
    var byteCount: Int
    var modifiedAt: Date?
    var summary: String
}

struct KnowledgeIndexResult: Equatable {
    var root: String
    var files: [KnowledgeIndexEntry]
    var scannedCount: Int
    var skippedCount: Int
    var truncated: Bool
}

struct KnowledgeIndexer {
    static let defaultMaxFiles = 40
    static let maxSummaryCharacters = 300

    var fileManager: FileManager = .default

    func index(rootPath: String, maxFiles: Int = defaultMaxFiles) throws -> KnowledgeIndexResult {
        let expandedPath = (rootPath as NSString).expandingTildeInPath
        let rootURL = URL(fileURLWithPath: expandedPath).standardizedFileURL
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw KnowledgeIndexError.missingDirectory
        }

        let effectiveMaxFiles = max(1, min(maxFiles, Self.defaultMaxFiles))
        var entries: [KnowledgeIndexEntry] = []
        var scannedCount = 0
        var skippedCount = 0
        var truncated = false

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw KnowledgeIndexError.cannotEnumerate
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try? fileURL.resourceValues(forKeys: Set<URLResourceKey>([.isDirectoryKey]))
            if resourceValues?.isDirectory == true {
                continue
            }

            guard Self.isIndexable(fileURL) else {
                skippedCount += 1
                continue
            }

            guard entries.count < effectiveMaxFiles else {
                truncated = true
                break
            }

            scannedCount += 1
            entries.append(makeEntry(fileURL: fileURL, rootURL: rootURL))
        }

        return KnowledgeIndexResult(
            root: rootURL.path,
            files: entries,
            scannedCount: scannedCount,
            skippedCount: skippedCount,
            truncated: truncated
        )
    }

    private func makeEntry(fileURL: URL, rootURL: URL) -> KnowledgeIndexEntry {
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        return KnowledgeIndexEntry(
            path: fileURL.path,
            name: fileURL.lastPathComponent,
            relativePath: relativePath(fileURL: fileURL, rootURL: rootURL),
            byteCount: values?.fileSize ?? 0,
            modifiedAt: values?.contentModificationDate,
            summary: Self.summary(for: content)
        )
    }

    private func relativePath(fileURL: URL, rootURL: URL) -> String {
        let root = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard fileURL.path.hasPrefix(root) else {
            return fileURL.lastPathComponent
        }

        return String(fileURL.path.dropFirst(root.count))
    }

    private static func isIndexable(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "md", "markdown", "txt", "json", "yaml", "yml", "toml", "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "kt", "sh", "zsh", "sql", "html", "css":
            true
        default:
            false
        }
    }

    private static func summary(for content: String) -> String {
        let collapsed = content
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard collapsed.count > maxSummaryCharacters else {
            return collapsed
        }

        return String(collapsed.prefix(maxSummaryCharacters)) + "..."
    }
}

enum KnowledgeIndexError: Error {
    case missingDirectory
    case cannotEnumerate
}
