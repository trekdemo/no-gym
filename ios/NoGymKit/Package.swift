// swift-tools-version: 6.0
// NoGymKit holds the app's rules: templates, timing and sound cues.
// It only uses Foundation, so `swift test` runs on any Mac or Linux machine.
import PackageDescription

let package = Package(
    name: "NoGymKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "NoGymKit", targets: ["NoGymKit"]),
    ],
    targets: [
        .target(name: "NoGymKit"),
        .testTarget(name: "NoGymKitTests", dependencies: ["NoGymKit"]),
    ]
)
