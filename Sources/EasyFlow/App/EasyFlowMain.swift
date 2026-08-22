import AppKit

@MainActor
final class EasyFlowAppDelegate: NSObject, NSApplicationDelegate {
  private var appShellCoordinator: AppShellCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    let coordinator = AppShellCoordinator()
    appShellCoordinator = coordinator
    coordinator.start()
  }

  func applicationWillTerminate(_ notification: Notification) {
    appShellCoordinator?.stop()
    appShellCoordinator = nil
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}

@main
enum EasyFlowMain {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let delegate = EasyFlowAppDelegate()

    application.delegate = delegate
    application.setActivationPolicy(.accessory)

    withExtendedLifetime(delegate) {
      application.run()
    }
  }
}
