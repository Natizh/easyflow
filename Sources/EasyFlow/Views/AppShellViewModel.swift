import Combine
import SwiftUI

@MainActor
final class AppShellViewModel: ObservableObject {
  @Published private(set) var snapshot = WorkspaceSnapshot.empty
  @Published private(set) var focusRequestID = 0
  @Published var secondaryContext: SecondaryPanelContext?
  @Published var quickNoteDraft = ""
  @Published var isCreatingTask = false
  @Published var newTaskTitle = ""
  @Published var newTaskEffort: Effort?
  @Published var isSettingsPresented = false {
    didSet {
      if oldValue != isSettingsPresented {
        onSettingsPresentationChanged?(isSettingsPresented)
      }
    }
  }
  @Published var errorMessage: String?
  @Published private(set) var remindersStatus: RemindersSyncStatus

  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?
  var onSettingsPresentationChanged: ((Bool) -> Void)?

  private let repository: WorkspaceRepository
  private let remindersSync: RemindersSyncCoordinator
  private var remindersStatusCancellable: AnyCancellable?
  private var observationTask: Task<Void, Never>?
  private var draftSaveTask: Task<Void, Never>?
  private var draftRevision = UUID()
  private var loadedInitialDraft = false

  init(
    repository: WorkspaceRepository,
    remindersSync: RemindersSyncCoordinator? = nil
  ) {
    self.repository = repository
    let sync =
      remindersSync
      ?? RemindersSyncCoordinator(
        repository: repository,
        adapter: DisabledRemindersAdapter()
      )
    self.remindersSync = sync
    remindersStatus = sync.status
    remindersStatusCancellable = sync.$status.sink { [weak self] in
      self?.remindersStatus = $0
    }
  }

  func start() {
    guard observationTask == nil else { return }
    observationTask = Task { [weak self, repository] in
      do {
        let stream = await repository.observe()
        for try await snapshot in stream {
          guard let self else { return }
          self.apply(snapshot)
        }
      } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
    remindersSync.start()
  }

  func stop() {
    commitQuickNoteIfNeeded()
    observationTask?.cancel()
    observationTask = nil
    draftSaveTask?.cancel()
    draftSaveTask = nil
    remindersSync.stop()
  }

  func requestRemindersAccess() {
    remindersSync.requestAccess()
  }

  func retryRemindersSync() {
    remindersSync.retry()
  }

  func openRemindersPrivacySettings() {
    EventKitRemindersAdapter.openPrivacySettings()
  }

  func requestQuickNoteFocus() {
    focusRequestID &+= 1
  }

  func registerInteraction() {
    onInteraction?()
  }

  func requestSecondary(_ context: SecondaryPanelContext) {
    onInteraction?()
    onSecondaryRequested?(context)
  }

  func clearSecondary() {
    onSecondaryCleared?()
  }

  func setQuickNoteDraft(_ body: String) {
    quickNoteDraft = body
    draftRevision = UUID()
    registerInteraction()
    scheduleDraftSave(body: body, revision: draftRevision)
  }

  func commitQuickNoteIfNeeded() {
    let body = quickNoteDraft
    guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      quickNoteDraft = ""
      draftSaveTask?.cancel()
      Task { [repository] in try? await repository.clearDraft() }
      return
    }

    let revision = draftRevision
    draftSaveTask?.cancel()
    quickNoteDraft = ""
    draftRevision = UUID()
    requestQuickNoteFocus()
    Task { [weak self, repository] in
      do {
        _ = try await repository.commitDraft(body: body, revision: revision)
      } catch {
        guard let self else { return }
        if self.quickNoteDraft.isEmpty {
          self.quickNoteDraft = body
          self.draftRevision = revision
        }
        self.errorMessage = error.localizedDescription
      }
    }
  }

  func createMainTask() {
    guard let effort = newTaskEffort else { return }
    let title = newTaskTitle
    Task { [weak self, repository] in
      do {
        _ = try await repository.createMainTask(title: title, effort: effort)
        self?.newTaskTitle = ""
        self?.newTaskEffort = nil
        self?.isCreatingTask = false
      } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func updateMainTask(
    id: UUID,
    title: String? = nil,
    effort: Effort? = nil,
    description: String? = nil,
    style: ItemStyle? = nil
  ) {
    Task { [weak self, repository] in
      do {
        try await repository.updateMainTask(
          id: id,
          title: title,
          effort: effort,
          description: description,
          style: style
        )
      } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func completeMainTask(_ id: UUID) {
    Task { [weak self, repository] in
      do { try await repository.completeMainTask(id: id) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteMainTask(_ id: UUID) {
    Task { [weak self, repository] in
      do { try await repository.softDeleteMainTask(id: id) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderMainTask(draggedID: UUID, before targetID: UUID) {
    guard
      let ids = ReorderLogic.moving(
        snapshot.activeTasks.map(\.id),
        draggedID: draggedID,
        before: targetID
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderMainTasks(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderMainTask(draggedID: UUID, toInsertionIndex: Int) {
    guard
      let ids = ReorderLogic.moving(
        snapshot.activeTasks.map(\.id),
        draggedID: draggedID,
        toInsertionIndex: toInsertionIndex
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderMainTasks(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func createStep(mainTaskID: UUID, title: String) {
    Task { [weak self, repository] in
      do { _ = try await repository.createStep(mainTaskID: mainTaskID, title: title) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func updateStep(
    id: UUID,
    title: String? = nil,
    notes: String? = nil,
    isCompleted: Bool? = nil,
    style: ItemStyle? = nil
  ) {
    Task { [weak self, repository] in
      do {
        try await repository.updateStep(
          id: id,
          title: title,
          notes: notes,
          isCompleted: isCompleted,
          style: style
        )
      } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteStep(_ id: UUID) {
    Task { [weak self, repository] in
      do { try await repository.softDeleteStep(id: id) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderStep(mainTaskID: UUID, draggedID: UUID, before targetID: UUID) {
    guard let current = snapshot.stepsByTask[mainTaskID],
      let ids = ReorderLogic.moving(
        current.map(\.id),
        draggedID: draggedID,
        before: targetID
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderSteps(mainTaskID: mainTaskID, ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderStep(mainTaskID: UUID, draggedID: UUID, toInsertionIndex: Int) {
    guard let current = snapshot.stepsByTask[mainTaskID],
      let ids = ReorderLogic.moving(
        current.map(\.id),
        draggedID: draggedID,
        toInsertionIndex: toInsertionIndex
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderSteps(mainTaskID: mainTaskID, ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func updateNote(id: UUID, title: String?, body: String) {
    Task { [weak self, repository] in
      do { try await repository.updateNote(id: id, title: title, body: body) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteNote(_ id: UUID) {
    Task { [weak self, repository] in
      do { try await repository.softDeleteNote(id: id) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderQuickNote(draggedID: UUID, before targetID: UUID) {
    guard
      let ids = ReorderLogic.moving(
        snapshot.quickNotes.map(\.id),
        draggedID: draggedID,
        before: targetID
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderQuickNotes(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func reorderQuickNote(draggedID: UUID, toInsertionIndex: Int) {
    guard
      let ids = ReorderLogic.moving(
        snapshot.quickNotes.map(\.id),
        draggedID: draggedID,
        toInsertionIndex: toInsertionIndex
      )
    else { return }
    Task { [weak self, repository] in
      do { try await repository.reorderQuickNotes(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func moveQuickNote(_ noteID: UUID, to taskID: UUID) {
    Task { [weak self, repository] in
      do { try await repository.moveQuickNote(id: noteID, to: taskID) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func handleDrop(_ payload: String, on taskID: UUID) -> Bool {
    if let noteID = Self.payloadID(payload, prefix: "note:") {
      moveQuickNote(noteID, to: taskID)
      return true
    }
    if let taskIDToMove = Self.payloadID(payload, prefix: "task:") {
      reorderMainTask(draggedID: taskIDToMove, before: taskID)
      return true
    }
    return false
  }

  func handleQuickNoteDrop(_ payload: String, on noteID: UUID) -> Bool {
    guard let draggedID = Self.payloadID(payload, prefix: "note:") else { return false }
    reorderQuickNote(draggedID: draggedID, before: noteID)
    return true
  }

  func handleStepDrop(_ payload: String, taskID: UUID, on stepID: UUID) -> Bool {
    guard let draggedID = Self.payloadID(payload, prefix: "step:") else { return false }
    reorderStep(mainTaskID: taskID, draggedID: draggedID, before: stepID)
    return true
  }

  private func apply(_ newSnapshot: WorkspaceSnapshot) {
    snapshot = newSnapshot
    if !loadedInitialDraft {
      loadedInitialDraft = true
      if let draft = newSnapshot.draft {
        quickNoteDraft = draft.body
        draftRevision = draft.revision
      }
    }
  }

  private func scheduleDraftSave(body: String, revision: UUID) {
    draftSaveTask?.cancel()
    draftSaveTask = Task { [weak self, repository] in
      do {
        try await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        try await repository.saveDraft(body: body, revision: revision)
      } catch is CancellationError {
      } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  private static func payloadID(_ payload: String, prefix: String) -> UUID? {
    guard payload.hasPrefix(prefix) else { return nil }
    return UUID(uuidString: String(payload.dropFirst(prefix.count)))
  }
}
