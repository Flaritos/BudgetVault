// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BudgetVaultShared",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "BudgetVaultShared", targets: ["BudgetVaultShared"])
    ],
    dependencies: [],
    targets: [
        .target(name: "BudgetVaultShared"),
        .testTarget(name: "BudgetVaultSharedTests", dependencies: ["BudgetVaultShared"])
    ]
)
