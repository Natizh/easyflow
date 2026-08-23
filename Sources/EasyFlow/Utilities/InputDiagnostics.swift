import Foundation

enum InputDiagnostics {
  #if DEBUG
    static let isEnabled = ProcessInfo.processInfo.environment["EASYFLOW_INPUT_DEBUG"] == "1"
  #else
    static let isEnabled = false
  #endif

  static func record(_ message: @autoclosure () -> String) {
    guard isEnabled else { return }
    fputs("[EasyFlowInput] \(message())\n", stderr)
  }
}
