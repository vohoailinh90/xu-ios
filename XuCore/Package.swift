// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XuCore",
    defaultLocalization: "vi",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "XuCore", targets: ["XuCore"])
    ],
    targets: [
        .target(name: "XuCore"),
        .testTarget(name: "XuCoreTests", dependencies: ["XuCore"])
    ]
)
