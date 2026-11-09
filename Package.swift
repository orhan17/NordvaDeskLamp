// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "NordvaDeskLamp",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "NordvaDeskLampCore"),
        .executableTarget(name: "NordvaDeskLamp", dependencies: ["NordvaDeskLampCore"]),
        .testTarget(name: "NordvaDeskLampCoreTests", dependencies: ["NordvaDeskLampCore"]),
    ]
)
