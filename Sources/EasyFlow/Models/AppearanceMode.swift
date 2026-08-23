import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
  case standard
  case frosted
  case liquidGlass

  var id: String { rawValue }

  var label: String {
    switch self {
    case .standard: "Standard"
    case .frosted: "Frosted"
    case .liquidGlass: "Liquid Glass"
    }
  }

  static var available: [AppearanceMode] {
    var modes: [AppearanceMode] = [.standard, .frosted]
    #if compiler(>=6.2)
      if #available(macOS 26, *) { modes.append(.liquidGlass) }
    #endif
    return modes
  }
}

enum EasyFlowBrand {
  static let indigo = Color(red: 0.30, green: 0.27, blue: 0.76)
  static let lavender = Color(red: 0.68, green: 0.62, blue: 0.93)
}
