import AppKit

@MainActor
final class ScreenConfigurationMonitor: NSObject {
  var onScreenConfigurationChanged: (() -> Void)?
  var onActiveSpaceChanged: (() -> Void)?

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
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(activeSpaceDidChange),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: NSWorkspace.shared
    )
  }

  func stop() {
    guard isRunning else { return }
    isRunning = false
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  @objc
  private func screenConfigurationDidChange() {
    onScreenConfigurationChanged?()
  }

  @objc
  private func activeSpaceDidChange() {
    onActiveSpaceChanged?()
  }
}
