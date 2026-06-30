import Foundation
import Testing
@testable import DingDong

struct ClipboardFileReferenceTests {
    @Test func imageURLUsesFirstExistingImageFile() throws {
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-preview-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let textURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-preview-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        try Data("hello".utf8).write(to: textURL)
        defer {
            try? FileManager.default.removeItem(at: imageURL)
            try? FileManager.default.removeItem(at: textURL)
        }

        let item = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Image",
            content: [textURL.path, imageURL.path].joined(separator: "\n"),
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )

        #expect(ClipboardFileReference.fileURLs(for: item).map(\.path) == [textURL.path, imageURL.path])
        #expect(ClipboardFileReference.imageURL(for: item)?.path == imageURL.path)
    }

    @Test func missingFileURLsAreIgnoredByDefault() {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-missing-\(UUID().uuidString)")
            .appendingPathExtension("png")
            .path
        let item = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Missing",
            content: missingPath,
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )

        #expect(ClipboardFileReference.fileURLs(for: item).isEmpty)
        #expect(ClipboardFileReference.fileURLs(for: item, existingOnly: false).map(\.path) == [missingPath])
        #expect(ClipboardFileReference.imageURL(for: item) == nil)
    }

    @Test func plainTextImagePathIsNotTreatedAsFileReference() throws {
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-plain-path-\(UUID().uuidString)")
            .appendingPathExtension("png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let item = ResourceItem(
            type: .clipboard,
            group: "Paths",
            title: "Image path",
            content: imageURL.path,
            tags: ["clipboard", "path"]
        )

        #expect(ClipboardFileReference.fileURLs(for: item).isEmpty)
        #expect(ClipboardFileReference.imageURL(for: item) == nil)
    }

    @Test func plainTextImagePathContainingSpacesIsNotTreatedAsFileReference() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong preview \(UUID().uuidString)", isDirectory: true)
        let imageURL = directory.appendingPathComponent("clipboard image.png")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let item = ResourceItem(
            type: .clipboard,
            group: "Paths",
            title: "Image path with spaces",
            content: imageURL.path,
            tags: ["clipboard", "path"]
        )

        #expect(ClipboardFileReference.fileURLs(for: item).isEmpty)
        #expect(ClipboardFileReference.imageURL(for: item) == nil)
    }

    @Test func fileURLTaggedPathContainingSpacesIsTreatedAsFileReference() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong file reference \(UUID().uuidString)", isDirectory: true)
        let imageURL = directory.appendingPathComponent("clipboard image.png")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let item = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Image path with spaces",
            content: imageURL.path,
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )

        #expect(ClipboardFileReference.fileURLs(for: item).map(\.path) == [imageURL.path])
        #expect(ClipboardFileReference.imageURL(for: item)?.path == imageURL.path)
    }
}
