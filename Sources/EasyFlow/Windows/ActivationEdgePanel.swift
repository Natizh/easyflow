import AppKit

final class ActivationEdgePanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true
    )

    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle,
    ]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    ignoresMouseEvents = false
    acceptsMouseMovedEvents = true
  }
}
