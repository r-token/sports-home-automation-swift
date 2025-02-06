// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sports-home-automation-swift",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Utils", targets: ["Utils"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-cloud/swift-cloud.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events", branch: "main"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", branch: "main"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Models",
            dependencies: []
        ),
        .target(
            name: "Utils",
            dependencies: [
                .product(name: "AWSSSM", package: "aws-sdk-swift"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime")
            ]
        ),
        .executableTarget(
            name: "Infra",
            dependencies: [
                .product(name: "Cloud", package: "swift-cloud")
            ]
        ),
        .executableTarget(
            name: "HueTokenRefresher",
            dependencies: [
                "Utils",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSSM", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .executableTarget(
            name: "Scheduler",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSQS", package: "aws-sdk-swift"),
                .product(name: "CloudSDK", package: "swift-cloud")
            ]
        ),
        .executableTarget(
            name: "Poller",
            dependencies: [
                "Models",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSDynamoDB", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "CloudSDK", package: "swift-cloud")
            ]
        ),
        .executableTarget(
            name: "ScoreProcessor",
            dependencies: [
                "Models",
                "Utils",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSSM", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        )
    ]
)
