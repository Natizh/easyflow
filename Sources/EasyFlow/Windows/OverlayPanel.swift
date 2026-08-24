import AppKit

final class OverlayPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
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
    animationBehavior = .utilityWindow
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    hidesOnDeactivate = false
    isMovable = false
    isMovableByWindowBackground = false
    isReleasedWhenClosed = false
    becomesKeyOnlyIfNeeded = false
    acceptsMouseMovedEvents = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
  }
}
