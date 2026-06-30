import Foundation
import Testing
@testable import DingDong

struct KnowledgeIndexerTests {
    @Test func indexesOnlySupportedTextFilesWithSummaries() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-knowledge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "First line\n\nSecond line".write(to: root.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        try Data([0, 1, 2]).write(to: root.appendingPathComponent("image.png"))

        let result = try KnowledgeIndexer().index(rootPath: root.path)

        #expect(result.files.count == 1)
        #expect(result.files.first?.relativePath == "notes.md")
        #expect(result.files.first?.summary == "First line Second line")
        #expect(result.skippedCount == 1)
    }

    @Test func indexLimitIsBoundedAndReportsTruncation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-knowledge-limit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        for index in 0..<3 {
            try "File \(index)".write(to: root.appendingPathComponent("file-\(index).txt"), atomically: true, encoding: .utf8)
        }

        let result = try KnowledgeIndexer().index(rootPath: root.path, maxFiles: 2)

        #expect(result.files.count == 2)
        #expect(result.truncated == true)
    }

    @Test func missingDirectoryThrows() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-missing-\(UUID().uuidString)")
            .path

        #expect(throws: KnowledgeIndexError.missingDirectory) {
            _ = try KnowledgeIndexer().index(rootPath: path)
        }
    }
}
