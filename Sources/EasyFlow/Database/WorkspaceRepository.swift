import Foundation
@preconcurrency import GRDB

private final class ObservationTokenBox: @unchecked Sendable {
  var token: DatabaseCancellable?
}

actor WorkspaceRepository {
  private let database: AppDatabase
  private let now: @Sendable () -> Date

  init(
    database: AppDatabase,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.database = database
    self.now = now
  }

  func snapshot() throws -> WorkspaceSnapshot {
    try database.queue.read(Self.fetchSnapshot)
  }

  func observe() -> AsyncThrowingStream<WorkspaceSnapshot, Error> {
    let queue = database.queue
    return AsyncThrowingStream { continuation in
      let box = ObservationTokenBox()
      let observation = ValueObservation.tracking(Self.fetchSnapshot)
      box.token = observation.start(
        in: queue,
        scheduling: .async(onQueue: .main),
        onError: { error in continuation.finish(throwing: error) },
        onChange: { snapshot in continuation.yield(snapshot) }
      )
      continuation.onTermination = { _ in
        box.token?.cancel()
        box.token = nil
      }
    }
  }

  @discardableResult
  func createMainTask(
    title: String,
    effort: Effort,
    id: UUID = UUID()
  ) throws -> MainTask {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty else { throw WorkspaceError.emptyTitle }
    let timestamp = now()

    return try database.queue.write { database in
      let nextIndex = try Self.nextSortIndex(
        in: database,
        table: MainTask.databaseTableName,
        predicate: "deletedAt IS NULL AND completedAt IS NULL"
      )
      var task = MainTask(
        id: id,
        reminderIdentifier: nil,
        title: cleanTitle,
        effort: effort,
        sortIndex: nextIndex,
        taskDescription: "",
        textColor: nil,
        highlightColor: nil,
        isUnderlined: false,
        createdAt: timestamp,
        updatedAt: timestamp,
        completedAt: nil,
        deletedAt: nil
      )
      try task.insert(database)
      return task
    }
  }

  func updateMainTask(
    id: UUID,
    title: String? = nil,
    effort: Effort? = nil,
    description: String? = nil,
    style: ItemStyle? = nil
  ) throws {
    try database.queue.write { database in
      guard var task = try MainTask.fetchOne(database, key: id) else {
        throw WorkspaceError.taskNotFound
      }
      if let title {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw WorkspaceError.emptyTitle }
        task.title = cleanTitle
      }
      if let effort { task.effort = effort }
      if let description { task.taskDescription = description }
      if let style {
        task.textColor = style.textColor
        task.highlightColor = style.highlightColor
        task.isUnderlined = style.isUnderlined
      }
      task.updatedAt = now()
      try task.update(database)
    }
  }

  func completeMainTask(id: UUID) throws {
    try database.queue.write { database in
      guard var task = try MainTask.fetchOne(database, key: id) else {
        throw WorkspaceError.taskNotFound
      }
      let timestamp = now()
      task.completedAt = timestamp
      task.updatedAt = timestamp
      try task.update(database)
    }
  }

  func softDeleteMainTask(id: UUID) throws {
    try database.queue.write { database in
      guard var task = try MainTask.fetchOne(database, key: id) else {
        throw WorkspaceError.taskNotFound
      }
      let timestamp = now()
      task.deletedAt = timestamp
      task.updatedAt = timestamp
      try task.update(database)
    }
  }

  func reorderMainTasks(ids: [UUID]) throws {
    try database.queue.write { database in
      let current =
        try MainTask
        .filter(Column("deletedAt") == nil && Column("completedAt") == nil)
        .order(Column("sortIndex"), Column("id"))
        .fetchAll(database)
      try Self.validateOrder(current: current.map(\.id), requested: ids)
      try Self.applyOrder(
        ids,
        table: MainTask.databaseTableName,
        timestamp: now(),
        database: database
      )
    }
  }

  @discardableResult
  func createStep(
    mainTaskID: UUID,
    title: String,
    id: UUID = UUID()
  ) throws -> TaskStep {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanTitle.isEmpty else { throw WorkspaceError.emptyTitle }
    let timestamp = now()

    return try database.queue.write { database in
      guard try MainTask.fetchOne(database, key: mainTaskID) != nil else {
        throw WorkspaceError.taskNotFound
      }
      let nextIndex = try Self.nextSortIndex(
        in: database,
        table: TaskStep.databaseTableName,
        predicate: "mainTaskID = ? AND deletedAt IS NULL",
        arguments: [mainTaskID]
      )
      var step = TaskStep(
        id: id,
        mainTaskID: mainTaskID,
        title: cleanTitle,
        sortIndex: nextIndex,
        isCompleted: false,
        notes: "",
        textColor: nil,
        highlightColor: nil,
        isUnderlined: false,
        createdAt: timestamp,
        updatedAt: timestamp,
        deletedAt: nil
      )
      try step.insert(database)
      return step
    }
  }

  func updateStep(
    id: UUID,
    title: String? = nil,
    notes: String? = nil,
    isCompleted: Bool? = nil,
    style: ItemStyle? = nil
  ) throws {
    try database.queue.write { database in
      guard var step = try TaskStep.fetchOne(database, key: id) else {
        throw WorkspaceError.stepNotFound
      }
      if let title {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw WorkspaceError.emptyTitle }
        step.title = cleanTitle
      }
      if let notes { step.notes = notes }
      if let isCompleted { step.isCompleted = isCompleted }
      if let style {
        step.textColor = style.textColor
        step.highlightColor = style.highlightColor
        step.isUnderlined = style.isUnderlined
      }
      step.updatedAt = now()
      try step.update(database)
    }
  }

  func softDeleteStep(id: UUID) throws {
    try database.queue.write { database in
      guard var step = try TaskStep.fetchOne(database, key: id) else {
        throw WorkspaceError.stepNotFound
      }
      step.deletedAt = now()
      step.updatedAt = now()
      try step.update(database)
    }
  }

  func reorderSteps(mainTaskID: UUID, ids: [UUID]) throws {
    try database.queue.write { database in
      let current =
        try TaskStep
        .filter(Column("mainTaskID") == mainTaskID && Column("deletedAt") == nil)
        .order(Column("sortIndex"), Column("id"))
        .fetchAll(database)
      try Self.validateOrder(current: current.map(\.id), requested: ids)
      try Self.applyOrder(
        ids,
        table: TaskStep.databaseTableName,
        timestamp: now(),
        database: database
      )
    }
  }

  func saveDraft(body: String, revision: UUID) throws {
    try database.queue.write { database in
      if try WorkspaceNote
        .filter(Column("sourceDraftRevision") == revision)
        .fetchCount(database) > 0
      {
        return
      }

      var draft = QuickNoteDraft(
        revision: revision,
        body: body,
        updatedAt: now()
      )
      try draft.save(database)
    }
  }

  @discardableResult
  func commitDraft(body: String, revision: UUID) throws -> WorkspaceNote? {
    guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      try clearDraft()
      return nil
    }

    return try database.queue.write { database in
      if let existing =
        try WorkspaceNote
        .filter(Column("sourceDraftRevision") == revision)
        .fetchOne(database)
      {
        try QuickNoteDraft.deleteOne(database, key: QuickNoteDraft.singletonID)
        return existing
      }

      let timestamp = now()
      let nextIndex = try Self.nextSortIndex(
        in: database,
        table: WorkspaceNote.databaseTableName,
        predicate: "mainTaskID IS NULL AND deletedAt IS NULL"
      )
      var note = WorkspaceNote(
        id: UUID(),
        title: nil,
        body: body,
        mainTaskID: nil,
        sourceDraftRevision: revision,
        sortIndex: nextIndex,
        createdAt: timestamp,
        updatedAt: timestamp,
        deletedAt: nil
      )
      try note.insert(database)
      _ = try QuickNoteDraft.deleteOne(database, key: QuickNoteDraft.singletonID)
      return note
    }
  }

  func clearDraft() throws {
    try database.queue.write { database in
      _ = try QuickNoteDraft.deleteOne(database, key: QuickNoteDraft.singletonID)
    }
  }

  func updateNote(id: UUID, title: String?, body: String) throws {
    try database.queue.write { database in
      guard var note = try WorkspaceNote.fetchOne(database, key: id) else {
        throw WorkspaceError.noteNotFound
      }
      note.title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
      if note.title?.isEmpty == true { note.title = nil }
      note.body = body
      note.updatedAt = now()
      try note.update(database)
    }
  }

  func softDeleteNote(id: UUID) throws {
    try database.queue.write { database in
      guard var note = try WorkspaceNote.fetchOne(database, key: id) else {
        throw WorkspaceError.noteNotFound
      }
      note.deletedAt = now()
      note.updatedAt = now()
      try note.update(database)
    }
  }

  func reorderQuickNotes(ids: [UUID]) throws {
    try database.queue.write { database in
      let current =
        try WorkspaceNote
        .filter(Column("mainTaskID") == nil && Column("deletedAt") == nil)
        .order(Column("sortIndex"), Column("id"))
        .fetchAll(database)
      try Self.validateOrder(current: current.map(\.id), requested: ids)
      try Self.applyOrder(
        ids,
        table: WorkspaceNote.databaseTableName,
        timestamp: now(),
        database: database
      )
    }
  }

  func moveQuickNote(id: UUID, to mainTaskID: UUID) throws {
    try database.queue.write { database in
      guard var note = try WorkspaceNote.fetchOne(database, key: id),
        note.mainTaskID == nil,
        note.deletedAt == nil
      else {
        throw WorkspaceError.noteNotFound
      }
      guard let task = try MainTask.fetchOne(database, key: mainTaskID),
        task.deletedAt == nil
      else {
        throw WorkspaceError.taskNotFound
      }

      note.mainTaskID = mainTaskID
      note.sortIndex = try Self.nextSortIndex(
        in: database,
        table: WorkspaceNote.databaseTableName,
        predicate: "mainTaskID = ? AND deletedAt IS NULL",
        arguments: [mainTaskID]
      )
      note.updatedAt = now()
      try note.update(database)
    }
  }

  private static func fetchSnapshot(_ database: Database) throws -> WorkspaceSnapshot {
    let activeTasks =
      try MainTask
      .filter(Column("deletedAt") == nil && Column("completedAt") == nil)
      .order(Column("sortIndex"), Column("id"))
      .fetchAll(database)
    let recentlyCompleted =
      try MainTask
      .filter(Column("deletedAt") == nil && Column("completedAt") != nil)
      .order(Column("completedAt").desc, Column("id"))
      .limit(5)
      .fetchAll(database)
    let steps =
      try TaskStep
      .filter(Column("deletedAt") == nil)
      .order(Column("mainTaskID"), Column("sortIndex"), Column("id"))
      .fetchAll(database)
    let notes =
      try WorkspaceNote
      .filter(Column("deletedAt") == nil)
      .order(Column("mainTaskID"), Column("sortIndex"), Column("id"))
      .fetchAll(database)
    let draft = try QuickNoteDraft.fetchOne(
      database,
      key: QuickNoteDraft.singletonID
    )

    return WorkspaceSnapshot(
      quickNotes: notes.filter { $0.mainTaskID == nil },
      activeTasks: activeTasks,
      recentlyCompleted: recentlyCompleted,
      stepsByTask: Dictionary(grouping: steps, by: \.mainTaskID),
      attachedNotesByTask: Dictionary(
        grouping: notes.filter { $0.mainTaskID != nil },
        by: { $0.mainTaskID! }
      ),
      draft: draft
    )
  }

  private static func nextSortIndex(
    in database: Database,
    table: String,
    predicate: String,
    arguments: StatementArguments = []
  ) throws -> Int {
    let maximum = try Int.fetchOne(
      database,
      sql: "SELECT MAX(sortIndex) FROM \(table) WHERE \(predicate)",
      arguments: arguments
    )
    return (maximum ?? -1) + 1
  }

  private static func validateOrder(current: [UUID], requested: [UUID]) throws {
    guard current.count == requested.count,
      Set(current) == Set(requested),
      Set(requested).count == requested.count
    else {
      throw WorkspaceError.invalidOrder
    }
  }

  private static func applyOrder(
    _ ids: [UUID],
    table: String,
    timestamp: Date,
    database: Database
  ) throws {
    for (index, id) in ids.enumerated() {
      try database.execute(
        sql: "UPDATE \(table) SET sortIndex = ?, updatedAt = ? WHERE id = ?",
        arguments: [index, timestamp, id]
      )
    }
  }
}
