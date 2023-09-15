// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Publishable",
    products: [
        .library(name: "Publishable", targets: ["Publishable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftarium/WeakRef", from: "1.0.0"),
    ],
    targets: [
        .target(name: "Publishable", dependencies: ["WeakRef"]),
        .testTarget(name: "PublishableTests", dependencies: ["Publishable"]),
    ]
)
