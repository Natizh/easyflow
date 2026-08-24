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

enum MainTaskDensity: String, CaseIterable, Identifiable, Sendable {
  case compact
  case comfortable

  var id: String { rawValue }

  var label: String {
    switch self {
    case .compact: "Compact"
    case .comfortable: "Comfortable"
    }
  }

  var taskRowSpacing: CGFloat {
    switch self {
    case .compact: 3
    case .comfortable: 8
    }
  }

  var taskRowVerticalPadding: CGFloat {
    switch self {
    case .compact: 8
    case .comfortable: 12
    }
  }
}

enum EasyFlowBrand {
  static let indigo = Color(red: 0.30, green: 0.27, blue: 0.76)
  static let lavender = Color(red: 0.68, green: 0.62, blue: 0.93)
}
