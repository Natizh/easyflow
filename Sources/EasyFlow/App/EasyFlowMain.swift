import AppKit

@MainActor
final class EasyFlowAppDelegate: NSObject, NSApplicationDelegate {
  private var appShellCoordinator: AppShellCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)

    do {
      let database = try AppDatabase.production()
      let repository = WorkspaceRepository(database: database)
      let coordinator = AppShellCoordinator(repository: repository)
      appShellCoordinator = coordinator
      coordinator.start()
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = "EasyFlow could not open its local workspace."
      alert.runModal()
      NSApplication.shared.terminate(nil)
    }
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
