// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacSteamLinkKeyboardHelper",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "MacSteamLinkKeyboardHelper", targets: ["MacSteamLinkKeyboardHelper"])
    ],
    targets: [
        .executableTarget(
            name: "MacSteamLinkKeyboardHelper",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
