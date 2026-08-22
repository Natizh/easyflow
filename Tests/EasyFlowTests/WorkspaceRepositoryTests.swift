import Foundation
@preconcurrency import GRDB
import Testing

@testable import EasyFlow

@Suite("Local workspace persistence")
struct WorkspaceRepositoryTests {
  @Test("Migration creates the complete v1 schema and effort constraint")
  func migrationAndEffortConstraint() throws {
    let database = try AppDatabase(inMemoryNamed: #function)
    let tables = try database.queue.read { database in
      try String.fetchAll(
        database,
        sql: "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
      )
    }

    #expect(tables.contains(MainTask.databaseTableName))
    #expect(tables.contains(TaskStep.databaseTableName))
    #expect(tables.contains(WorkspaceNote.databaseTableName))
    #expect(tables.contains(QuickNoteDraft.databaseTableName))
    #expect(tables.contains("appSetting"))
    #expect(Effort(rawValue: 0) == nil)
    #expect(Effort(rawValue: 5) == nil)
  }

  @Test("Database reopens with stable IDs and persisted relationships")
  func reopenPersistence() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("workspace.sqlite").path
    let taskID = UUID()
    let stepID = UUID()

    do {
      let repository = WorkspaceRepository(database: try AppDatabase(path: path))
      _ = try await repository.createMainTask(
        title: "Persistent task",
        effort: .three,
        id: taskID
      )
      _ = try await repository.createStep(
        mainTaskID: taskID,
        title: "Persistent step",
        id: stepID
      )
      let revision = UUID()
      _ = try await repository.commitDraft(body: "Persistent note", revision: revision)
    }

    let reopened = WorkspaceRepository(database: try AppDatabase(path: path))
    let snapshot = try await reopened.snapshot()
    #expect(snapshot.activeTasks.map(\.id) == [taskID])
    #expect(snapshot.stepsByTask[taskID]?.map(\.id) == [stepID])
    #expect(snapshot.quickNotes.count == 1)
  }

  @Test("Main Task CRUD, deterministic reorder, completion, and soft delete")
  func mainTaskLifecycle() async throws {
    let repository = try makeRepository()
    let first = try await repository.createMainTask(title: "First", effort: .one)
    let second = try await repository.createMainTask(title: "Second", effort: .four)

    try await repository.updateMainTask(
      id: first.id,
      title: "Updated",
      description: "Execution context",
      style: ItemStyle(textColor: .blue, highlightColor: .yellow, isUnderlined: true)
    )
    try await repository.reorderMainTasks(ids: [second.id, first.id])
    var snapshot = try await repository.snapshot()
    #expect(snapshot.activeTasks.map(\.id) == [second.id, first.id])
    #expect(snapshot.activeTasks[1].title == "Updated")
    #expect(snapshot.activeTasks[1].taskDescription == "Execution context")
    #expect(snapshot.activeTasks[1].style.isUnderlined)

    try await repository.completeMainTask(id: second.id)
    snapshot = try await repository.snapshot()
    #expect(snapshot.activeTasks.map(\.id) == [first.id])
    #expect(snapshot.recentlyCompleted.map(\.id) == [second.id])

    try await repository.softDeleteMainTask(id: first.id)
    snapshot = try await repository.snapshot()
    #expect(snapshot.activeTasks.isEmpty)
  }

  @Test("Invalid reorder rolls back without corrupting order")
  func reorderRollback() async throws {
    let repository = try makeRepository()
    let first = try await repository.createMainTask(title: "First", effort: .one)
    let second = try await repository.createMainTask(title: "Second", effort: .two)

    await #expect(throws: WorkspaceError.invalidOrder) {
      try await repository.reorderMainTasks(ids: [first.id, UUID()])
    }
    let snapshot = try await repository.snapshot()
    #expect(snapshot.activeTasks.map(\.id) == [first.id, second.id])
    #expect(snapshot.activeTasks.map(\.sortIndex) == [0, 1])
  }

  @Test("Steps support CRUD, reorder, notes, style, and in-place completion")
  func stepLifecycle() async throws {
    let repository = try makeRepository()
    let task = try await repository.createMainTask(title: "Task", effort: .two)
    let first = try await repository.createStep(mainTaskID: task.id, title: "First")
    let second = try await repository.createStep(mainTaskID: task.id, title: "Second")

    try await repository.updateStep(
      id: first.id,
      notes: "How to do it",
      isCompleted: true,
      style: ItemStyle(textColor: .green, highlightColor: nil, isUnderlined: true)
    )
    try await repository.reorderSteps(mainTaskID: task.id, ids: [second.id, first.id])
    var snapshot = try await repository.snapshot()
    let steps = try #require(snapshot.stepsByTask[task.id])
    #expect(steps.map(\.id) == [second.id, first.id])
    #expect(steps[1].isCompleted)
    #expect(steps[1].sortIndex == 1)
    #expect(steps[1].notes == "How to do it")

    try await repository.softDeleteStep(id: second.id)
    snapshot = try await repository.snapshot()
    #expect(snapshot.stepsByTask[task.id]?.map(\.id) == [first.id])
  }

  @Test("Draft commit is data-safe, idempotent, and generates presentation title")
  func draftCommit() async throws {
    let repository = try makeRepository()
    let revision = UUID()
    try await repository.saveDraft(body: "  meaningful note body survives  ", revision: revision)
    let first = try #require(
      try await repository.commitDraft(
        body: "  meaningful note body survives  ",
        revision: revision
      )
    )
    let duplicate = try #require(
      try await repository.commitDraft(
        body: "  meaningful note body survives  ",
        revision: revision
      )
    )

    let snapshot = try await repository.snapshot()
    #expect(first.id == duplicate.id)
    #expect(snapshot.quickNotes.count == 1)
    #expect(snapshot.quickNotes[0].body == "  meaningful note body survives  ")
    #expect(snapshot.quickNotes[0].displayTitle == "meaningful note body survives")
    #expect(snapshot.draft == nil)
  }

  @Test("Quick Notes reorder and move transaction preserves identity and content")
  func noteReorderAndMove() async throws {
    let repository = try makeRepository()
    let first = try #require(
      try await repository.commitDraft(body: "First note", revision: UUID())
    )
    let second = try #require(
      try await repository.commitDraft(body: "Second note", revision: UUID())
    )
    try await repository.reorderQuickNotes(ids: [second.id, first.id])
    let task = try await repository.createMainTask(title: "Target", effort: .three)
    try await repository.moveQuickNote(id: first.id, to: task.id)

    let snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes.map(\.id) == [second.id])
    let attached = try #require(snapshot.attachedNotesByTask[task.id]?.first)
    #expect(attached.id == first.id)
    #expect(attached.body == first.body)
    #expect(abs(attached.createdAt.timeIntervalSince(first.createdAt)) < 0.001)
  }

  @Test("Failed note move rolls back and soft-deleted parents preserve local children")
  func noteMoveRollbackAndSoftDelete() async throws {
    let repository = try makeRepository()
    let note = try #require(
      try await repository.commitDraft(body: "Keep me", revision: UUID())
    )
    await #expect(throws: WorkspaceError.taskNotFound) {
      try await repository.moveQuickNote(id: note.id, to: UUID())
    }
    var snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes.map(\.id) == [note.id])

    let task = try await repository.createMainTask(title: "Task", effort: .one)
    let step = try await repository.createStep(mainTaskID: task.id, title: "Step")
    try await repository.moveQuickNote(id: note.id, to: task.id)
    try await repository.softDeleteMainTask(id: task.id)
    snapshot = try await repository.snapshot()
    #expect(snapshot.activeTasks.isEmpty)
    #expect(snapshot.stepsByTask[task.id]?.map(\.id) == [step.id])
    #expect(snapshot.attachedNotesByTask[task.id]?.map(\.id) == [note.id])
  }

  private func makeRepository() throws -> WorkspaceRepository {
    WorkspaceRepository(database: try AppDatabase(inMemoryNamed: UUID().uuidString))
  }
}
