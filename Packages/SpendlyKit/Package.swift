// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpendlyKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        // macOS is only here so `swift test` runs on the Mac without a simulator.
        .macOS(.v15),
    ],
    products: [
        .library(name: "SpendlyCore", targets: ["SpendlyCore"]),
        .library(name: "SpendlyData", targets: ["SpendlyData"]),
        .library(name: "SpendlyUI", targets: ["SpendlyUI"]),
    ],
    targets: [
        // Pure value types: money, amount entry, currency rules. No SwiftUI, no SwiftData.
        .target(name: "SpendlyCore"),
        // Persistence: SwiftData models + the ExpenseStore protocol and its SwiftData implementation.
        .target(name: "SpendlyData", dependencies: ["SpendlyCore"]),
        // Design system shared by the app and (later) the widget extension.
        .target(name: "SpendlyUI", dependencies: ["SpendlyCore"]),

        .testTarget(name: "SpendlyCoreTests", dependencies: ["SpendlyCore"]),
        .testTarget(name: "SpendlyDataTests", dependencies: ["SpendlyData"]),
    ]
)
