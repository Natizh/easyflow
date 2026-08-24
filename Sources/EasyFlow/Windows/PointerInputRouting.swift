import AppKit

enum PointerInputRouting {
  static func shouldCaptureReorder(
    isLeftMouseDown: Bool,
    isReorderCandidate: Bool,
    hitsInteractiveControl: Bool
  ) -> Bool {
    isLeftMouseDown && isReorderCandidate && !hitsInteractiveControl
  }
}
