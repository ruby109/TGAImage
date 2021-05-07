// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TGAImage",
    products: [
        .library(
            name: "TGAImage",
            targets: ["TGAImage"]),
    ],
    dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
            // other dependencies
        ],
    targets: [
        .target(
            name: "TGAImage",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .testTarget(
            name: "TGAImageTests",
            dependencies: ["TGAImage"],
            resources: [
                .copy("Resources")
            ])
    ]
)
