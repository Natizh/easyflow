import Foundation

enum AppVersion {
  static func label(bundle: Bundle = .main) -> String {
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    return build.map { "Version \(version) (\($0))" } ?? "Version \(version)"
  }
}
