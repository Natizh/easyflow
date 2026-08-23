import Foundation
@preconcurrency import GRDB

enum Effort: Int, Codable, CaseIterable, DatabaseValueConvertible, Sendable {
  case one = 1
  case two = 2
  case three = 3
  case four = 4
}

enum StyleColor: String, Codable, CaseIterable, DatabaseValueConvertible, Sendable {
  case red
  case orange
  case yellow
  case green
  case blue
  case purple
}

struct ItemStyle: Equatable, Sendable {
  var textColor: StyleColor?
  var highlightColor: StyleColor?
  var isUnderlined: Bool

  static let plain = ItemStyle(
    textColor: nil,
    highlightColor: nil,
    isUnderlined: false
  )
}

struct MainTask: Codable, Equatable, Identifiable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "mainTask"

  var id: UUID
  var reminderIdentifier: String?
  var title: String
  var effort: Effort?
  var sortIndex: Int
  var taskDescription: String
  var textColor: StyleColor?
  var highlightColor: StyleColor?
  var isUnderlined: Bool
  var createdAt: Date
  var updatedAt: Date
  var completedAt: Date?
  var deletedAt: Date?

  var style: ItemStyle {
    ItemStyle(
      textColor: textColor,
      highlightColor: highlightColor,
      isUnderlined: isUnderlined
    )
  }
}

struct TaskStep: Codable, Equatable, Identifiable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "taskStep"

  var id: UUID
  var mainTaskID: UUID
  var title: String
  var sortIndex: Int
  var isCompleted: Bool
  var notes: String
  var textColor: StyleColor?
  var highlightColor: StyleColor?
  var isUnderlined: Bool
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?

  var style: ItemStyle {
    ItemStyle(
      textColor: textColor,
      highlightColor: highlightColor,
      isUnderlined: isUnderlined
    )
  }
}

struct WorkspaceNote: Codable, Equatable, Identifiable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "workspaceNote"

  var id: UUID
  var title: String?
  var body: String
  var mainTaskID: UUID?
  var sourceDraftRevision: UUID?
  var sortIndex: Int
  var createdAt: Date
  var updatedAt: Date
  var deletedAt: Date?

  var displayTitle: String {
    let explicitTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !explicitTitle.isEmpty {
      return explicitTitle
    }

    let words = body.split(whereSeparator: { $0.isWhitespace })
    let generated = words.prefix(6).joined(separator: " ")
    if generated.isEmpty {
      return "Untitled Note"
    }
    return String(generated.prefix(56))
  }

  var preview: String {
    body
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }
}

struct QuickNoteDraft: Codable, Equatable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "quickNoteDraft"
  static let singletonID = "quick-note"

  var id: String = singletonID
  var revision: UUID
  var body: String
  var updatedAt: Date
}

struct WorkspaceSnapshot: Equatable, Sendable {
  var quickNotes: [WorkspaceNote]
  var activeTasks: [MainTask]
  var recentlyCompleted: [MainTask]
  var stepsByTask: [UUID: [TaskStep]]
  var attachedNotesByTask: [UUID: [WorkspaceNote]]
  var draft: QuickNoteDraft?

  static let empty = WorkspaceSnapshot(
    quickNotes: [],
    activeTasks: [],
    recentlyCompleted: [],
    stepsByTask: [:],
    attachedNotesByTask: [:],
    draft: nil
  )
}

enum WorkspaceError: Error, Equatable {
  case emptyTitle
  case emptyNote
  case taskNotFound
  case stepNotFound
  case noteNotFound
  case invalidOrder
}

enum TaskOrigin: String, Codable, DatabaseValueConvertible, Sendable {
  case local
  case reminders
}

enum SyncPendingMutation: String, Codable, DatabaseValueConvertible, Sendable {
  case create
  case update
  case delete
}

struct ReminderSyncRecord: Codable, Equatable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "reminderSync"

  var taskID: UUID
  var calendarItemIdentifier: String?
  var externalIdentifier: String?
  var origin: TaskOrigin
  var baselineTitle: String?
  var baselineCompleted: Bool?
  var baselineExternalModifiedAt: Date?
  var localCoreUpdatedAt: Date
  var lastSuccessfulSyncAt: Date?
  var pendingMutation: SyncPendingMutation?
  var retryCount: Int
  var lastErrorCode: String?
}

struct SyncTaskState: Equatable, Sendable {
  var task: MainTask
  var sync: ReminderSyncRecord?
}
