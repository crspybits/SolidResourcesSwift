// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SolidResourcesSwift",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "SolidResourcesSwift",
            targets: ["SolidResourcesSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/HeliumLogger", from: "1.9.200"),
        .package(url: "https://github.com/crspybits/SolidAuthSwift.git", from: "0.0.2"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "SolidResourcesSwift",
            dependencies: [
                "HeliumLogger",
                .product(name: "SolidAuthSwiftTools", package: "SolidAuthSwift"),
            ]),
        .testTarget(
            name: "SolidResourcesSwiftTests",
            dependencies: ["SolidResourcesSwift"]),
    ]
)
