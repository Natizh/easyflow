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
    panel.contentView = NSHostingView(
      rootView: SettingsView(
        dismiss: { [weak panel] in panel?.close() },
        model: model,
        preferredHeightChanged: { [weak panel] height in
          guard let panel else { return }
          resizeSettingsPanel(panel, contentHeight: height, animate: panel.isVisible)
        }
      )
    )
    resizeSettingsPanel(
      panel,
      contentHeight: SettingsWindowMetrics.contentHeight(
        remindersEnabled: model.reminderSettings.isEnabled,
        showsCustomFrequency: model.reminderSettings.frequency.isCustom,
        showsCustomPause: false,
        showsPausedStatus: model.reminderSettings.isPaused(at: Date())
      ),
      animate: false
    )
  }

  required init?(coder: NSCoder) { fatalError("Not implemented") }

  func present(on screen: NSScreen) {
    model.refreshLaunchAtLoginStatus()
    guard let window else { return }
    window.setFrame(
      AuxiliaryWindowLayout.centered(size: window.frame.size, in: screen.visibleFrame),
      display: true
    )
    NSApp.activate(ignoringOtherApps: true)
    window.orderFrontRegardless()
    window.makeKey()
  }

  func windowWillClose(_ notification: Notification) { onClose?() }
}

@MainActor
private func resizeSettingsPanel(
  _ panel: NSPanel,
  contentHeight: CGFloat,
  animate: Bool
) {
  let oldFrame = panel.frame
  let newSize = panel.frameRect(
    forContentRect: CGRect(
      x: 0,
      y: 0,
      width: SettingsWindowMetrics.contentWidth,
      height: contentHeight
    )
  ).size
  let newFrame: CGRect
  if let visibleFrame = panel.screen?.visibleFrame {
    newFrame = AuxiliaryWindowLayout.centered(size: newSize, in: visibleFrame)
  } else if oldFrame.width > 0, oldFrame.height > 0 {
    var centeredFrame = CGRect(origin: oldFrame.origin, size: newSize)
    centeredFrame.origin.x = oldFrame.midX - newSize.width / 2
    centeredFrame.origin.y = oldFrame.midY - newSize.height / 2
    newFrame = centeredFrame
  } else {
    newFrame = CGRect(origin: oldFrame.origin, size: newSize)
  }
  panel.setFrame(newFrame, display: true, animate: animate)
}
