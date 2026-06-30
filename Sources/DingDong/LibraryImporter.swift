import Foundation

struct LibraryImportRequest: Codable, Equatable {
    var type: ResourceType
    var path: String
    var group: String?
    var tags: [String]?
    var source: String?
    var limit: Int?
}

struct LibraryImportResult: Equatable {
    var imported: [ResourceItem]
    var skippedCount: Int
    var scannedCount: Int
}

struct LibraryImporter {
    static let defaultLimit = 30
    static let maxLimit = 50
    static let maxPromptCharacters = ResourceLimits.maxClipboardContentCharacters

    var fileManager: FileManager = .default

    func candidates(from request: LibraryImportRequest, existing: [ResourceItem]) throws -> LibraryImportResult {
        let rootURL = URL(fileURLWithPath: (request.path as NSString).expandingTildeInPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryImportError.missingDirectory
        }

        let limit = max(1, min(request.limit ?? Self.defaultLimit, Self.maxLimit))
        let children = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        let existingContent = Set(existing.map { normalizedContent($0.content, type: request.type) })
        var imported: [ResourceItem] = []
        var skippedCount = 0
        var scannedCount = 0

        for child in children {
            guard imported.count < limit else {
                skippedCount += 1
                continue
            }

            scannedCount += 1
            guard let item = makeItem(url: child, request: request),
                  !existingContent.contains(normalizedContent(item.content, type: item.type)) else {
                skippedCount += 1
                continue
            }

            imported.append(item)
        }

        return LibraryImportResult(
            imported: imported,
            skippedCount: skippedCount,
            scannedCount: scannedCount
        )
    }

    private func makeItem(url: URL, request: LibraryImportRequest) -> ResourceItem? {
        switch request.type {
        case .prompt:
            return makePromptItem(url: url, request: request)
        case .skill:
            return makePathItem(url: url, request: request, acceptedDirectoryMarkers: ["SKILL.md", "skill.md"])
        case .mcp:
            return makeMCPItem(url: url, request: request)
        case .knowledge:
            return makeKnowledgeItem(url: url, request: request)
        case .clipboard:
            return nil
        }
    }

    private func makePromptItem(url: URL, request: LibraryImportRequest) -> ResourceItem? {
        guard ["md", "markdown", "txt"].contains(url.pathExtension.lowercased()),
              let content = try? String(contentsOf: url, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ResourceItem(
            type: .prompt,
            group: request.group,
            title: title(for: url),
            content: String(content.prefix(Self.maxPromptCharacters)),
            tags: request.tags ?? ["imported", "prompt"],
            source: request.source ?? "Library Import"
        )
    }

    private func makePathItem(url: URL, request: LibraryImportRequest, acceptedDirectoryMarkers: [String]) -> ResourceItem? {
        guard isDirectory(url) else {
            return nil
        }

        let hasMarker = acceptedDirectoryMarkers.contains { marker in
            fileManager.fileExists(atPath: url.appendingPathComponent(marker).path)
        }
        guard hasMarker else {
            return nil
        }

        return ResourceItem(
            type: request.type,
            group: request.group,
            title: title(for: url),
            content: url.path,
            tags: request.tags ?? ["imported", request.type.rawValue],
            source: request.source ?? "Library Import"
        )
    }

    private func makeMCPItem(url: URL, request: LibraryImportRequest) -> ResourceItem? {
        if isDirectory(url) {
            let markers = ["package.json", "mcp.json", "server.json"]
            guard markers.contains(where: { fileManager.fileExists(atPath: url.appendingPathComponent($0).path) }) else {
                return nil
            }

            return pathResource(url: url, request: request, type: .mcp)
        }

        guard ["json", "toml", "yaml", "yml"].contains(url.pathExtension.lowercased()) else {
            return nil
        }

        return pathResource(url: url, request: request, type: .mcp)
    }

    private func makeKnowledgeItem(url: URL, request: LibraryImportRequest) -> ResourceItem? {
        if isDirectory(url) {
            return pathResource(url: url, request: request, type: .knowledge)
        }

        guard ["md", "markdown", "txt", "json", "yaml", "yml"].contains(url.pathExtension.lowercased()) else {
            return nil
        }

        return pathResource(url: url, request: request, type: .knowledge)
    }

    private func pathResource(url: URL, request: LibraryImportRequest, type: ResourceType) -> ResourceItem {
        ResourceItem(
            type: type,
            group: request.group,
            title: title(for: url),
            content: url.path,
            tags: request.tags ?? ["imported", type.rawValue],
            source: request.source ?? "Library Import"
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func title(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }

    private func normalizedContent(_ content: String, type: ResourceType) -> String {
        switch type {
        case .skill, .mcp, .knowledge:
            URL(fileURLWithPath: (content as NSString).expandingTildeInPath).standardizedFileURL.path
        case .prompt, .clipboard:
            content
        }
    }
}

enum LibraryImportError: Error {
    case missingDirectory
}
