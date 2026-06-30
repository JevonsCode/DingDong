import Foundation
import Testing
@testable import DingDong

struct LibraryImporterTests {
    @Test func importsPromptFilesFromDirectory() throws {
        let root = try makeDirectory()
        try "Review this diff".write(to: root.appendingPathComponent("review.md"), atomically: true, encoding: .utf8)
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("image.png"))
        let request = LibraryImportRequest(type: .prompt, path: root.path, group: nil, tags: nil, source: nil, limit: nil)

        let result = try LibraryImporter().candidates(from: request, existing: [])

        #expect(result.imported.count == 1)
        #expect(result.imported.first?.title == "review")
        #expect(result.imported.first?.content == "Review this diff")
        #expect(result.skippedCount == 1)
    }

    @Test func importsSkillDirectoriesWithSkillMarker() throws {
        let root = try makeDirectory()
        let skill = root.appendingPathComponent("code-review", isDirectory: true)
        let other = root.appendingPathComponent("notes", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try "skill instructions".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        let request = LibraryImportRequest(type: .skill, path: root.path, group: nil, tags: nil, source: nil, limit: nil)

        let result = try LibraryImporter().candidates(from: request, existing: [])

        #expect(result.imported.count == 1)
        #expect(result.imported.first?.title == "code-review")
        #expect(result.imported.first?.content.hasSuffix("/code-review") == true)
        #expect(FileManager.default.fileExists(atPath: result.imported.first?.content ?? "") == true)
    }

    @Test func skipsExistingResourcesByContent() throws {
        let root = try makeDirectory()
        let docs = root.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        let existing = ResourceItem(type: .knowledge, title: "Docs", content: docs.path)
        let request = LibraryImportRequest(type: .knowledge, path: root.path, group: nil, tags: nil, source: nil, limit: nil)

        let result = try LibraryImporter().candidates(from: request, existing: [existing])

        #expect(result.imported.isEmpty)
        #expect(result.skippedCount == 1)
    }

    private func makeDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
