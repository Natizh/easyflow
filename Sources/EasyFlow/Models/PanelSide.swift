import Foundation

enum PanelSide: String, CaseIterable, Identifiable, Sendable {
  case left, right
  var id: Self { self }
  var label: String { self == .left ? "Left" : "Right" }
  var outwardSign: CGFloat { self == .right ? 1 : -1 }
}
