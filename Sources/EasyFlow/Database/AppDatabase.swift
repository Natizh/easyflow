import Foundation
@preconcurrency import GRDB

final class AppDatabase: @unchecked Sendable {
  let queue: DatabaseQueue

  init(path: String) throws {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    configuration.busyMode = .timeout(5)
    queue = try DatabaseQueue(path: path, configuration: configuration)
    try Self.migrator.migrate(queue)
  }

  init(inMemoryNamed name: String = UUID().uuidString) throws {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = true
    queue = try DatabaseQueue(
      path: "file:\(name)?mode=memory&cache=shared",
      configuration: configuration
    )
    try Self.migrator.migrate(queue)
  }

  static func production() throws -> AppDatabase {
    let fileManager = FileManager.default
    let applicationSupport = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let directory = applicationSupport.appendingPathComponent(
      "EasyFlow",
      isDirectory: true
    )
    try fileManager.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return try AppDatabase(
      path: directory.appendingPathComponent("EasyFlow.sqlite").path
    )
  }

  static var migrator: DatabaseMigrator {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1-local-workspace") { database in
      try database.create(table: MainTask.databaseTableName) { table in
        table.column("id", .text).primaryKey()
        table.column("reminderIdentifier", .text).unique()
        table.column("title", .text).notNull()
        table.column("effort", .integer).notNull()
        table.column("sortIndex", .integer).notNull()
        table.column("taskDescription", .text).notNull().defaults(to: "")
        table.column("textColor", .text)
        table.column("highlightColor", .text)
        table.column("isUnderlined", .boolean).notNull().defaults(to: false)
        table.column("createdAt", .datetime).notNull()
        table.column("updatedAt", .datetime).notNull()
        table.column("completedAt", .datetime)
        table.column("deletedAt", .datetime)
        table.check(sql: "effort BETWEEN 1 AND 4")
      }

      try database.create(table: TaskStep.databaseTableName) { table in
        table.column("id", .text).primaryKey()
        table.column("mainTaskID", .text).notNull()
          .references(MainTask.databaseTableName, onDelete: .cascade)
        table.column("title", .text).notNull()
        table.column("sortIndex", .integer).notNull()
        table.column("isCompleted", .boolean).notNull().defaults(to: false)
        table.column("notes", .text).notNull().defaults(to: "")
        table.column("textColor", .text)
        table.column("highlightColor", .text)
        table.column("isUnderlined", .boolean).notNull().defaults(to: false)
        table.column("createdAt", .datetime).notNull()
        table.column("updatedAt", .datetime).notNull()
        table.column("deletedAt", .datetime)
      }

      try database.create(table: WorkspaceNote.databaseTableName) { table in
        table.column("id", .text).primaryKey()
        table.column("title", .text)
        table.column("body", .text).notNull()
        table.column("mainTaskID", .text)
          .references(MainTask.databaseTableName, onDelete: .cascade)
        table.column("sourceDraftRevision", .text).unique()
        table.column("sortIndex", .integer).notNull()
        table.column("createdAt", .datetime).notNull()
        table.column("updatedAt", .datetime).notNull()
        table.column("deletedAt", .datetime)
      }

      try database.create(table: QuickNoteDraft.databaseTableName) { table in
        table.column("id", .text).primaryKey()
        table.column("revision", .text).notNull()
        table.column("body", .text).notNull()
        table.column("updatedAt", .datetime).notNull()
      }

      try database.create(table: "appSetting") { table in
        table.column("key", .text).primaryKey()
        table.column("value", .text).notNull()
        table.column("updatedAt", .datetime).notNull()
      }

      try database.create(
        index: "mainTask_active_order",
        on: MainTask.databaseTableName,
        columns: ["deletedAt", "completedAt", "sortIndex"]
      )
      try database.create(
        index: "taskStep_parent_order",
        on: TaskStep.databaseTableName,
        columns: ["mainTaskID", "deletedAt", "sortIndex"]
      )
      try database.create(
        index: "workspaceNote_location_order",
        on: WorkspaceNote.databaseTableName,
        columns: ["mainTaskID", "deletedAt", "sortIndex"]
      )
    }
    migrator.registerMigration("v2-reminders-sync") { database in
      try database.create(table: "mainTask_v2") { table in
        table.column("id", .text).primaryKey()
        table.column("reminderIdentifier", .text).unique()
        table.column("title", .text).notNull()
        table.column("effort", .integer)
        table.column("sortIndex", .integer).notNull()
        table.column("taskDescription", .text).notNull().defaults(to: "")
        table.column("textColor", .text)
        table.column("highlightColor", .text)
        table.column("isUnderlined", .boolean).notNull().defaults(to: false)
        table.column("createdAt", .datetime).notNull()
        table.column("updatedAt", .datetime).notNull()
        table.column("completedAt", .datetime)
        table.column("deletedAt", .datetime)
        table.check(sql: "effort IS NULL OR effort BETWEEN 1 AND 4")
      }
      try database.execute(
        sql: """
          INSERT INTO mainTask_v2
          SELECT id, reminderIdentifier, title, effort, sortIndex, taskDescription,
                 textColor, highlightColor, isUnderlined, createdAt, updatedAt,
                 completedAt, deletedAt
          FROM mainTask
          """)
      try database.drop(table: MainTask.databaseTableName)
      try database.rename(table: "mainTask_v2", to: MainTask.databaseTableName)
      try database.create(
        index: "mainTask_active_order",
        on: MainTask.databaseTableName,
        columns: ["deletedAt", "completedAt", "sortIndex"]
      )

      try database.create(table: ReminderSyncRecord.databaseTableName) { table in
        table.column("taskID", .text).primaryKey()
          .references(MainTask.databaseTableName, onDelete: .cascade)
        table.column("calendarItemIdentifier", .text).unique()
        table.column("externalIdentifier", .text)
        table.column("origin", .text).notNull()
        table.column("baselineTitle", .text)
        table.column("baselineCompleted", .boolean)
        table.column("baselineExternalModifiedAt", .datetime)
        table.column("localCoreUpdatedAt", .datetime).notNull()
        table.column("lastSuccessfulSyncAt", .datetime)
        table.column("pendingMutation", .text)
        table.column("retryCount", .integer).notNull().defaults(to: 0)
        table.column("lastErrorCode", .text)
      }
      try database.create(
        index: "reminderSync_pending",
        on: ReminderSyncRecord.databaseTableName,
        columns: ["pendingMutation", "retryCount"]
      )
    }
    migrator.registerMigration("v3-deleted-task-retention") { database in
      try database.create(table: ReminderDeletionTombstone.databaseTableName) { table in
        table.column("taskID", .text).primaryKey()
        table.column("calendarItemIdentifier", .text).notNull().unique()
        table.column("deletedAt", .datetime).notNull()
        table.column("retryCount", .integer).notNull().defaults(to: 0)
        table.column("lastErrorCode", .text)
      }
      try database.create(
        index: "reminderDeletionTombstone_deletedAt",
        on: ReminderDeletionTombstone.databaseTableName,
        columns: ["deletedAt", "taskID"]
      )

      let excessDeletedTaskIDs = """
        SELECT id
        FROM mainTask
        WHERE deletedAt IS NOT NULL
        ORDER BY deletedAt DESC, id DESC
        LIMIT -1 OFFSET 5
        """
      try database.execute(
        sql: """
          INSERT INTO reminderDeletionTombstone (
            taskID, calendarItemIdentifier, deletedAt, retryCount, lastErrorCode
          )
          SELECT mainTask.id, reminderSync.calendarItemIdentifier,
                 mainTask.deletedAt, reminderSync.retryCount, reminderSync.lastErrorCode
          FROM mainTask
          JOIN reminderSync ON reminderSync.taskID = mainTask.id
          WHERE mainTask.id IN (\(excessDeletedTaskIDs))
            AND reminderSync.pendingMutation = 'delete'
            AND reminderSync.calendarItemIdentifier IS NOT NULL
          """
      )
      try database.execute(
        sql: "DELETE FROM taskStep WHERE mainTaskID IN (\(excessDeletedTaskIDs))"
      )
      try database.execute(
        sql: "DELETE FROM workspaceNote WHERE mainTaskID IN (\(excessDeletedTaskIDs))"
      )
      try database.execute(
        sql: "DELETE FROM reminderSync WHERE taskID IN (\(excessDeletedTaskIDs))"
      )
      try database.execute(
        sql: "DELETE FROM mainTask WHERE id IN (\(excessDeletedTaskIDs))"
      )
    }
    return migrator
  }
}
