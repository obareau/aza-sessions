// swift-tools-version:5.10
// AZA — Journal de Sessions, app macOS native (SwiftUI).
// AZACore = modèle + stockage JSON + import sessions.db,
// AZA = l'app SwiftUI, aza-check = auto-test en ligne de commande.
import PackageDescription

let package = Package(
    name: "AZA",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AZA", targets: ["AZA"]),
        .executable(name: "aza-check", targets: ["aza-check"]),
        .library(name: "AZACore", targets: ["AZACore"]),
    ],
    targets: [
        .target(name: "AZACore", linkerSettings: [.linkedLibrary("sqlite3")]),
        .executableTarget(name: "AZA", dependencies: ["AZACore"]),
        .executableTarget(name: "aza-check", dependencies: ["AZACore"]),
    ]
)
