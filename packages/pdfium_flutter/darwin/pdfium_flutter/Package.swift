// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "pdfium_flutter",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "pdfium-flutter",
            targets: ["pdfium_flutter"]
        ),
    ],
    targets: [
        .target(
            name: "pdfium_flutter",
            dependencies: [
                .target(name: "PDFium"),
            ],
            path: "Sources/main"
        ),
        .binaryTarget(
            name: "PDFium",
            url: "https://github.com/Telosnex/pdfrx/releases/download/pdfium-xcframework-chromium-8179/PDFium-chromium-8179-20261124-165322.xcframework.zip",
            checksum: "414d344bafbafa25893019f518fba69e5b507b201759d1bf511c70babd2b5d5c"
        ),
    ]
)
