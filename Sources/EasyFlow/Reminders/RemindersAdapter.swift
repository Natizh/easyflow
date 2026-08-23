import Foundation

enum RemindersAccessState: Equatable, Sendable {
  case notDetermined
  case requesting
  case fullAccess
  case denied
  case restricted
  case unavailable
  case error(String)
}

struct ReminderListSnapshot: Equatable, Sendable {
  var id: String
  var title: String
  var isWritable: Bool
}

struct ReminderItemSnapshot: Equatable, Sendable {
  var calendarItemIdentifier: String
  var externalIdentifier: String?
  var title: String
  var isCompleted: Bool
  var lastModifiedAt: Date?
}

@MainActor
protocol RemindersAdapter: AnyObject {
  var authorizationState: RemindersAccessState { get }
  func requestFullAccess() async throws -> Bool
  func lists() throws -> [ReminderListSnapshot]
  func createList(named title: String) throws -> ReminderListSnapshot
  func reminders(inList identifier: String) async throws -> [ReminderItemSnapshot]
  func createReminder(
    inList identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot
  func updateReminder(
    identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot
  func deleteReminder(identifier: String) throws
  func changes() -> AsyncStream<Void>
}

enum ReminderListSelection: Equatable {
  case use(ReminderListSnapshot)
  case create
  case ambiguous([ReminderListSnapshot])
}

enum ReminderListSelector {
  static func select(
    persistedIdentifier: String?,
    lists: [ReminderListSnapshot],
    requiredName: String = "EasyFlow"
  ) -> ReminderListSelection {
    if let persistedIdentifier,
      let persisted = lists.first(where: { $0.id == persistedIdentifier && $0.isWritable })
    {
      return .use(persisted)
    }
    let matches = lists.filter { $0.isWritable && $0.title == requiredName }
    if matches.count == 1 { return .use(matches[0]) }
    if matches.isEmpty { return .create }
    return .ambiguous(matches)
  }
}

@MainActor
final class DisabledRemindersAdapter: RemindersAdapter {
  var authorizationState: RemindersAccessState { .unavailable }
  func requestFullAccess() async throws -> Bool { false }
  func lists() throws -> [ReminderListSnapshot] { [] }
  func createList(named title: String) throws -> ReminderListSnapshot {
    throw CocoaError(.featureUnsupported)
  }
  func reminders(inList identifier: String) async throws -> [ReminderItemSnapshot] { [] }
  func createReminder(
    inList identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    throw CocoaError(.featureUnsupported)
  }
  func updateReminder(
    identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    throw CocoaError(.featureUnsupported)
  }
  func deleteReminder(identifier: String) throws {
    throw CocoaError(.featureUnsupported)
  }
  func changes() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
