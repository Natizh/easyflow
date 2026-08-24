enum PointerInputEvent {
  case mouseDown
  case mouseUp
}

enum PointerInputRouting {
  static func shouldForward(
    _ event: PointerInputEvent,
    hasCapturedDrag: Bool
  ) -> Bool {
    switch event {
    case .mouseDown, .mouseUp:
      !hasCapturedDrag
    }
  }
}
