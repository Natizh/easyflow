import AppKit

enum EasyFlowOverlayWindowConfiguration {
  static let collectionBehavior: NSWindow.CollectionBehavior = [
    .canJoinAllSpaces,
    .fullScreenAuxiliary,
    .stationary,
    .ignoresCycle,
  ]

  @MainActor
  static func maskRoundedContent(_ view: NSView) {
    view.wantsLayer = true
    view.layer?.cornerRadius = 22
    view.layer?.cornerCurve = .continuous
    view.layer?.masksToBounds = true
  }
}

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
    collectionBehavior = EasyFlowOverlayWindowConfiguration.collectionBehavior
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
