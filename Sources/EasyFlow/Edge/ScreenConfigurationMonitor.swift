import AppKit

@MainActor
final class ScreenConfigurationMonitor: NSObject {
  var onScreenConfigurationChanged: (() -> Void)?

  private var isRunning = false

  func start() {
    guard !isRunning else { return }
    isRunning = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenConfigurationDidChange),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    NotificationCenter.default.removeObserver(self)
  }

  @objc
  private func screenConfigurationDidChange() {
    onScreenConfigurationChanged?()
  }
}
