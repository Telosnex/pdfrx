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
            url: "https://github.com/Telosnex/pdfrx/releases/download/pdfium-xcframework-chromium-8165/PDFium-chromium-8165-20261118-165113.xcframework.zip",
            checksum: "6bf02db00ba01835df5071f782e0cbe1af25a5c19630bb789a1db1c385e920f1"
        ),
    ]
)
