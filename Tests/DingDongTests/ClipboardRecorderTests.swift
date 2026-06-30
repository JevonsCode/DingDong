import Foundation
import Testing
@testable import DingDong

private struct StubClipboardReader: ClipboardReading {
    var value: String?
    var urls: [URL] = []
    var image: ClipboardImageData?
    var changeCount = 1

    func stringValue() -> String? {
        value
    }

    func fileURLs() -> [URL] {
        urls
    }

    func imageData() -> ClipboardImageData? {
        image
    }
}

struct ClipboardRecorderTests {
    @Test func emptyClipboardReturnsNil() {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "   "))

        #expect(recorder.capture() == nil)
    }

    @Test func textClipboardCreatesClipboardResource() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "First line\nSecond line"))

        let item = try #require(recorder.capture(source: "Test"))

        #expect(item.type == .clipboard)
        #expect(item.group == "Clipboard")
        #expect(item.title == "First line")
        #expect(item.content == "First line\nSecond line")
        #expect(item.source == "Test")
    }

    @Test func urlClipboardAddsURLTagsAndReadableTitle() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "https://example.com/docs/agent?tab=api"))

        let item = try #require(recorder.capture())

        #expect(item.group == "URLs")
        #expect(item.title == "URL: example.com/docs/agent")
        #expect(item.tags.contains("url"))
        #expect(item.tags.contains("domain:example.com"))
    }

    @Test func jsonClipboardAddsStructuredTags() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: #"{"message":"done","source":"Codex"}"#))

        let item = try #require(recorder.capture())

        #expect(item.group == "JSON")
        #expect(item.title == "JSON: message, source")
        #expect(item.tags.contains("json"))
        #expect(item.tags.contains("structured"))
    }

    @Test func shellCommandClipboardAddsCommandTags() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "curl -sS http://127.0.0.1:8765/health"))

        let item = try #require(recorder.capture())

        #expect(item.group == "Commands")
        #expect(item.title == "Command: curl -sS http://127.0.0.1:8765/health")
        #expect(item.tags.contains("command"))
        #expect(item.tags.contains("curl"))
    }

    @Test func codeClipboardAddsCodeTags() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "func runAgent() {\n    print(\"done\")\n}"))

        let item = try #require(recorder.capture())

        #expect(item.group == "Code")
        #expect(item.title == "Code: func runAgent() {")
        #expect(item.tags.contains("code"))
        #expect(item.tags.contains("swift"))
    }

    @Test func emailAndPathClipboardUseDedicatedGroups() throws {
        let emailRecorder = ClipboardRecorder(reader: StubClipboardReader(value: "agent@example.com"))
        let pathRecorder = ClipboardRecorder(reader: StubClipboardReader(value: "/Users/me/project/README.md"))

        let email = try #require(emailRecorder.capture())
        let path = try #require(pathRecorder.capture())

        #expect(email.group == "Email")
        #expect(email.tags.contains("email"))
        #expect(path.group == "Paths")
        #expect(path.tags.contains("path"))
    }

    @Test func copiedImageFileCreatesImageClipboardResource() throws {
        let url = URL(fileURLWithPath: "/Users/me/Desktop/reference.png")
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: nil, urls: [url]))

        let item = try #require(recorder.capture(source: "Finder"))

        #expect(item.type == .clipboard)
        #expect(item.group == "Images")
        #expect(item.title == "Image: reference.png")
        #expect(item.content == "/Users/me/Desktop/reference.png")
        #expect(item.source == "Finder")
        #expect(item.tags.contains("file"))
        #expect(item.tags.contains("file-url"))
        #expect(item.tags.contains("image"))
        #expect(item.tags.contains("ext:png"))
    }

    @Test func copiedBitmapImageCreatesStoredImageClipboardResource() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-clipboard-images-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let recorder = ClipboardRecorder(
            reader: StubClipboardReader(
                value: nil,
                image: ClipboardImageData(data: Data([0x89, 0x50, 0x4E, 0x47]), fileExtension: "png")
            ),
            imageStoreDirectory: directory
        )

        let item = try #require(recorder.capture(source: "Codex"))
        let storedURL = URL(fileURLWithPath: item.content)

        #expect(item.type == .clipboard)
        #expect(item.group == "Images")
        #expect(item.title.hasPrefix("Image: clipboard-"))
        #expect(item.source == "Codex")
        #expect(item.tags.contains("file"))
        #expect(item.tags.contains("file-url"))
        #expect(item.tags.contains("image"))
        #expect(item.tags.contains("ext:png"))
        #expect(FileManager.default.fileExists(atPath: storedURL.path))
    }

    @Test func pruneStoredImagesRemovesOnlyUnreferencedInternalFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("dingdong-clipboard-prune-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let keptURL = directory.appendingPathComponent("kept.png")
        let orphanURL = directory.appendingPathComponent("orphan.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: keptURL)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: orphanURL)

        let retainedItem = ResourceItem(
            type: .clipboard,
            group: "Images",
            title: "Image: kept.png",
            content: keptURL.path,
            tags: ["clipboard", "file", "file-url", "image", "ext:png"]
        )
        let recorder = ClipboardRecorder(reader: StubClipboardReader(), imageStoreDirectory: directory)

        recorder.pruneStoredImages(retainedItems: [retainedItem])

        #expect(FileManager.default.fileExists(atPath: keptURL.path))
        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
    }

    @Test func copiedFileURLsTakePrecedenceOverStringFallback() throws {
        let url = URL(fileURLWithPath: "/Users/me/Desktop/reference.jpg")
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "fallback text", urls: [url]))

        let item = try #require(recorder.capture())

        #expect(item.group == "Images")
        #expect(item.content == "/Users/me/Desktop/reference.jpg")
        #expect(!item.tags.contains("text"))
    }

    @Test func sensitiveClipboardAddsPrivacyTags() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "OPENAI_API_KEY=sk-test1234567890abcdef1234567890"))

        let item = try #require(recorder.capture())

        #expect(item.group == "Sensitive")
        #expect(item.title == "Sensitive: API key or token")
        #expect(item.tags.contains("sensitive"))
        #expect(item.tags.contains("secret"))
        #expect(item.tags.contains("api-key"))
    }

    @Test func classifiedClipboardTagsAreSearchable() throws {
        let recorder = ClipboardRecorder(reader: StubClipboardReader(value: "https://example.com/docs/agent?tab=api"))
        let item = try #require(recorder.capture())
        let store = InMemoryResourceStore(items: [item])

        let results = try store.list(type: .clipboard, query: "domain:example.com", limit: nil)
        let groupResults = try store.list(type: .clipboard, query: "URLs", limit: nil)

        #expect(results.map(\.id) == [item.id])
        #expect(groupResults.map(\.id) == [item.id])
    }
}
