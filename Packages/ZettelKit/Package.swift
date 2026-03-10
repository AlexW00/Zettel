// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZettelKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "ZettelKit",
            targets: ["ZettelKit"]
        ),
    ],
    targets: [
        .target(
            name: "ZettelKit"
        ),
    ]
)
