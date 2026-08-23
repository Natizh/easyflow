import Foundation
@preconcurrency import GRDB
import Testing

@testable import EasyFlow

@MainActor
final class FakeRemindersAdapter: RemindersAdapter {
  var authorizationState: RemindersAccessState = .fullAccess
  var availableLists: [ReminderListSnapshot] = []
  var itemsByList: [String: [ReminderItemSnapshot]] = [:]
  var createListCount = 0
  var createReminderCount = 0
  var updateReminderCount = 0
  var deleteReminderCount = 0
  var failCreateCount = 0
  var failDeleteCount = 0
  var requestAccessCount = 0
  private var nextID = 1

  func requestFullAccess() async throws -> Bool {
    requestAccessCount += 1
    authorizationState = .fullAccess
    return true
  }

  func lists() throws -> [ReminderListSnapshot] { availableLists }

  func createList(named title: String) throws -> ReminderListSnapshot {
    createListCount += 1
    let list = ReminderListSnapshot(id: "created-list", title: title, isWritable: true)
    availableLists.append(list)
    itemsByList[list.id] = []
    return list
  }

  func reminders(inList identifier: String) async throws -> [ReminderItemSnapshot] {
    itemsByList[identifier] ?? []
  }

  func createReminder(
    inList identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    createReminderCount += 1
    if failCreateCount > 0 {
      failCreateCount -= 1
      throw CocoaError(.fileWriteUnknown)
    }
    let item = ReminderItemSnapshot(
      calendarItemIdentifier: "item-\(nextID)",
      externalIdentifier: "external-\(nextID)",
      title: title,
      isCompleted: isCompleted,
      lastModifiedAt: Date()
    )
    nextID += 1
    itemsByList[identifier, default: []].append(item)
    return item
  }

  func updateReminder(
    identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    updateReminderCount += 1
    for listID in Array(itemsByList.keys) {
      guard
        let index = itemsByList[listID]?.firstIndex(where: {
          $0.calendarItemIdentifier == identifier
        })
      else { continue }
      var item = itemsByList[listID]![index]
      item.title = title
      item.isCompleted = isCompleted
      item.lastModifiedAt = Date()
      itemsByList[listID]![index] = item
      return item
    }
    throw CocoaError(.fileNoSuchFile)
  }

  func deleteReminder(identifier: String) throws {
    deleteReminderCount += 1
    if failDeleteCount > 0 {
      failDeleteCount -= 1
      throw CocoaError(.fileWriteUnknown)
    }
    for listID in Array(itemsByList.keys) {
      itemsByList[listID]?.removeAll { $0.calendarItemIdentifier == identifier }
    }
  }

  func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

@Suite("Reminders list selection")
struct ReminderListSelectorTests {
  @Test("Persisted writable list wins")
  func persistedList() {
    let lists = [
      ReminderListSnapshot(id: "saved", title: "Renamed", isWritable: true),
      ReminderListSnapshot(id: "other", title: "EasyFlow", isWritable: true),
    ]
    #expect(
      ReminderListSelector.select(persistedIdentifier: "saved", lists: lists)
        == .use(lists[0])
    )
  }

  @Test("One exact writable EasyFlow list is reused and duplicates are ambiguous")
  func exactAndAmbiguous() {
    let exact = ReminderListSnapshot(id: "exact", title: "EasyFlow", isWritable: true)
    #expect(ReminderListSelector.select(persistedIdentifier: nil, lists: [exact]) == .use(exact))
    #expect(
      ReminderListSelector.select(persistedIdentifier: nil, lists: [exact, exact])
        == .ambiguous([exact, exact])
    )
    #expect(ReminderListSelector.select(persistedIdentifier: nil, lists: []) == .create)
  }
}

@Suite("Three-way Reminder reconciliation")
struct ReminderReconcilerTests {
  private let baseline = ReminderCore(title: "Baseline", isCompleted: false)
  private let timestamp = Date(timeIntervalSince1970: 100)

  @Test("One-sided and equal changes resolve without conflict")
  func oneSidedChanges() {
    #expect(
      ReminderReconciler.decide(
        local: ReminderCore(title: "Local", isCompleted: false),
        baseline: baseline,
        external: baseline,
        localChangedAt: timestamp,
        externalChangedAt: timestamp
      )
        == .apply(
          ReminderCore(title: "Local", isCompleted: false),
          pushExternal: true,
          pullLocal: false
        )
    )
    #expect(
      ReminderReconciler.decide(
        local: baseline,
        baseline: baseline,
        external: ReminderCore(title: "External", isCompleted: true),
        localChangedAt: timestamp,
        externalChangedAt: timestamp.addingTimeInterval(1)
      )
        == .apply(
          ReminderCore(title: "External", isCompleted: true),
          pushExternal: false,
          pullLocal: true
        )
    )
  }

  @Test("Conflicting changes use reliable timestamps or preserve conflict")
  func conflictResolution() {
    let local = ReminderCore(title: "Local", isCompleted: false)
    let external = ReminderCore(title: "External", isCompleted: false)
    #expect(
      ReminderReconciler.decide(
        local: local,
        baseline: baseline,
        external: external,
        localChangedAt: timestamp.addingTimeInterval(2),
        externalChangedAt: timestamp
      ) == .apply(local, pushExternal: true, pullLocal: false)
    )
    #expect(
      ReminderReconciler.decide(
        local: local,
        baseline: baseline,
        external: external,
        localChangedAt: timestamp,
        externalChangedAt: nil
      ) == .conflict
    )
  }
}

@Suite("Reminders synchronization")
@MainActor
struct RemindersSyncCoordinatorTests {
  @Test("Authorization requests once and denied or revoked access preserves local data")
  func authorizationLifecycle() async throws {
    let repository = try makeRepository()
    _ = try await repository.createMainTask(title: "Local survives", effort: .one)
    let adapter = configuredAdapter()
    adapter.authorizationState = .notDetermined
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.start()
    try await connected(coordinator)
    #expect(adapter.requestAccessCount == 1)

    adapter.authorizationState = .denied
    coordinator.synchronize()
    try await eventually { coordinator.status == .denied }
    #expect(try await repository.snapshot().activeTasks.count == 1)
    coordinator.stop()
  }

  @Test("Existing exact EasyFlow list is selected without duplicate creation")
  func existingListReuse() async throws {
    let repository = try makeRepository()
    let adapter = FakeRemindersAdapter()
    adapter.availableLists = [
      ReminderListSnapshot(id: "real-list", title: "EasyFlow", isWritable: true)
    ]
    adapter.itemsByList["real-list"] = []
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)

    #expect(adapter.createListCount == 0)
    #expect(try await repository.storedReminderListIdentifier() == "real-list")
  }

  @Test("Existing local active and completed tasks create distinct Reminders")
  func initialLocalExport() async throws {
    let repository = try makeRepository()
    let active = try await repository.createMainTask(title: "Active", effort: .one)
    let completed = try await repository.createMainTask(title: "Completed", effort: .two)
    try await repository.completeMainTask(id: completed.id)
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)

    #expect(adapter.createReminderCount == 2)
    #expect(Set(adapter.itemsByList["real-list"]!.map(\.title)) == ["Active", "Completed"])
    #expect(
      try await repository.syncTaskStates().allSatisfy {
        $0.sync?.calendarItemIdentifier != nil
      })
    _ = active
  }

  @Test("External Reminder imports unrated and same titles never auto-merge")
  func externalImport() async throws {
    let repository = try makeRepository()
    _ = try await repository.createMainTask(title: "Same", effort: .four)
    let adapter = configuredAdapter()
    adapter.itemsByList["real-list"] = [
      ReminderItemSnapshot(
        calendarItemIdentifier: "external-item",
        externalIdentifier: "external-stable",
        title: "Same",
        isCompleted: false,
        lastModifiedAt: Date()
      )
    ]
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)

    let tasks = try await repository.syncTaskStates()
    #expect(tasks.count == 2)
    #expect(tasks.contains { $0.sync?.origin == .reminders && $0.task.effort == nil })
    #expect(tasks.contains { $0.sync?.origin == .local && $0.task.effort == .four })
  }

  @Test("Assigning imported effort persists locally without pending synchronization")
  func importedEffortAssignment() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("effort.sqlite").path
    let repository = WorkspaceRepository(database: try AppDatabase(path: path))
    let imported = try await repository.importReminder(
      title: "Unrated",
      isCompleted: false,
      calendarItemIdentifier: "unrated-id",
      externalIdentifier: "external-unrated",
      externalModifiedAt: Date()
    )
    #expect(imported.effort == nil)
    try await repository.updateMainTask(id: imported.id, effort: .four)
    let state = try #require(try await repository.syncTaskStates().first)
    #expect(state.task.effort == .four)
    #expect(state.sync?.pendingMutation == nil)

    let reopened = WorkspaceRepository(database: try AppDatabase(path: path))
    let reopenedState = try #require(try await reopened.syncTaskStates().first)
    #expect(reopenedState.task.effort == .four)
    #expect(reopenedState.sync?.calendarItemIdentifier == "unrated-id")
  }

  @Test("External rename and completion preserve local-only metadata")
  func externalUpdatePreservesLocalData() async throws {
    let repository = try makeRepository()
    let task = try await repository.createMainTask(title: "Original", effort: .three)
    try await repository.updateMainTask(id: task.id, description: "Keep description")
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)

    adapter.itemsByList["real-list"]![0].title = "External rename"
    adapter.itemsByList["real-list"]![0].isCompleted = true
    adapter.itemsByList["real-list"]![0].lastModifiedAt = Date().addingTimeInterval(5)
    coordinator.synchronize()
    try await connected(coordinator)

    let state = try #require(try await repository.syncTaskStates().first)
    #expect(state.task.title == "External rename")
    #expect(state.task.completedAt != nil)
    #expect(state.task.effort == .three)
    #expect(state.task.taskDescription == "Keep description")
  }

  @Test("Local rename, completion, and delete propagate without duplicate creation")
  func localMutationFlow() async throws {
    let repository = try makeRepository()
    let task = try await repository.createMainTask(title: "Initial", effort: .two)
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.createReminderCount == 1)

    try await repository.updateMainTask(id: task.id, title: "Renamed")
    try await repository.completeMainTask(id: task.id)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]?.first?.title == "Renamed")
    #expect(adapter.itemsByList["real-list"]?.first?.isCompleted == true)

    adapter.itemsByList["real-list"]?[0].isCompleted = false
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]?.first?.isCompleted == true)
    #expect(try await repository.snapshot().recentlyCompleted.map(\.id) == [task.id])

    try await repository.softDeleteMainTask(id: task.id)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]?.isEmpty == true)
    #expect(adapter.deleteReminderCount == 1)
    #expect(adapter.createReminderCount == 1)
  }

  @Test("Repeated reconciliation is idempotent")
  func repeatedReconciliation() async throws {
    let repository = try makeRepository()
    _ = try await repository.createMainTask(title: "Once", effort: .one)
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)
    coordinator.synchronize()
    try await connected(coordinator)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.createReminderCount == 1)
    #expect(adapter.itemsByList["real-list"]?.count == 1)
  }

  @Test("Create failure is durable and retry does not duplicate")
  func createRetry() async throws {
    let repository = try makeRepository()
    _ = try await repository.createMainTask(title: "Retry", effort: .one)
    let adapter = configuredAdapter()
    adapter.failCreateCount = 1
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]!.isEmpty)
    #expect(try await repository.syncTaskStates().first?.sync?.retryCount == 1)

    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]!.count == 1)
  }

  @Test("Purged task data leaves a minimal pending-delete retry tombstone")
  func purgedTaskDeleteRetry() async throws {
    let database = try AppDatabase(inMemoryNamed: UUID().uuidString)
    let repository = WorkspaceRepository(database: database)
    var tasks: [MainTask] = []
    for index in 0..<6 {
      tasks.append(
        try await repository.createMainTask(title: "Delete \(index)", effort: .one)
      )
    }
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(adapter.itemsByList["real-list"]?.count == 6)

    for task in tasks {
      try await repository.softDeleteMainTask(id: task.id)
    }
    #expect(try await repository.syncTaskStates().count == 5)
    #expect(try await repository.reminderDeletionTombstones().count == 1)

    adapter.failDeleteCount = 1
    coordinator.synchronize()
    try await connected(coordinator)
    let failedTombstone = try #require(
      try await repository.reminderDeletionTombstones().first
    )
    #expect(failedTombstone.retryCount == 1)
    #expect(adapter.itemsByList["real-list"]?.count == 1)

    coordinator.synchronize()
    try await connected(coordinator)
    #expect(try await repository.reminderDeletionTombstones().isEmpty)
    #expect(adapter.itemsByList["real-list"]?.isEmpty == true)
    #expect(try await repository.syncTaskStates().count == 5)
  }

  @Test("Missing external item requires two full reconciliations before soft delete")
  func conservativeExternalDeletion() async throws {
    let repository = try makeRepository()
    _ = try await repository.createMainTask(title: "Delete later", effort: .two)
    let adapter = configuredAdapter()
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await connected(coordinator)
    adapter.itemsByList["real-list"] = []

    coordinator.synchronize()
    try await connected(coordinator)
    #expect(try await repository.snapshot().activeTasks.count == 1)
    coordinator.synchronize()
    try await connected(coordinator)
    #expect(try await repository.snapshot().activeTasks.isEmpty)
  }

  @Test("Duplicate lists surface ambiguity without mutation")
  func duplicateLists() async throws {
    let repository = try makeRepository()
    let adapter = FakeRemindersAdapter()
    adapter.availableLists = [
      ReminderListSnapshot(id: "one", title: "EasyFlow", isWritable: true),
      ReminderListSnapshot(id: "two", title: "EasyFlow", isWritable: true),
    ]
    let coordinator = RemindersSyncCoordinator(repository: repository, adapter: adapter)
    coordinator.synchronize()
    try await eventually { coordinator.status == .ambiguousList }
    #expect(adapter.createListCount == 0)
  }

  private func configuredAdapter() -> FakeRemindersAdapter {
    let adapter = FakeRemindersAdapter()
    adapter.availableLists = [
      ReminderListSnapshot(id: "real-list", title: "EasyFlow", isWritable: true)
    ]
    adapter.itemsByList["real-list"] = []
    return adapter
  }

  private func makeRepository() throws -> WorkspaceRepository {
    WorkspaceRepository(database: try AppDatabase(inMemoryNamed: UUID().uuidString))
  }

  private func connected(_ coordinator: RemindersSyncCoordinator) async throws {
    try await eventually { coordinator.status == .connected }
  }

  private func eventually(_ condition: @escaping () async throws -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
      if try await condition() { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition did not become true")
  }
}

@Suite("Reminders migration")
struct RemindersMigrationTests {
  @Test("v1 fixture migrates without data loss and allows unrated imports")
  func v1ToCurrent() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("migration.sqlite").path
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    let queue = try DatabaseQueue(path: path, configuration: configuration)
    try AppDatabase.migrator.migrate(queue, upTo: "v1-local-workspace")
    let id = UUID()
    try await queue.write { database in
      try database.execute(
        sql: """
          INSERT INTO mainTask
          (id, title, effort, sortIndex, taskDescription, isUnderlined, createdAt, updatedAt)
          VALUES (?, ?, ?, 0, ?, 0, ?, ?)
          """,
        arguments: [id, "Existing", 3, "Preserve", Date(), Date()]
      )
    }

    let repository = WorkspaceRepository(database: try AppDatabase(path: path))
    #expect(try await repository.snapshot().activeTasks.first?.effort == .three)
    _ = try await repository.importReminder(
      title: "Imported",
      isCompleted: false,
      calendarItemIdentifier: "imported-id",
      externalIdentifier: nil,
      externalModifiedAt: nil
    )
    let tasks = try await repository.syncTaskStates()
    #expect(tasks.count == 2)
    #expect(tasks.contains { $0.task.effort == nil })
    #expect(tasks.first(where: { $0.task.id == id })?.task.taskDescription == "Preserve")
  }

  @Test("v2 fixture enforces deleted-task retention during migration")
  func v2DeletedTaskRetentionMigration() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("migration.sqlite").path
    let taskIDs = (1...7).map {
      UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))!
    }
    let purgedStepID = UUID()
    let purgedAttachedNoteID = UUID()
    let inboxNoteID = UUID()

    do {
      var configuration = Configuration()
      configuration.foreignKeysEnabled = true
      let queue = try DatabaseQueue(path: path, configuration: configuration)
      try AppDatabase.migrator.migrate(queue, upTo: "v2-reminders-sync")
      try await queue.write { database in
        for (index, id) in taskIDs.enumerated() {
          let timestamp = Date(timeIntervalSince1970: TimeInterval(index))
          try database.execute(
            sql: """
              INSERT INTO mainTask (
                id, reminderIdentifier, title, effort, sortIndex, taskDescription,
                isUnderlined, createdAt, updatedAt, deletedAt
              ) VALUES (?, ?, ?, 1, ?, ?, 0, ?, ?, ?)
              """,
            arguments: [
              id, index == 0 ? "pending-delete" : nil, "Deleted \(index)", index,
              "Local context", timestamp, timestamp, timestamp,
            ]
          )
        }
        try database.execute(
          sql: """
            INSERT INTO reminderSync (
              taskID, calendarItemIdentifier, origin, baselineTitle,
              baselineCompleted, localCoreUpdatedAt, pendingMutation,
              retryCount, lastErrorCode
            ) VALUES (?, ?, 'local', ?, 0, ?, 'delete', 2, 'delete')
            """,
          arguments: [
            taskIDs[0], "pending-delete", "Deleted 0", Date(timeIntervalSince1970: 0),
          ]
        )
        var step = TaskStep(
          id: purgedStepID,
          mainTaskID: taskIDs[0],
          title: "Owned",
          sortIndex: 0,
          isCompleted: false,
          notes: "",
          textColor: nil,
          highlightColor: nil,
          isUnderlined: false,
          createdAt: Date(timeIntervalSince1970: 0),
          updatedAt: Date(timeIntervalSince1970: 0),
          deletedAt: nil
        )
        try step.insert(database)
        var attached = WorkspaceNote(
          id: purgedAttachedNoteID,
          title: nil,
          body: "Owned",
          mainTaskID: taskIDs[0],
          sourceDraftRevision: nil,
          sortIndex: 0,
          createdAt: Date(timeIntervalSince1970: 0),
          updatedAt: Date(timeIntervalSince1970: 0),
          deletedAt: nil
        )
        try attached.insert(database)
        var inbox = WorkspaceNote(
          id: inboxNoteID,
          title: nil,
          body: "Independent",
          mainTaskID: nil,
          sourceDraftRevision: nil,
          sortIndex: 0,
          createdAt: Date(timeIntervalSince1970: 0),
          updatedAt: Date(timeIntervalSince1970: 0),
          deletedAt: nil
        )
        try inbox.insert(database)
      }
    }

    let database = try AppDatabase(path: path)
    let result = try await database.queue.read { db in
      (
        try UUID.fetchAll(
          db,
          sql: "SELECT id FROM mainTask WHERE deletedAt IS NOT NULL ORDER BY deletedAt, id"
        ),
        try TaskStep.fetchOne(db, key: purgedStepID),
        try WorkspaceNote.fetchOne(db, key: purgedAttachedNoteID),
        try WorkspaceNote.fetchOne(db, key: inboxNoteID),
        try ReminderDeletionTombstone.fetchAll(db)
      )
    }
    #expect(result.0 == Array(taskIDs.suffix(5)))
    #expect(result.1 == nil)
    #expect(result.2 == nil)
    #expect(result.3?.body == "Independent")
    #expect(result.4.count == 1)
    #expect(result.4.first?.taskID == taskIDs[0])
    #expect(result.4.first?.retryCount == 2)
  }
}
