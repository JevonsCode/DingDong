import Foundation

enum AppVersion {
    static let fallbackVersion = "0.1.0"
    static let fallbackBuild = "1"

    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? fallbackBuild
    }
}

struct ReleaseDownloads: Codable, Equatable, Sendable {
    var appleSilicon: URL?
    var intel: URL?
}

struct ReleaseMetadata: Codable, Equatable, Sendable {
    var app: String
    var latestVersion: String
    var latestBuild: String?
    var publishedAt: String?
    var website: URL
    var releasePage: URL
    var downloads: ReleaseDownloads
    var notes: [String]
}

struct ReleaseStatus: Equatable {
    var currentVersion: String
    var currentBuild: String
    var metadata: ReleaseMetadata?
    var isChecking: Bool
    var errorMessage: String?
    var checkedAt: Date?

    static var currentOnly: ReleaseStatus {
        ReleaseStatus(
            currentVersion: AppVersion.current,
            currentBuild: AppVersion.build,
            metadata: nil,
            isChecking: false,
            errorMessage: nil,
            checkedAt: nil
        )
    }

    var latestVersion: String? {
        metadata?.latestVersion
    }

    var websiteURL: URL {
        metadata?.website ?? ReleaseMetadataFetcher.defaultWebsiteURL
    }

    var releasePageURL: URL {
        metadata?.releasePage ?? ReleaseMetadataFetcher.defaultReleasePageURL
    }

    var isLatest: Bool? {
        guard let latestVersion else {
            return nil
        }

        return VersionComparator.compare(currentVersion, latestVersion) != .orderedAscending
    }

    func checking() -> ReleaseStatus {
        ReleaseStatus(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            metadata: metadata,
            isChecking: true,
            errorMessage: nil,
            checkedAt: checkedAt
        )
    }

    func resolved(_ metadata: ReleaseMetadata) -> ReleaseStatus {
        ReleaseStatus(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            metadata: metadata,
            isChecking: false,
            errorMessage: nil,
            checkedAt: Date()
        )
    }

    func failed(_ message: String) -> ReleaseStatus {
        ReleaseStatus(
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            metadata: metadata,
            isChecking: false,
            errorMessage: message,
            checkedAt: Date()
        )
    }
}

enum VersionComparator {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = normalizedParts(lhs)
        let rhsParts = normalizedParts(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let lhsValue = index < lhsParts.count ? lhsParts[index] : 0
            let rhsValue = index < rhsParts.count ? rhsParts[index] : 0

            if lhsValue < rhsValue {
                return .orderedAscending
            }

            if lhsValue > rhsValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func normalizedParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            .split(separator: ".")
            .map { part in
                let digits = part.prefix { $0.isNumber }
                return Int(digits) ?? 0
            }
    }
}

enum ReleaseMetadataFetcher {
    static let defaultMetadataURL = URL(string: "https://jevonscode.github.io/DingDong/dingdong-release.json")!
    static let defaultWebsiteURL = URL(string: "https://jevonscode.github.io/DingDong/")!
    static let defaultReleasePageURL = URL(string: "https://github.com/JevonsCode/DingDong/releases/latest")!

    @discardableResult
    static func fetch(
        from url: URL = defaultMetadataURL,
        completion: @escaping @Sendable (Result<ReleaseMetadata, Error>) -> Void
    ) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(ReleaseMetadataError.emptyResponse))
                return
            }

            do {
                let metadata = try JSONDecoder().decode(ReleaseMetadata.self, from: data)
                completion(.success(metadata))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
        return task
    }
}

enum ReleaseMetadataError: LocalizedError {
    case emptyResponse

    var errorDescription: String? {
        "Release metadata response was empty."
    }
}
