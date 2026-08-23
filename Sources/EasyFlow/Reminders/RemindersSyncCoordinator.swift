import Foundation
import SwiftUI

enum RemindersSyncStatus: Equatable, Sendable {
  case needsAccess
  case requesting
  case synchronizing
  case connected
  case denied
  case ambiguousList
  case error(String)
}

@MainActor
final class RemindersSyncCoordinator: ObservableObject {
  @Published private(set) var status: RemindersSyncStatus = .needsAccess

  private let repository: WorkspaceRepository
  private let adapter: RemindersAdapter
  private var syncTask: Task<Void, Never>?
  private var changesTask: Task<Void, Never>?

  init(repository: WorkspaceRepository, adapter: RemindersAdapter) {
    self.repository = repository
    self.adapter = adapter
  }

  func start() {
    switch adapter.authorizationState {
    case .notDetermined:
      requestAccess()
    case .fullAccess:
      synchronize()
    case .denied, .restricted:
      status = .denied
    case .unavailable:
      status = .error("Reminders unavailable")
    case .requesting:
      status = .requesting
    case .error(let message):
      status = .error(message)
    }
    changesTask = Task { [weak self, adapter] in
      for await _ in adapter.changes() {
        do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        self?.synchronize()
      }
    }
  }

  func stop() {
    syncTask?.cancel()
    changesTask?.cancel()
  }

  func requestAccess() {
    guard status != .requesting else { return }
    status = .requesting
    Task { [weak self, adapter] in
      do {
        if try await adapter.requestFullAccess() {
          self?.synchronize()
        } else {
          self?.status = .denied
        }
      } catch {
        self?.status = .error("Authorization failed")
      }
    }
  }

  func retry() {
    if adapter.authorizationState == .fullAccess { synchronize() } else { requestAccess() }
  }

  func synchronize() {
    guard syncTask == nil else { return }
    status = .synchronizing
    syncTask = Task { [weak self] in
      guard let self else { return }
      defer { self.syncTask = nil }
      await self.performSynchronization()
    }
  }

  private func performSynchronization() async {
    guard adapter.authorizationState == .fullAccess else {
      status = .denied
      return
    }
    do {
      let persisted = try await repository.storedReminderListIdentifier()
      let lists = try adapter.lists()
      let list: ReminderListSnapshot
      switch ReminderListSelector.select(persistedIdentifier: persisted, lists: lists) {
      case .use(let existing):
        list = existing
      case .create:
        list = try adapter.createList(named: "EasyFlow")
      case .ambiguous:
        status = .ambiguousList
        return
      }
      try await repository.storeReminderListIdentifier(list.id)
      let externalItems = try await adapter.reminders(inList: list.id)
      try await reconcile(list: list, externalItems: externalItems)
      status = .connected
    } catch {
      status = .error("Synchronization failed")
    }
  }

  private func reconcile(
    list: ReminderListSnapshot,
    externalItems: [ReminderItemSnapshot]
  ) async throws {
    let deletionTombstones = try await repository.reminderDeletionTombstones()
    let states = try await repository.syncTaskStates()
    var externalByID = Dictionary(
      uniqueKeysWithValues: externalItems.map { ($0.calendarItemIdentifier, $0) }
    )

    for tombstone in deletionTombstones {
      try Task.checkCancellation()
      guard externalByID.removeValue(forKey: tombstone.calendarItemIdentifier) != nil else {
        try await repository.completeReminderDeletion(taskID: tombstone.taskID)
        continue
      }
      do {
        try adapter.deleteReminder(identifier: tombstone.calendarItemIdentifier)
        try await repository.completeReminderDeletion(taskID: tombstone.taskID)
      } catch {
        try await repository.markReminderDeletionFailure(
          taskID: tombstone.taskID,
          code: "delete"
        )
      }
    }

    for state in states {
      try Task.checkCancellation()
      let task = state.task
      let sync = state.sync
      if sync?.pendingMutation == .delete || task.deletedAt != nil {
        if let identifier = sync?.calendarItemIdentifier,
          externalByID.removeValue(forKey: identifier) != nil
        {
          do {
            try adapter.deleteReminder(identifier: identifier)
            try await repository.confirmExternalDeletion(taskID: task.id)
          } catch {
            try await repository.markSyncFailure(taskID: task.id, code: "delete")
          }
        }
        continue
      }

      guard let identifier = sync?.calendarItemIdentifier else {
        do {
          let created = try adapter.createReminder(
            inList: list.id,
            title: task.title,
            isCompleted: task.completedAt != nil
          )
          try await repository.markSyncSuccess(
            taskID: task.id,
            calendarItemIdentifier: created.calendarItemIdentifier,
            externalIdentifier: created.externalIdentifier,
            title: created.title,
            isCompleted: created.isCompleted,
            externalModifiedAt: created.lastModifiedAt
          )
        } catch {
          try await repository.markSyncFailure(taskID: task.id, code: "create")
        }
        continue
      }

      guard let external = externalByID.removeValue(forKey: identifier) else {
        if (sync?.retryCount ?? 0) > 0 {
          try await repository.confirmExternalDeletion(taskID: task.id)
        } else {
          try await repository.markSyncFailure(taskID: task.id, code: "missing")
        }
        continue
      }
      do {
        try await reconcileMapped(task: task, sync: sync!, external: external)
      } catch {
        try await repository.markSyncFailure(taskID: task.id, code: "update")
      }
    }

    for external in externalByID.values.sorted(by: {
      $0.calendarItemIdentifier < $1.calendarItemIdentifier
    }) {
      _ = try await repository.importReminder(
        title: external.title,
        isCompleted: external.isCompleted,
        calendarItemIdentifier: external.calendarItemIdentifier,
        externalIdentifier: external.externalIdentifier,
        externalModifiedAt: external.lastModifiedAt
      )
    }
  }

  private func reconcileMapped(
    task: MainTask,
    sync: ReminderSyncRecord,
    external: ReminderItemSnapshot
  ) async throws {
    let external =
      if task.completedAt != nil && !external.isCompleted {
        try adapter.updateReminder(
          identifier: external.calendarItemIdentifier,
          title: external.title,
          isCompleted: true
        )
      } else {
        external
      }
    guard let baselineTitle = sync.baselineTitle,
      let baselineCompleted = sync.baselineCompleted
    else {
      try await repository.markSyncSuccess(
        taskID: task.id,
        calendarItemIdentifier: external.calendarItemIdentifier,
        externalIdentifier: external.externalIdentifier,
        title: external.title,
        isCompleted: external.isCompleted,
        externalModifiedAt: external.lastModifiedAt
      )
      return
    }
    let decision = ReminderReconciler.decide(
      local: ReminderCore(title: task.title, isCompleted: task.completedAt != nil),
      baseline: ReminderCore(title: baselineTitle, isCompleted: baselineCompleted),
      external: ReminderCore(title: external.title, isCompleted: external.isCompleted),
      localChangedAt: sync.localCoreUpdatedAt,
      externalChangedAt: external.lastModifiedAt
    )
    switch decision {
    case .conflict:
      try await repository.markSyncFailure(taskID: task.id, code: "conflict")
    case .noChange(let core):
      try await repository.markSyncSuccess(
        taskID: task.id,
        calendarItemIdentifier: external.calendarItemIdentifier,
        externalIdentifier: external.externalIdentifier,
        title: core.title,
        isCompleted: core.isCompleted,
        externalModifiedAt: external.lastModifiedAt
      )
    case .apply(let core, let pushExternal, _):
      let finalExternal =
        pushExternal
        ? try adapter.updateReminder(
          identifier: external.calendarItemIdentifier,
          title: core.title,
          isCompleted: core.isCompleted
        ) : external
      try await repository.applyExternalCore(
        taskID: task.id,
        title: core.title,
        isCompleted: core.isCompleted,
        calendarItemIdentifier: finalExternal.calendarItemIdentifier,
        externalIdentifier: finalExternal.externalIdentifier,
        externalModifiedAt: finalExternal.lastModifiedAt
      )
    }
  }
}
