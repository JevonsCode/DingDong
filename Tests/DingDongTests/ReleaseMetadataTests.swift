import Foundation
import Testing
@testable import DingDong

@Suite("Release metadata")
struct ReleaseMetadataTests {
    @Test func versionComparatorHandlesSemanticVersions() {
        #expect(VersionComparator.compare("0.1.0", "0.1.0") == .orderedSame)
        #expect(VersionComparator.compare("v0.1.1", "0.1.0") == .orderedDescending)
        #expect(VersionComparator.compare("0.1.0", "0.2.0") == .orderedAscending)
        #expect(VersionComparator.compare("1.0", "1.0.0") == .orderedSame)
    }

    @Test func releaseMetadataDecodesUpdateJson() throws {
        let data = """
        {
          "app": "DingDong",
          "latestVersion": "0.2.0",
          "latestBuild": "7",
          "publishedAt": "2026-07-01T00:00:00Z",
          "website": "https://jevonscode.github.io/DingDong/",
          "releasePage": "https://github.com/JevonsCode/DingDong/releases/latest",
          "downloads": {
            "appleSilicon": "https://example.com/DingDong-0.2.0-apple-silicon.zip",
            "intel": "https://example.com/DingDong-0.2.0-intel.zip"
          },
          "notes": ["Native MCP bridge", "Version checks"]
        }
        """.data(using: .utf8)!

        let metadata = try JSONDecoder().decode(ReleaseMetadata.self, from: data)
        let status = ReleaseStatus.currentOnly.resolved(metadata)

        #expect(metadata.latestVersion == "0.2.0")
        #expect(metadata.downloads.intel?.lastPathComponent == "DingDong-0.2.0-intel.zip")
        #expect(status.isLatest == false)
        #expect(status.websiteURL.absoluteString == "https://jevonscode.github.io/DingDong/")
    }
}
