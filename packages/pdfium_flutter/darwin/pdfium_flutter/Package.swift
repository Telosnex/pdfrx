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
            url: "https://github.com/Telosnex/pdfrx/releases/download/pdfium-xcframework-chromium-8152/PDFium-chromium-8152-20261110-180141.xcframework.zip",
            checksum: "e56fba3434c2da7aa582989d3d0910945dc1c21148fcf85b951ed341522ef25d"
        ),
    ]
)
