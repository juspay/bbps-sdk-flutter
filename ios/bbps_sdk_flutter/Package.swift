// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "bbps_sdk_flutter",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(name: "bbps-sdk-flutter", targets: ["bbps_sdk_flutter"])
    ],
    dependencies: [
        .package(url: "https://github.com/juspay/bbps-ios.git", from: "0.0.5")
    ],
    targets: [
        .target(
            name: "bbps_sdk_flutter",
            dependencies: [
                .product(name: "BBPSSDK", package: "bbps-ios")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
