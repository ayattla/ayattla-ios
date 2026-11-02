// swift-tools-version:5.9
// AyatTiming — word-timing timeline, validation and lookup. STATUS: NOT compiled yet.
import PackageDescription

let package = Package(
    name: "AyatTiming",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AyatTiming", targets: ["AyatTiming"])],
    targets: [
        .target(name: "AyatTiming"),
        .testTarget(name: "AyatTimingTests", dependencies: ["AyatTiming"])
    ]
)
