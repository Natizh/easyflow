import AppKit
@preconcurrency import EventKit
import Foundation

private final class NotificationTokenBox: @unchecked Sendable {
  var token: NSObjectProtocol?
}

@MainActor
final class EventKitRemindersAdapter: RemindersAdapter {
  private let eventStore: EKEventStore

  init(eventStore: EKEventStore = EKEventStore()) {
    self.eventStore = eventStore
  }

  var authorizationState: RemindersAccessState {
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .notDetermined: .notDetermined
    case .fullAccess, .authorized: .fullAccess
    case .denied: .denied
    case .restricted: .restricted
    case .writeOnly: .unavailable
    @unknown default: .unavailable
    }
  }

  func requestFullAccess() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      Self.requestFullAccess(eventStore: eventStore, continuation: continuation)
    }
  }

  func lists() throws -> [ReminderListSnapshot] {
    eventStore.calendars(for: .reminder).map {
      ReminderListSnapshot(
        id: $0.calendarIdentifier,
        title: $0.title,
        isWritable: $0.allowsContentModifications
      )
    }
  }

  func createList(named title: String) throws -> ReminderListSnapshot {
    guard
      let source = eventStore.defaultCalendarForNewReminders()?.source
        ?? eventStore.sources.first(where: { $0.sourceType == .calDAV || $0.sourceType == .local })
    else {
      throw CocoaError(.fileNoSuchFile)
    }
    let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
    calendar.title = title
    calendar.source = source
    try eventStore.saveCalendar(calendar, commit: true)
    return ReminderListSnapshot(
      id: calendar.calendarIdentifier,
      title: calendar.title,
      isWritable: calendar.allowsContentModifications
    )
  }

  func reminders(inList identifier: String) async throws -> [ReminderItemSnapshot] {
    guard let list = eventStore.calendar(withIdentifier: identifier) else { return [] }
    let predicate = eventStore.predicateForReminders(in: [list])
    let snapshots: [ReminderItemSnapshot] = await withCheckedContinuation { continuation in
      Self.fetchReminderSnapshots(
        eventStore: eventStore,
        predicate: predicate,
        continuation: continuation
      )
    }
    return snapshots
  }

  func createReminder(
    inList identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    guard let list = eventStore.calendar(withIdentifier: identifier) else {
      throw CocoaError(.fileNoSuchFile)
    }
    let reminder = EKReminder(eventStore: eventStore)
    reminder.calendar = list
    reminder.title = title
    reminder.isCompleted = isCompleted
    try eventStore.save(reminder, commit: true)
    return Self.snapshot(reminder)
  }

  func updateReminder(
    identifier: String,
    title: String,
    isCompleted: Bool
  ) throws -> ReminderItemSnapshot {
    guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
      throw CocoaError(.fileNoSuchFile)
    }
    reminder.title = title
    reminder.isCompleted = isCompleted
    try eventStore.save(reminder, commit: true)
    return Self.snapshot(reminder)
  }

  func deleteReminder(identifier: String) throws {
    guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
      throw CocoaError(.fileNoSuchFile)
    }
    try eventStore.remove(reminder, commit: true)
  }

  func changes() -> AsyncStream<Void> {
    AsyncStream { continuation in
      let box = NotificationTokenBox()
      box.token = NotificationCenter.default.addObserver(
        forName: .EKEventStoreChanged,
        object: eventStore,
        queue: .main
      ) { _ in continuation.yield(()) }
      continuation.onTermination = { _ in
        if let token = box.token {
          NotificationCenter.default.removeObserver(token)
        }
        box.token = nil
      }
    }
  }

  static func openPrivacySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }

  nonisolated private static func snapshot(_ reminder: EKReminder) -> ReminderItemSnapshot {
    ReminderItemSnapshot(
      calendarItemIdentifier: reminder.calendarItemIdentifier,
      externalIdentifier: reminder.calendarItemExternalIdentifier,
      title: reminder.title ?? "",
      isCompleted: reminder.isCompleted,
      lastModifiedAt: reminder.lastModifiedDate
    )
  }

  nonisolated private static func requestFullAccess(
    eventStore: EKEventStore,
    continuation: CheckedContinuation<Bool, any Error>
  ) {
    eventStore.requestFullAccessToReminders { granted, error in
      DispatchQueue.main.async {
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: granted)
        }
      }
    }
  }

  nonisolated private static func fetchReminderSnapshots(
    eventStore: EKEventStore,
    predicate: NSPredicate,
    continuation: CheckedContinuation<[ReminderItemSnapshot], Never>
  ) {
    eventStore.fetchReminders(matching: predicate) { reminders in
      let snapshots = (reminders ?? []).map(Self.snapshot)
      DispatchQueue.main.async {
        continuation.resume(returning: snapshots)
      }
    }
  }
}
