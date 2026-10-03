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

enum PanelFocusPolicy {
  static func canFocus(isVisible: Bool, isOnActiveSpace: Bool, isClosing: Bool) -> Bool {
    isVisible && isOnActiveSpace && !isClosing
  }
}

final class OverlayPanel: NSPanel {
  var onDismiss: (() -> Void)?
  var onPointerInteraction: (() -> Void)?
  var onKeyboardInteraction: (() -> Void)?
  private(set) var isClosing = false

  var isAvailableForFocus: Bool {
    PanelFocusPolicy.canFocus(isVisible: isVisible, isOnActiveSpace: isOnActiveSpace, isClosing: isClosing)
  }

  func exposeForInteraction() {
    isClosing = false
    setAccessibilityHidden(false)
    contentView?.setAccessibilityHidden(false)
    recalculateKeyViewLoop()
  }

  func retireFromInteraction() {
    isClosing = true
    makeFirstResponder(nil)
    resignKey()
    setAccessibilityHidden(true)
    contentView?.setAccessibilityHidden(true)
  }

  override func cancelOperation(_ sender: Any?) { onDismiss?() }
  override func performClose(_ sender: Any?) { onDismiss?() }

  override func sendEvent(_ event: NSEvent) {
    if event.type == .keyDown { onKeyboardInteraction?() }
    if event.type == .leftMouseDown || event.type == .rightMouseDown { onPointerInteraction?() }
    super.sendEvent(event)
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: true
    )

    autorecalculatesKeyViewLoop = true
    setAccessibilityHidden(true)
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
