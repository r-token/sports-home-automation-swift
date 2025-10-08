// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sports-home-automation-swift",
	platforms: [.macOS(.v26)],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "Extensions", targets: ["Extensions"]),
        .library(name: "SharedUtils", targets: ["SharedUtils"]),
        .library(name: "SSMUtils", targets: ["SSMUtils"])
    ],
    dependencies: [
        .package(url: "https://github.com/swift-cloud/swift-cloud.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", branch: "main"),
        .package(url: "https://github.com/swift-server/swift-aws-lambda-events", branch: "main"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0"),
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Models",
            dependencies: []
        ),
        .target(
            name: "Extensions",
            dependencies: []
        ),
        .target(
            name: "SharedUtils",
            dependencies: ["Extensions"]
        ),
        .target(
            name: "SSMUtils",
            dependencies: [
                "Models",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSSSM", package: "aws-sdk-swift")
            ]
        ),
        .executableTarget(
            name: "Infra",
            dependencies: [
                .product(name: "Cloud", package: "swift-cloud")
            ]
        ),
        .executableTarget(
            name: "Scheduler",
            dependencies: [
                "SharedUtils",
                .product(name: "CloudSDK", package: "swift-cloud"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSQS", package: "aws-sdk-swift")
            ]
        ),
        .executableTarget(
            name: "Poller",
            dependencies: [
                "Models",
                "SharedUtils",
                .product(name: "CloudSDK", package: "swift-cloud"),
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSDynamoDB", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .executableTarget(
            name: "ScoreProcessor",
            dependencies: [
                "Models",
                "SSMUtils",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSSM", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        ),
        .executableTarget(
            name: "HueTokenRefresher",
            dependencies: [
                "SSMUtils",
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-events"),
                .product(name: "AWSSSM", package: "aws-sdk-swift"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        )
    ]
)

for target in package.targets {
	var settings = target.swiftSettings ?? []
	settings.append(.enableUpcomingFeature("StrictConcurrency"))
	target.swiftSettings = settings
}
