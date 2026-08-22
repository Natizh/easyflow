// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "EasyFlow",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "EasyFlow", targets: ["EasyFlow"])
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1")
  ],
  targets: [
    .executableTarget(
      name: "EasyFlow",
      dependencies: [
        .product(name: "GRDB", package: "GRDB.swift")
      ]
    ),
    .testTarget(
      name: "EasyFlowTests",
      dependencies: ["EasyFlow"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
