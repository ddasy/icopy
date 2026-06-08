// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "icopy",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "icopy", targets: ["iCopyApp"]),
        .library(name: "ICopyCore", targets: ["ICopyCore"]),
        .library(name: "ICopyClipboard", targets: ["ICopyClipboard"]),
        .library(name: "ICopyStorage", targets: ["ICopyStorage"]),
        .library(name: "ICopyUIComponents", targets: ["ICopyUIComponents"]),
        .library(name: "ClipboardPanel", targets: ["ClipboardPanel"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ICopyCore",
            path: "Packages/Core/Sources/ICopyCore",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ICopyCoreTests",
            dependencies: ["ICopyCore"],
            path: "Packages/Core/Tests/ICopyCoreTests",
            exclude: ["README.md"]
        ),
        .target(
            name: "ICopyClipboard",
            dependencies: ["ICopyCore"],
            path: "Packages/Clipboard/Sources/ICopyClipboard",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ICopyClipboardTests",
            dependencies: ["ICopyClipboard"],
            path: "Packages/Clipboard/Tests/ICopyClipboardTests",
            exclude: ["README.md"]
        ),
        .target(
            name: "ICopyStorage",
            dependencies: ["ICopyCore"],
            path: "Packages/Storage/Sources/ICopyStorage",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ICopyStorageTests",
            dependencies: ["ICopyCore", "ICopyStorage"],
            path: "Packages/Storage/Tests/ICopyStorageTests",
            exclude: ["README.md"]
        ),
        .target(
            name: "ICopyUIComponents",
            dependencies: ["ICopyCore"],
            path: "Packages/UIComponents/Sources/ICopyUIComponents",
            exclude: ["README.md"]
        ),
        .target(
            name: "ClipboardPanel",
            dependencies: ["ICopyCore", "ICopyClipboard", "ICopyStorage", "ICopyUIComponents"],
            path: "Features/ClipboardPanel/Sources/ClipboardPanel",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "iCopyApp",
            dependencies: ["ClipboardPanel"],
            path: "App/Sources/iCopyApp",
            exclude: ["README.md"]
        )
    ]
)
