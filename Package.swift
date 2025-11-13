// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MCP-ZedChat",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .executable(
            name: "mcp-zedchat",
            targets: ["MCPZedChat"]
        ),
    ],
    dependencies: [
        // MCP Swift SDK
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        // Swift Service Lifecycle for graceful shutdown
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.3.0"),
        // Swift Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "MCPZedChat",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/MCPZedChat",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MCPZedChatTests",
            dependencies: [
                "MCPZedChat",
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/MCPZedChatTests"
        ),
    ]
)