// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QixKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "QixKit", targets: ["QixKit"]),
    ],
    targets: [
        .target(name: "QixKit"),
        .testTarget(name: "QixKitTests", dependencies: ["QixKit"]),
    ]
)
