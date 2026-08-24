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
    #expect(tables.contains(ReminderDeletionTombstone.databaseTableName))
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

  @Test("Derived note titles use the first three meaningful words without changing body")
  func derivedNoteTitles() {
    let cases = [
      ("alpha", "alpha"),
      ("alpha beta", "alpha beta"),
      ("alpha beta gamma", "alpha beta gamma"),
      ("alpha beta gamma delta", "alpha beta gamma"),
      (" \n alpha \n\t beta   gamma \n delta  ", "alpha beta gamma"),
    ]

    for (body, title) in cases {
      let note = makeNote(body: body)
      #expect(note.displayTitle == title)
      #expect(note.body == body)
    }
  }

  @Test("Note title edits preserve explicit versus derived semantics")
  func noteTitleSemantics() async throws {
    let repository = try makeRepository()
    let note = try #require(
      try await repository.commitDraft(body: "alpha beta gamma delta", revision: UUID())
    )
    #expect(note.displayTitle == "alpha beta gamma")

    try await repository.updateNoteBody(id: note.id, body: "new body words here")
    var snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes[0].title == nil)
    #expect(snapshot.quickNotes[0].displayTitle == "new body words")

    try await repository.updateNoteTitle(id: note.id, title: "Pinned title")
    try await repository.updateNoteBody(id: note.id, body: "body should not win")
    snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes[0].title == "Pinned title")
    #expect(snapshot.quickNotes[0].displayTitle == "Pinned title")

    try await repository.updateNoteTitle(id: note.id, title: "  ")
    snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes[0].title == nil)
    #expect(snapshot.quickNotes[0].displayTitle == "body should not")
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
    #expect(snapshot.quickNotes[0].displayTitle == "meaningful note body")
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

  @Test("Attached Note body edits persist after reload without changing note identity")
  func attachedNoteBodyEditPersistsAfterReload() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("workspace.sqlite").path

    let taskID: UUID
    let noteID: UUID
    do {
      let repository = WorkspaceRepository(database: try AppDatabase(path: path))
      let task = try await repository.createMainTask(title: "Target", effort: .two)
      let note = try #require(
        try await repository.commitDraft(body: "Original body", revision: UUID())
      )
      try await repository.moveQuickNote(id: note.id, to: task.id)
      try await repository.updateNoteBody(id: note.id, body: "Edited attached body")
      taskID = task.id
      noteID = note.id
    }

    let reopened = WorkspaceRepository(database: try AppDatabase(path: path))
    let snapshot = try await reopened.snapshot()
    let attached = try #require(snapshot.attachedNotesByTask[taskID]?.first)
    #expect(attached.id == noteID)
    #expect(attached.body == "Edited attached body")
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

  @Test("Recently Completed returns exactly the newest five without deleting history")
  func recentlyCompletedLimit() async throws {
    let database = try AppDatabase(inMemoryNamed: UUID().uuidString)
    let repository = WorkspaceRepository(database: database)
    #expect(try await repository.snapshot().recentlyCompleted.isEmpty)

    var tasks: [MainTask] = []
    for index in 0..<6 {
      let task = try await repository.createMainTask(
        title: "Completed \(index)",
        effort: .one
      )
      tasks.append(task)
      try await repository.completeMainTask(id: task.id)
    }
    let completedTasks = tasks
    try await database.queue.write { db in
      for (index, task) in completedTasks.enumerated() {
        let completedAt =
          index < 4
          ? Date(timeIntervalSince1970: TimeInterval(index))
          : Date(timeIntervalSince1970: 10)
        try db.execute(
          sql: "UPDATE mainTask SET completedAt = ? WHERE id = ?",
          arguments: [completedAt, task.id]
        )
      }
    }

    let snapshot = try await repository.snapshot()
    #expect(snapshot.recentlyCompleted.count == 5)
    let tiedNewest = tasks.suffix(2).map(\.id).sorted { $0.uuidString < $1.uuidString }
    #expect(Array(snapshot.recentlyCompleted.prefix(2).map(\.id)) == tiedNewest)
    #expect(snapshot.recentlyCompleted[2].id == tasks[3].id)
    #expect(snapshot.recentlyCompleted[4].id == tasks[1].id)
    let retainedCount = try await database.queue.read { db in
      try MainTask.filter(Column("completedAt") != nil).fetchCount(db)
    }
    #expect(retainedCount == 6)
  }

  @Test(
    "Recently Completed count is bounded only in presentation",
    arguments: [1, 3, 5, 6, 10]
  )
  func recentlyCompletedCounts(taskCount: Int) async throws {
    let database = try AppDatabase(inMemoryNamed: UUID().uuidString)
    let repository = WorkspaceRepository(database: database)
    for index in 0..<taskCount {
      let task = try await repository.createMainTask(
        title: "Task \(index)",
        effort: .two
      )
      try await repository.completeMainTask(id: task.id)
    }
    let snapshot = try await repository.snapshot()
    #expect(snapshot.recentlyCompleted.count == min(taskCount, 5))
    let retainedCount = try await database.queue.read { db in
      try MainTask.filter(Column("completedAt") != nil).fetchCount(db)
    }
    #expect(retainedCount == taskCount)
  }

  @Test("Deleted Main Tasks retain the newest five and purge owned data")
  func deletedMainTaskRetention() async throws {
    let database = try AppDatabase(inMemoryNamed: UUID().uuidString)
    let dates = TestDateSource()
    let repository = WorkspaceRepository(database: database, now: { dates.next() })
    let inboxNote = try #require(
      try await repository.commitDraft(body: "Unrelated inbox note", revision: UUID())
    )
    let activeTask = try await repository.createMainTask(title: "Active", effort: .one)
    let completedTask = try await repository.createMainTask(title: "Completed", effort: .two)
    try await repository.completeMainTask(id: completedTask.id)

    var deletedTasks: [MainTask] = []
    var ownedStepIDs: [UUID] = []
    var attachedNoteIDs: [UUID] = []
    for index in 0..<7 {
      let task = try await repository.createMainTask(
        title: "Deleted \(index)",
        effort: .three
      )
      deletedTasks.append(task)
      let step = try await repository.createStep(mainTaskID: task.id, title: "Owned step")
      ownedStepIDs.append(step.id)
      let note = try #require(
        try await repository.commitDraft(body: "Attached \(index)", revision: UUID())
      )
      attachedNoteIDs.append(note.id)
      try await repository.moveQuickNote(id: note.id, to: task.id)
      try await repository.softDeleteMainTask(id: task.id)

      let retainedCount = try await database.queue.read { db in
        try MainTask.filter(Column("deletedAt") != nil).fetchCount(db)
      }
      #expect(retainedCount == min(index + 1, 5))
    }

    let retainedDeletedIDs = try await database.queue.read { db in
      try UUID.fetchAll(
        db,
        sql: "SELECT id FROM mainTask WHERE deletedAt IS NOT NULL ORDER BY deletedAt, id"
      )
    }
    #expect(retainedDeletedIDs == deletedTasks.suffix(5).map(\.id))

    let purgedStepIDs = Array(ownedStepIDs.prefix(2))
    let purgedAttachedNoteIDs = Array(attachedNoteIDs.prefix(2))
    let dependentCounts = try await database.queue.read { db in
      (
        try TaskStep.filter(purgedStepIDs.contains(Column("id"))).fetchCount(db),
        try WorkspaceNote.filter(purgedAttachedNoteIDs.contains(Column("id"))).fetchCount(db)
      )
    }
    #expect(dependentCounts.0 == 0)
    #expect(dependentCounts.1 == 0)

    let snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes.map(\.id).contains(inboxNote.id))
    #expect(snapshot.activeTasks.map(\.id).contains(activeTask.id))
    #expect(snapshot.recentlyCompleted.map(\.id).contains(completedTask.id))
    let completedStillStored = try await database.queue.read { db in
      try MainTask.fetchOne(db, key: completedTask.id) != nil
    }
    #expect(completedStillStored)
  }

  @Test("Deleted Main Task FIFO uses UUID order when timestamps tie")
  func deletedMainTaskRetentionTieBreak() async throws {
    let database = try AppDatabase(inMemoryNamed: UUID().uuidString)
    let timestamp = Date(timeIntervalSince1970: 100)
    let repository = WorkspaceRepository(database: database, now: { timestamp })
    let ids = (1...6).map {
      UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!
    }

    for (index, id) in ids.enumerated() {
      _ = try await repository.createMainTask(
        title: "Tied \(index)",
        effort: .one,
        id: id
      )
      try await repository.softDeleteMainTask(id: id)
    }

    let retainedIDs = try await database.queue.read { db in
      try UUID.fetchAll(
        db,
        sql: "SELECT id FROM mainTask WHERE deletedAt IS NOT NULL ORDER BY id"
      )
    }
    #expect(retainedIDs == Array(ids.dropFirst()))
  }

  private func makeRepository() throws -> WorkspaceRepository {
    WorkspaceRepository(database: try AppDatabase(inMemoryNamed: UUID().uuidString))
  }

  private func makeNote(body: String, title: String? = nil) -> WorkspaceNote {
    WorkspaceNote(
      id: UUID(),
      title: title,
      body: body,
      mainTaskID: nil,
      sourceDraftRevision: nil,
      sortIndex: 0,
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0),
      deletedAt: nil
    )
  }
}

private final class TestDateSource: @unchecked Sendable {
  private let lock = NSLock()
  private var value = Date(timeIntervalSince1970: 1_000)

  func next() -> Date {
    lock.lock()
    defer { lock.unlock() }
    let result = value
    value = value.addingTimeInterval(1)
    return result
  }
}
