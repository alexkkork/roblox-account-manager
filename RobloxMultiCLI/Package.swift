// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RobloxMultiCLI",
    platforms: [ .macOS(.v13) ],
    products: [
        .executable(name: "robloxmulti", targets: ["RobloxMultiCLI"])
    ],
    targets: [
        .executableTarget(name: "RobloxMultiCLI")
    ]
)


