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
        .library(name: "ICopyTranslation", targets: ["ICopyTranslation"]),
        .library(name: "ICopyStorage", targets: ["ICopyStorage"]),
        .library(name: "ICopyUIComponents", targets: ["ICopyUIComponents"]),
        .library(name: "ClipboardPanel", targets: ["ClipboardPanel"]),
        .library(name: "DesktopCard", targets: ["DesktopCard"])
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
            name: "ICopyTranslation",
            dependencies: ["ICopyCore"],
            path: "Packages/Translation/Sources/ICopyTranslation",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "ICopyTranslationTests",
            dependencies: ["ICopyTranslation"],
            path: "Packages/Translation/Tests/ICopyTranslationTests",
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
        .target(
            name: "DesktopCard",
            dependencies: ["ICopyCore", "ICopyClipboard", "ICopyTranslation", "ICopyStorage", "ICopyUIComponents", "ClipboardPanel"],
            path: "Features/DesktopCard/Sources/DesktopCard",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "DesktopCardTests",
            dependencies: ["DesktopCard"],
            path: "Features/DesktopCard/Tests/DesktopCardTests",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "iCopyApp",
            dependencies: ["ClipboardPanel", "DesktopCard", "ICopyTranslation"],
            path: "App/Sources/iCopyApp",
            exclude: ["README.md", "DesktopCard/README.md"]
        )
    ]
)
