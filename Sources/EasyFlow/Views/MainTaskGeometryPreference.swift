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

struct QuickNotesGeometryPreferenceKey: PreferenceKey {
  static let defaultValue: CGRect? = nil

  static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
    if let next = nextValue() { value = next }
  }
}

struct QuickNoteRowGeometryPreferenceKey: PreferenceKey {
  static let defaultValue: [UUID: MainTaskRowGeometry] = [:]

  static func reduce(
    value: inout [UUID: MainTaskRowGeometry],
    nextValue: () -> [UUID: MainTaskRowGeometry]
  ) {
    value.merge(nextValue()) { _, next in next }
  }
}

enum SecondaryPanelCoordinateSpace {
  static let name = "EasyFlow.SecondaryPanel"
}

struct StepRowGeometryPreferenceKey: PreferenceKey {
  static let defaultValue: [UUID: MainTaskRowGeometry] = [:]

  static func reduce(
    value: inout [UUID: MainTaskRowGeometry],
    nextValue: () -> [UUID: MainTaskRowGeometry]
  ) {
    value.merge(nextValue()) { _, next in next }
  }
}

struct StepExclusionGeometryPreferenceKey: PreferenceKey {
  static let defaultValue: [UUID: [CGRect]] = [:]

  static func reduce(
    value: inout [UUID: [CGRect]],
    nextValue: () -> [UUID: [CGRect]]
  ) {
    for (id, frames) in nextValue() {
      value[id, default: []].append(contentsOf: frames)
    }
  }
}
