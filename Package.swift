// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GamepadMouse",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GamepadMouse",
            path: "Sources/GamepadMouse",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("GameController"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
