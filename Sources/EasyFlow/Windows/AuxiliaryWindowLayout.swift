import AppKit

enum AuxiliaryWindowLayout {
  static func centered(size: CGSize, in visibleFrame: CGRect) -> CGRect {
    let width = min(size.width, max(1, visibleFrame.width - 32))
    let height = min(size.height, max(1, visibleFrame.height - 32))
    return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.midY - height / 2,
      width: width, height: height)
  }

  static func imageSize(_ pixels: CGSize, in frame: CGRect) -> CGSize {
    let scale = min(1, min(frame.width * 0.85 / max(1, pixels.width),
      frame.height * 0.85 / max(1, pixels.height)))
    return CGSize(width: max(180, pixels.width * scale), height: max(120, pixels.height * scale))
  }
}

final class AuxiliaryPanel: NSPanel {
  private var keyMonitor: Any?

  override var canBecomeKey: Bool { true }
  override func cancelOperation(_ sender: Any?) { close() }

  override func sendEvent(_ event: NSEvent) {
    if shouldClose(from: event) {
      close()
      return
    }
    super.sendEvent(event)
  }

  init(title: String, resizable: Bool = false) {
    var style: NSWindow.StyleMask = [.titled, .closable]
    if resizable { style.insert(.resizable) }
    super.init(contentRect: .zero, styleMask: style, backing: .buffered, defer: true)
    self.title = title
    isReleasedWhenClosed = false
    hidesOnDeactivate = false
    level = .statusBar
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    standardWindowButton(.zoomButton)?.isHidden = true
    titlebarAppearsTransparent = true
    backgroundColor = .windowBackgroundColor
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.isVisible, self.shouldClose(from: event) else { return event }
      self.close()
      return nil
    }
  }

  private func shouldClose(from event: NSEvent) -> Bool {
    guard event.type == .keyDown else { return false }
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    return event.keyCode == 53 || (modifiers.contains(.command) && event.keyCode == 13)
  }
}
