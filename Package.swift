// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Publishable",
    products: [
        .library(name: "Publishable", targets: ["Publishable"]),
    ],
    targets: [
        .target(name: "Publishable", dependencies: []),
        .testTarget(name: "PublishableTests", dependencies: ["Publishable"]),
    ]
)
