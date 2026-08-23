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

  @Test("Routed Quick Note drag attaches the same note transactionally")
  func routedNoteAttachment() async throws {
    let repository = WorkspaceRepository(
      database: try AppDatabase(inMemoryNamed: UUID().uuidString)
    )
    let task = try await repository.createMainTask(title: "Target", effort: .one)
    let note = try #require(
      try await repository.commitDraft(body: "Move me", revision: UUID())
    )
    let model = AppShellViewModel(repository: repository)
    model.routedNoteDragCommitted(
      noteID: note.id,
      insertionIndex: nil,
      taskTargetID: task.id
    )
    try await eventually {
      let snapshot = try await repository.snapshot()
      return snapshot.quickNotes.isEmpty
        && snapshot.attachedNotesByTask[task.id]?.first?.id == note.id
    }
  }

  @Test("Routed Step drag commits one geometry-derived order")
  func routedStepReorder() async throws {
    let repository = WorkspaceRepository(
      database: try AppDatabase(inMemoryNamed: UUID().uuidString)
    )
    let task = try await repository.createMainTask(title: "Task", effort: .two)
    let first = try await repository.createStep(mainTaskID: task.id, title: "First")
    let second = try await repository.createStep(mainTaskID: task.id, title: "Second")
    let model = AppShellViewModel(repository: repository)
    model.start()
    try await eventually {
      model.snapshot.stepsByTask[task.id]?.count == 2
    }
    model.secondaryContext = .task(id: task.id)
    model.routedStepDragCommitted(stepID: first.id, insertionIndex: 2)
    try await eventually {
      try await repository.snapshot().stepsByTask[task.id]?.map(\.id)
        == [second.id, first.id]
    }
    model.stop()
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
