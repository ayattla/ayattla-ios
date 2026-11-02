// swift-tools-version:5.9
// AyatContent — read-only access to the offline content pack. STATUS: NOT compiled yet.
import PackageDescription

let package = Package(
    name: "AyatContent",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AyatContent", targets: ["AyatContent"])],
    targets: [
        .target(name: "AyatContent"),
        .testTarget(name: "AyatContentTests", dependencies: ["AyatContent"], resources: [.copy("Fixtures")])
    ]
)
