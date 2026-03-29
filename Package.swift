// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TamaNotchi",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TamaNotchi", targets: ["TamaNotchi"])
    ],
    targets: [
        .executableTarget(
            name: "TamaNotchi",
            path: "TamaNotchi",
            exclude: ["Info.plist", "TamaNotchi.entitlements"],
            resources: [.process("BundleResources")]
        )
    ]
)
