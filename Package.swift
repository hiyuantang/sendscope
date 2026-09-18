// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SendScope",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SendScope", targets: ["SendScope"])],
    targets: [
        .target(name: "SendScopeCore"),
        .executableTarget(name: "SendScope", dependencies: ["SendScopeCore"]),
        .testTarget(name: "SendScopeCoreTests", dependencies: ["SendScopeCore"])
    ],
    swiftLanguageModes: [.v5]
)
