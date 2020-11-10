// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "TUSKit",
    products: [
        .library(name: "TUSKit", targets: ["TUSKit"]),
    ],
    targets: [
        .target(name: "TUSKit", path: "TUSKit"),
    ]
)
