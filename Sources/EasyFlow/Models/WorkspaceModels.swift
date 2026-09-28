import Foundation
@preconcurrency import GRDB

enum Effort: Int, Codable, CaseIterable, DatabaseValueConvertible, Sendable {
  case one = 1
  case two = 2
  case three = 3
  case four = 4

  var pickerLabel: String { "\(rawValue)" }

  static var pickerLabels: [String] {
    allCases.map(\.pickerLabel)
  }
}

enum NewTaskEffortSelectionPresentation {
  static let label = "Effort"
  static let selectableLabels = Effort.pickerLabels
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

struct RichTextAttributes: Codable, Equatable, Sendable {
  struct Run: Codable, Equatable, Sendable {
    var location: Int
    var length: Int
    var bold: Bool
    var italic: Bool
    var underline: Bool
    var highlightColor: StyleColor?

    var isEmpty: Bool {
      !bold && !italic && !underline && highlightColor == nil
    }
  }

  var runs: [Run]

  static let empty = RichTextAttributes(runs: [])

  var isEmpty: Bool { runs.isEmpty }

  init(runs: [Run] = []) {
    self.runs = runs.filter { $0.length > 0 && !$0.isEmpty }
  }

  init?(json: String?) {
    guard let json, let data = json.data(using: .utf8) else {
      self = .empty
      return
    }
    do {
      self = try JSONDecoder().decode(Self.self, from: data)
    } catch {
      self = .empty
    }
  }

  var jsonString: String? {
    guard !runs.isEmpty,
      let data = try? JSONEncoder().encode(self)
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

struct RichTextValue: Equatable, Sendable {
  var text: String
  var attributes: RichTextAttributes

  static func plain(_ text: String) -> RichTextValue {
    RichTextValue(text: text, attributes: .empty)
  }
}

enum ReminderFrequency: Equatable, Sendable {
  case minutes15
  case minutes30
  case hour1
  case hours2
  case hours3
  case custom(TimeInterval)

  var interval: TimeInterval {
    switch self {
    case .minutes15: 15 * 60
    case .minutes30: 30 * 60
    case .hour1: 60 * 60
    case .hours2: 2 * 60 * 60
    case .hours3: 3 * 60 * 60
    case .custom(let interval): max(60, interval)
    }
  }
}

struct ReminderSettings: Equatable, Sendable {
  var isEnabled: Bool
  var frequency: ReminderFrequency
  var customInterval: TimeInterval
  var pausedUntil: Date?

  static let defaultCustomInterval: TimeInterval = 60 * 60
  static let defaults = ReminderSettings(
    isEnabled: true,
    frequency: .hour1,
    customInterval: defaultCustomInterval,
    pausedUntil: nil
  )

  var effectiveInterval: TimeInterval { frequency.interval }

  func isPaused(at date: Date) -> Bool {
    guard let pausedUntil else { return false }
    return pausedUntil > date
  }
}

enum ReminderPausePreset: CaseIterable, Equatable, Sendable {
  case oneHour
  case threeHours
  case untilTomorrow

  func pausedUntil(from date: Date, calendar: Calendar = .current) -> Date {
    switch self {
    case .oneHour:
      return date.addingTimeInterval(60 * 60)
    case .threeHours:
      return date.addingTimeInterval(3 * 60 * 60)
    case .untilTomorrow:
      return calendar.startOfDay(for: date).addingTimeInterval(24 * 60 * 60 + 8 * 60 * 60)
    }
  }
}

enum ReminderEligibility {
  static func firstEligibleTask(in tasks: [MainTask]) -> MainTask? {
    tasks.first { !$0.remindersExcluded }
  }
}

struct ReminderScheduleState: Equatable, Sendable {
  var isEnabled: Bool
  var interval: TimeInterval
  var pausedUntil: Date?
  var hasEligibleTasks: Bool

  init(
    settings: ReminderSettings,
    activeTasks: [MainTask]
  ) {
    isEnabled = settings.isEnabled
    interval = settings.effectiveInterval
    pausedUntil = settings.pausedUntil
    hasEligibleTasks = ReminderEligibility.firstEligibleTask(in: activeTasks) != nil
  }

  func isPaused(at date: Date) -> Bool {
    guard let pausedUntil else { return false }
    return pausedUntil > date
  }
}

enum ReminderTimerAction: Equatable, Sendable {
  case keep
  case cancel
  case schedule(after: TimeInterval)
}

enum ReminderSchedulePolicy {
  static func action(
    previous: ReminderScheduleState?,
    current: ReminderScheduleState,
    timerIsActive: Bool,
    now: Date
  ) -> ReminderTimerAction {
    guard current.isEnabled else { return .cancel }

    if current.isPaused(at: now) {
      guard !timerIsActive || previous?.pausedUntil != current.pausedUntil
      else { return .keep }
      return .schedule(after: max(0, current.pausedUntil?.timeIntervalSince(now) ?? 0))
    }

    guard current.hasEligibleTasks else { return .cancel }
    guard let previous else { return .schedule(after: current.interval) }
    if !timerIsActive { return .schedule(after: current.interval) }
    if !previous.isEnabled { return .schedule(after: current.interval) }
    if previous.interval != current.interval { return .schedule(after: current.interval) }
    if previous.pausedUntil != current.pausedUntil { return .schedule(after: current.interval) }
    if !previous.hasEligibleTasks && current.hasEligibleTasks {
      return .schedule(after: current.interval)
    }
    return .keep
  }
}

enum StepNoteFieldPresentation {
  static let placeholder = ""
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
  var remindersExcluded: Bool = false
  var taskDescriptionAttributes: String? = nil
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

  var descriptionRichTextAttributes: RichTextAttributes {
    RichTextAttributes(json: taskDescriptionAttributes) ?? .empty
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
  var titleAttributes: String? = nil
  var notesAttributes: String? = nil
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

  var titleRichTextAttributes: RichTextAttributes {
    RichTextAttributes(json: titleAttributes) ?? .empty
  }

  var notesRichTextAttributes: RichTextAttributes {
    RichTextAttributes(json: notesAttributes) ?? .empty
  }
}

struct WorkspaceNote: Codable, Equatable, Identifiable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "workspaceNote"

  var id: UUID
  var title: String?
  var body: String
  var bodyAttributes: String? = nil
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

    let generated = Self.derivedTitle(from: body)
    if generated.isEmpty {
      return "Untitled Note"
    }
    return generated
  }

  var preview: String {
    body
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }

  var bodyRichTextAttributes: RichTextAttributes {
    RichTextAttributes(json: bodyAttributes) ?? .empty
  }

  static func derivedTitle(from body: String) -> String {
    body
      .split(whereSeparator: { $0.isWhitespace })
      .prefix(3)
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
  var bodyAttributes: String? = nil
  var updatedAt: Date

  var bodyRichTextAttributes: RichTextAttributes {
    RichTextAttributes(json: bodyAttributes) ?? .empty
  }
}

struct WorkspaceSnapshot: Equatable, Sendable {
  var quickNotes: [WorkspaceNote]
  var activeTasks: [MainTask]
  var recentlyCompleted: [MainTask]
  var stepsByTask: [UUID: [TaskStep]]
  var attachedNotesByTask: [UUID: [WorkspaceNote]]
  var draft: QuickNoteDraft?
  var attachmentsByNote: [UUID: [NoteAttachment]] = [:]
  var draftAttachments: [NoteAttachment] = []
  var reminderSettings: ReminderSettings = .defaults

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

extension WorkspaceError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .emptyTitle: "Enter a title first."
    case .emptyNote: "The note is empty."
    case .taskNotFound: "That task is no longer available."
    case .stepNotFound: "That step is no longer available."
    case .noteNotFound: "That note is no longer available."
    case .invalidOrder: "The list changed while you were reordering it. Try again."
    }
  }
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

struct ReminderDeletionTombstone: Codable, Equatable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "reminderDeletionTombstone"

  var taskID: UUID
  var calendarItemIdentifier: String
  var deletedAt: Date
  var retryCount: Int
  var lastErrorCode: String?
}

struct SyncTaskState: Equatable, Sendable {
  var task: MainTask
  var sync: ReminderSyncRecord?
}
