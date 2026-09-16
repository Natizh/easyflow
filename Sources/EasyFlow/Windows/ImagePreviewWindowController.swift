import AppKit

@MainActor
final class ImagePreviewWindowController: NSWindowController, NSWindowDelegate {
  var onClose: (() -> Void)?

  init() {
    let panel = AuxiliaryPanel(title: "Image Preview", resizable: true)
    super.init(window: panel)
    panel.delegate = self
  }

  required init?(coder: NSCoder) { fatalError("Not implemented") }

  func present(image: NSImage, pixels: CGSize, on screen: NSScreen) {
    guard let window else { return }
    let view = NSImageView()
    view.image = image
    view.imageScaling = .scaleProportionallyUpOrDown
    view.imageAlignment = .alignCenter
    view.setAccessibilityLabel("Note image preview")
    window.contentView = view
    let size = AuxiliaryWindowLayout.imageSize(pixels, in: screen.visibleFrame)
    let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: size)).size
    window.setFrame(AuxiliaryWindowLayout.centered(size: frameSize, in: screen.visibleFrame), display: true)
    NSApp.activate(ignoringOtherApps: true)
    window.orderFrontRegardless()
    window.makeKey()
  }

  func windowWillClose(_ notification: Notification) { onClose?() }
}
