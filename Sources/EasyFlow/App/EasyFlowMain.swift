import AppKit

@MainActor
final class EasyFlowAppDelegate: NSObject, NSApplicationDelegate {
  private var appShellCoordinator: AppShellCoordinator?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.accessory)
    ApplicationMenu.install()

    do {
      let database = try AppDatabase.production()
      let repository = WorkspaceRepository(database: database)
      let reminders = RemindersSyncCoordinator(
        repository: repository,
        adapter: EventKitRemindersAdapter()
      )
      let coordinator = AppShellCoordinator(
        repository: repository,
        remindersSync: reminders
      )
      appShellCoordinator = coordinator
      coordinator.start()
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = "EasyFlow could not open its local workspace."
      alert.runModal()
      NSApplication.shared.terminate(nil)
    }
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    Task { @MainActor in
      let saved = await appShellCoordinator?.prepareToTerminate() ?? true
      if !saved {
        let alert = NSAlert()
        alert.messageText = "Your Quick Note could not be saved."
        alert.informativeText = "EasyFlow will stay open so you can retry without losing the draft."
        alert.runModal()
      }
      sender.reply(toApplicationShouldTerminate: saved)
    }
    return .terminateLater
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
