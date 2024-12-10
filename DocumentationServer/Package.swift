// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocumentationServer",
    platforms: [.macOS(.v15)],
    products: [
//        .executable(name: "App", targets: ["App"]),
        .library(name: "DocumentationServer", targets: ["DocumentationServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
//        .package(url: "https://github.com/vapor/postgres-kit.git", from: "2.13.5"),
        .package(path: "../Modules/DocumentationKit"),
//        .package(
//            url: "https://github.com/awslabs/aws-sdk-swift",
//            from: "1.0.55"
//        )
    ],
    targets: [
//        .executableTarget(
//            name: "App",
//            dependencies: [
//                .product(name: "ArgumentParser", package: "swift-argument-parser"),
//                .product(name: "Hummingbird", package: "hummingbird"),
////                .product(name: "PostgresKit", package: "postgres-kit"),
//                .product(name: "DocumentationKit", package: "DocumentationKit"),
////                .product(name: "AWSS3", package: "aws-sdk-swift"),
//                "DocumentationServer"
//            ],
//            path: "Sources/App",
//            swiftSettings: [
//                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
//            ]
//        ),
        .target(
            name: "DocumentationServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "DocumentationKit", package: "DocumentationKit"),
//                .product(name: "PostgresKit", package: "postgres-kit"),
//                .product(name: "DocumentationKit", package: "DocumentationKit"),
//                .product(name: "AWSS3", package: "aws-sdk-swift")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
//        .testTarget(
//            name: "AppTests",
//            dependencies: [
//                .byName(name: "App"),
//                .product(name: "HummingbirdTesting", package: "hummingbird")
//            ],
//            path: "Tests/AppTests"
//        )
    ]
)
