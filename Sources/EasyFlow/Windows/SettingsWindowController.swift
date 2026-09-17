import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
  var onClose: (() -> Void)?
  private let model: AppShellViewModel

  init(model: AppShellViewModel) {
    self.model = model
    let panel = AuxiliaryPanel(title: "EasyFlow Settings")
    super.init(window: panel)
    panel.delegate = self
    panel.contentView = NSHostingView(rootView: SettingsView(dismiss: { [weak panel] in panel?.close() }, model: model))
  }

  required init?(coder: NSCoder) { fatalError("Not implemented") }

  func present(on screen: NSScreen) {
    model.refreshLaunchAtLoginStatus()
    guard let window else { return }
    let size = window.frameRect(forContentRect: CGRect(x: 0, y: 0, width: 480, height: 460)).size
    window.setFrame(AuxiliaryWindowLayout.centered(size: size, in: screen.visibleFrame), display: true)
    NSApp.activate(ignoringOtherApps: true)
    window.orderFrontRegardless()
    window.makeKey()
  }

  func windowWillClose(_ notification: Notification) { onClose?() }
}
