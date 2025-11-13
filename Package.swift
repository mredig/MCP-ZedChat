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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.2"),
		.package(url: "https://github.com/Lighter-swift/Lighter.git", from: "1.4.12"),
		.package(url: "https://github.com/mredig/SwiftPizzaSnips.git", from: "0.4.37"),
    ],
    targets: [
		.target(
			name: "MCPZedChatLib",
			dependencies: [
				.product(name: "Lighter", package: "Lighter"),
				"SwiftPizzaSnips",
				.product(name: "MCP", package: "swift-sdk"),
				.product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
				.product(name: "Logging", package: "swift-log"),
			],
			swiftSettings: [
				.enableUpcomingFeature("StrictConcurrency")
			]
		),
        .executableTarget(
            name: "MCPZedChat",
            dependencies: [
				"MCPZedChatLib",
//                .product(name: "MCP", package: "swift-sdk"),
//                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
//                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/MCPZedChat",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MCPZedChatTests",
            dependencies: [
				.targetItem(name: "MCPZedChatLib", condition: nil),
                .product(name: "MCP", package: "swift-sdk"),
            ],
            path: "Tests/MCPZedChatTests"
        ),
    ]
)
