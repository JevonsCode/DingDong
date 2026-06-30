import Foundation

enum ClipboardSmartFilter: String, CaseIterable, Equatable, Hashable {
    case all
    case url
    case command
    case code
    case json
    case path
    case image
    case file
    case email
    case sensitive

    var tagQuery: String? {
        switch self {
        case .all:
            nil
        case .url:
            "url"
        case .command:
            "command"
        case .code:
            "code"
        case .json:
            "json"
        case .path:
            "path"
        case .image:
            "image"
        case .file:
            "file"
        case .email:
            "email"
        case .sensitive:
            "sensitive"
        }
    }

    var icon: String {
        switch self {
        case .all:
            "tray.full"
        case .url:
            "link"
        case .command:
            "terminal"
        case .code:
            "chevron.left.forwardslash.chevron.right"
        case .json:
            "curlybraces"
        case .path:
            "folder"
        case .image:
            "photo"
        case .file:
            "doc"
        case .email:
            "envelope"
        case .sensitive:
            "lock.shield"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            language.text(.all)
        case .url:
            "URL"
        case .command:
            language.text(.command)
        case .code:
            language.text(.code)
        case .json:
            "JSON"
        case .path:
            language.text(.path)
        case .image:
            language == .chinese ? "图片" : "Images"
        case .file:
            language == .chinese ? "文件" : "Files"
        case .email:
            language.text(.email)
        case .sensitive:
            language.text(.sensitive)
        }
    }
}
