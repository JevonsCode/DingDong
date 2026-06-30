import Foundation

enum ClipboardFileReference {
    static func fileURLs(for item: ResourceItem, existingOnly: Bool = true) -> [URL] {
        guard item.type == .clipboard,
              item.tags.contains("file-url")
        else {
            return []
        }

        let urls = item.contentURLCandidates()

        guard existingOnly else {
            return urls
        }

        return urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func imageURL(for item: ResourceItem) -> URL? {
        return fileURLs(for: item).first { imageExtensions.contains($0.pathExtension.lowercased()) }
    }

    private static let imageExtensions: Set<String> = [
        "apng", "avif", "bmp", "gif", "heic", "heif", "ico", "jpeg", "jpg",
        "png", "psd", "raw", "svg", "tif", "tiff", "webp"
    ]
}

private extension ResourceItem {
    func contentURLCandidates() -> [URL] {
        var seen: Set<String> = []
        let rawValues = content
            .split(whereSeparator: \.isNewline)
            .flatMap { rawLine -> [String] in
                let line = String(rawLine)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !line.isEmpty else {
                    return []
                }

                return [line] + line.split(separator: " ").map { String($0) }
            }
            .map { rawValue in
                rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`<>()[]{}，,;"))
            }
            .filter { !$0.isEmpty }

        return rawValues
            .compactMap { value in
                if let url = URL(string: value), url.isFileURL {
                    return url.standardizedFileURL
                }

                if value.hasPrefix("/") || value.hasPrefix("~") {
                    return URL(fileURLWithPath: (value as NSString).expandingTildeInPath).standardizedFileURL
                }

                return nil
            }
            .filter { url in
                let key = url.path
                guard !seen.contains(key) else {
                    return false
                }

                seen.insert(key)
                return true
            }
    }
}
