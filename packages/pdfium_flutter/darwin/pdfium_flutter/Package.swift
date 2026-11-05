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
            url: "https://github.com/Telosnex/pdfrx/releases/download/pdfium-xcframework-chromium-8138/PDFium-chromium-8138-20261105-001403.xcframework.zip",
            checksum: "b0c1c67b00ece10b7aae09098b5d19b9638def824961910806a4efb0dfd814a8"
        ),
    ]
)
