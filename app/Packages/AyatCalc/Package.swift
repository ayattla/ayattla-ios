// swift-tools-version:5.9
// AyatCalc — prayer times, qibla, hijri and zakat, ported 1:1 from ayattla.com.
// STATUS: written on Linux without a Swift toolchain; NOT compiled yet. Build and run
// `swift test` on the Mac before relying on it.
import PackageDescription

let package = Package(
    name: "AyatCalc",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AyatCalc", targets: ["AyatCalc"])],
    targets: [
        .target(name: "AyatCalc"),
        .testTarget(name: "AyatCalcTests", dependencies: ["AyatCalc"], resources: [.copy("Golden")])
    ]
)
