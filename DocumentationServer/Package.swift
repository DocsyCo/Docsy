// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DocumentationServer",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .executable(name: "CLI", targets: ["CLI"]),
        .library(name: "DocumentationServer", targets: ["DocumentationServer"]),
        .library(name: "DocumentationServerClient", targets: ["DocumentationServerClient"])
    ],
    dependencies: [
        .package(path: "../Modules/DocumentationKit"),
        
        // Server
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
//        .package(url: "https://github.com/vapor/postgres-kit.git", from: "2.13.5"),
//        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.0.55")
        
        // Client
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "CLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "DocumentationKit", package: "DocumentationKit"),
                .byName(name: "DocumentationServer"),
                .byName(name: "DocumentationServerClient"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "DocumentationServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "DocumentationKit", package: "DocumentationKit"),
//                .product(name: "PostgresKit", package: "postgres-kit"),
//                .product(name: "AWSS3", package: "aws-sdk-swift")
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(
            name: "DocumentationServerClient",
            dependencies: [
                .product(name: "DocumentationKit", package: "DocumentationKit"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .testTarget(
            name: "DocumentationServerTests",
            dependencies: [
                .byName(name: "DocumentationServer"),
                .byName(name: "DocumentationServerClient"),
                .product(name: "HummingbirdTesting", package: "hummingbird")
            ],
            path: "Tests/DocumentationServerTests"
        )
    ]
)
