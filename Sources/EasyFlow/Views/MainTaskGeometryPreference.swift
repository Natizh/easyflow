import SwiftUI

enum MainPanelCoordinateSpace {
  static let name = "EasyFlow.MainPanel"
}

struct MainTaskGeometryPreferenceKey: PreferenceKey {
  static let defaultValue: [UUID: MainTaskRowGeometry] = [:]

  static func reduce(
    value: inout [UUID: MainTaskRowGeometry],
    nextValue: () -> [UUID: MainTaskRowGeometry]
  ) {
    for (id, next) in nextValue() {
      var current =
        value[id]
        ?? MainTaskRowGeometry(taskID: id, rowFrame: .null, reorderFrame: .null)
      if !next.rowFrame.isNull { current.rowFrame = next.rowFrame }
      if !next.reorderFrame.isNull { current.reorderFrame = next.reorderFrame }
      value[id] = current
    }
  }
}
