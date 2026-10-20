// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Swoop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Swoop", targets: ["Swoop"]),
    ],
    targets: [
        // Pure logic: actions, geometry, radial math, cycles, settings, URL commands.
        // No AppKit, so it is fast to unit-test.
        .target(
            name: "SwoopCore",
            path: "Sources/SwoopCore"
        ),
        // The macOS app: Accessibility, trigger key, radial menu, preview, stash, settings UI.
        .executableTarget(
            name: "Swoop",
            dependencies: ["SwoopCore"],
            path: "Sources/Swoop",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "SwoopCoreTests",
            dependencies: ["SwoopCore"],
            path: "Tests/SwoopCoreTests"
        ),
    ]
)
