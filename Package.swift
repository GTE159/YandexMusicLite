// swift-tools-version: 6.0
import PackageDescription
import Foundation

// Автоматически подключаем плагин макросов Testing только если сборка идет через голый CLT
var testSwiftSettings: [SwiftSetting] = []
let cltPluginPath = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if FileManager.default.fileExists(atPath: cltPluginPath) &&
   (ProcessInfo.processInfo.environment["DEVELOPER_DIR"]?.contains("CommandLineTools") == true ||
    !FileManager.default.fileExists(atPath: "/Applications/Xcode.app")) {
    testSwiftSettings.append(
        .unsafeFlags([
            "-Xfrontend", "-load-resolved-plugin",
            "-Xfrontend", "\(cltPluginPath)##TestingMacros"
        ])
    )
}

let package = Package(
    name: "YandexMusicMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "YMCore", targets: ["YMCore"]),
        .executable(name: "YandexMusicMac", targets: ["YandexMusicMac"])
    ],
    targets: [
        .target(
            name: "YMCore",
            dependencies: []
        ),
        .executableTarget(
            name: "YandexMusicMac",
            dependencies: ["YMCore"]
        ),
        .testTarget(
            name: "YMCoreTests",
            dependencies: ["YMCore"],
            swiftSettings: testSwiftSettings
        )
    ]
)
