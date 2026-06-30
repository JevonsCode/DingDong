// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "DingDong",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DingDong", targets: ["DingDong"]),
        .executable(name: "dingdong-mcp", targets: ["DingDongMCP"])
    ],
    targets: [
        .target(
            name: "DingDongMCPCore"
        ),
        .executableTarget(
            name: "DingDongMCP",
            dependencies: ["DingDongMCPCore"]
        ),
        .executableTarget(
            name: "DingDong"
        ),
        .testTarget(
            name: "DingDongTests",
            dependencies: ["DingDong"]
        ),
        .testTarget(
            name: "DingDongMCPTests",
            dependencies: ["DingDongMCPCore"]
        )
    ]
)
