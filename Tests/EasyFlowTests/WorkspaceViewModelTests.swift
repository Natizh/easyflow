import Foundation
import Testing

@testable import EasyFlow

@Suite("Local workspace view model")
@MainActor
struct WorkspaceViewModelTests {
  @Test("Quick Note explicit commit clears composer and persists once")
  func quickNoteCommit() async throws {
    let repository = WorkspaceRepository(
      database: try AppDatabase(inMemoryNamed: UUID().uuidString)
    )
    let model = AppShellViewModel(repository: repository)
    model.start()
    model.setQuickNoteDraft("Captured thought")
    model.commitQuickNoteIfNeeded()

    try await eventually {
      model.snapshot.quickNotes.count == 1 && model.snapshot.draft == nil
    }
    #expect(model.quickNoteDraft.isEmpty)
    #expect(model.snapshot.quickNotes.first?.body == "Captured thought")
    model.stop()
  }

  @Test("Settings presentation emits dismiss-state changes")
  func settingsDismissState() async throws {
    let repository = WorkspaceRepository(
      database: try AppDatabase(inMemoryNamed: UUID().uuidString)
    )
    let model = AppShellViewModel(repository: repository)
    var states: [Bool] = []
    model.onSettingsPresentationChanged = { states.append($0) }

    model.isSettingsPresented = true
    model.isSettingsPresented = false
    #expect(states == [true, false])
  }

  @Test("Main Task composer has no hidden effort default")
  func taskRequiresExplicitEffort() async throws {
    let repository = WorkspaceRepository(
      database: try AppDatabase(inMemoryNamed: UUID().uuidString)
    )
    let model = AppShellViewModel(repository: repository)
    model.newTaskTitle = "Explicit effort"
    #expect(model.newTaskEffort == nil)
    model.createMainTask()
    try await Task.sleep(for: .milliseconds(30))
    #expect(try await repository.snapshot().activeTasks.isEmpty)

    model.newTaskEffort = .two
    model.createMainTask()
    try await eventually {
      try await repository.snapshot().activeTasks.count == 1
    }
  }

  private func eventually(
    timeout: Duration = .seconds(1),
    condition: @escaping () async throws -> Bool
  ) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while clock.now < deadline {
      if try await condition() { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition did not become true before timeout")
  }
}
