// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AgentLinker",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AgentLinker",
            targets: ["AgentLinker"]
        ),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AgentLinker",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
