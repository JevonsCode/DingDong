import AppKit
import Foundation

protocol ClipboardReading {
    var changeCount: Int { get }
    func stringValue() -> String?
    func fileURLs() -> [URL]
    func imageData() -> ClipboardImageData?
}

struct ClipboardImageData: Equatable {
    var data: Data
    var fileExtension: String
}

struct SystemClipboardReader: ClipboardReading {
    var changeCount: Int {
        NSPasteboard.general.changeCount
    }

    func stringValue() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func fileURLs() -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let objects = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: options) ?? []
        return objects.compactMap { object in
            (object as? URL) ?? (object as? NSURL).map { $0 as URL }
        }
    }

    func imageData() -> ClipboardImageData? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) {
            return ClipboardImageData(data: data, fileExtension: "png")
        }

        if let tiffData = pasteboard.data(forType: .tiff) {
            return Self.pngData(fromTIFF: tiffData)
                .map { ClipboardImageData(data: $0, fileExtension: "png") }
                ?? ClipboardImageData(data: tiffData, fileExtension: "tiff")
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation
        else {
            return nil
        }

        return Self.pngData(fromTIFF: tiffData)
            .map { ClipboardImageData(data: $0, fileExtension: "png") }
            ?? ClipboardImageData(data: tiffData, fileExtension: "tiff")
    }

    private static func pngData(fromTIFF data: Data) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: data) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

struct ClipboardRecorder {
    var reader: ClipboardReading
    var imageStoreDirectory: URL

    init(
        reader: ClipboardReading = SystemClipboardReader(),
        imageStoreDirectory: URL = ClipboardRecorder.defaultImageStoreDirectory()
    ) {
        self.reader = reader
        self.imageStoreDirectory = imageStoreDirectory
    }

    func capture(source: String = "Clipboard") -> ResourceItem? {
        let urls = reader.fileURLs().filter { $0.isFileURL }
        if !urls.isEmpty {
            return fileClipboardItem(urls: urls, source: source)
        }

        if let imageData = reader.imageData(),
           let item = imageClipboardItem(imageData, source: source) {
            return item
        }

        guard let text = reader.stringValue()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        let classification = ClipboardClassifier.classify(text)

        return ResourceItem(
            type: .clipboard,
            group: classification.group,
            title: classification.title,
            content: text,
            tags: classification.tags,
            source: source
        )
    }

    private func imageClipboardItem(_ image: ClipboardImageData, source: String) -> ResourceItem? {
        let fileExtension = sanitizedImageExtension(image.fileExtension)
        let fileURL = imageStoreDirectory
            .appendingPathComponent("clipboard-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)

        do {
            try FileManager.default.createDirectory(at: imageStoreDirectory, withIntermediateDirectories: true)
            try image.data.write(to: fileURL, options: [.atomic])
            return fileClipboardItem(urls: [fileURL], source: source)
        } catch {
            return nil
        }
    }

    func pruneStoredImages(retainedItems: [ResourceItem]) {
        let retainedPaths = Set(retainedItems.flatMap { item in
            ClipboardFileReference.fileURLs(for: item, existingOnly: false)
                .map(\.standardizedFileURL.path)
        })

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: imageStoreDirectory,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return
        }

        for file in files where file.isFileURL {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }

            let standardizedPath = file.standardizedFileURL.path
            guard standardizedPath.hasPrefix(imageStoreDirectory.standardizedFileURL.path),
                  !retainedPaths.contains(standardizedPath)
            else {
                continue
            }

            try? FileManager.default.removeItem(at: file)
        }
    }

    private func fileClipboardItem(urls: [URL], source: String) -> ResourceItem {
        let fileInfos = urls.map { FileClipboardInfo(url: $0) }
        let imageCount = fileInfos.filter(\.isImage).count
        let allImages = imageCount == fileInfos.count
        let title = title(for: fileInfos, allImages: allImages)
        let content = fileInfos.map(\.path).joined(separator: "\n")
        var tags = ["clipboard", "file", "file-url"]

        if allImages {
            tags.append("image")
        }

        for fileInfo in fileInfos {
            if !fileInfo.extensionTag.isEmpty {
                tags.append("ext:\(fileInfo.extensionTag)")
            }
        }

        return ResourceItem(
            type: .clipboard,
            group: allImages ? "Images" : "Files",
            title: title,
            content: content,
            tags: Array(Set(tags)).sorted(),
            source: source
        )
    }

    private func title(for files: [FileClipboardInfo], allImages: Bool) -> String {
        let prefix = allImages ? "Image" : "File"
        guard files.count > 1 else {
            return "\(prefix): \(files[0].displayName)"
        }

        return "\(prefix)s: \(files.count) items, \(files[0].displayName)"
    }

    private func sanitizedImageExtension(_ fileExtension: String) -> String {
        let value = fileExtension
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return FileClipboardInfo.imageExtensions.contains(value) ? value : "png"
    }

    private static func defaultImageStoreDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("DingDong/Clipboard Images", isDirectory: true)
    }
}

private struct FileClipboardInfo {
    var url: URL

    var path: String {
        url.path
    }

    var displayName: String {
        url.lastPathComponent.isEmpty ? path : url.lastPathComponent
    }

    var extensionTag: String {
        url.pathExtension.lowercased()
    }

    var isImage: Bool {
        Self.imageExtensions.contains(extensionTag)
    }

    static let imageExtensions: Set<String> = [
        "apng", "avif", "bmp", "gif", "heic", "heif", "ico", "jpeg", "jpg",
        "png", "psd", "raw", "svg", "tif", "tiff", "webp"
    ]
}
