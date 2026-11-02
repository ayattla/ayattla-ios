// swift-tools-version:5.9
// AyatDesign — brand tokens, card style and Arabic-Indic number formatting shared by all screens
// (design/System.dc.html).
import PackageDescription

let package = Package(
    name: "AyatDesign",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AyatDesign", targets: ["AyatDesign"])],
    dependencies: [.package(path: "../AyatCalc")],
    targets: [
        .target(name: "AyatDesign", dependencies: ["AyatCalc"]),
        .testTarget(name: "AyatDesignTests", dependencies: ["AyatDesign"])
    ]
)
