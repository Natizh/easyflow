import Combine
import SwiftUI

@MainActor
final class AppShellViewModel: ObservableObject {
  @Published private(set) var snapshot = WorkspaceSnapshot.empty
  @Published private(set) var focusRequestID = 0
  @Published private(set) var newTaskTitleFocusRequestID = 0
  @Published var secondaryContext: SecondaryPanelContext?
  @Published var quickNoteDraft = ""
  @Published private(set) var isCommittingCapture = false
  @Published private(set) var pendingCaptureImageCount = 0
  @Published var panelSide: PanelSide {
    didSet {
      userDefaults.set(panelSide.rawValue, forKey: Self.panelSideKey)
      if oldValue != panelSide { onPanelSideChanged?(panelSide) }
    }
  }
  var onPanelSideChanged: ((PanelSide) -> Void)?
  var onImagePreview: ((NoteAttachment) -> Void)?
  nonisolated let attachmentDirectory: URL
  private var captureTask: Task<Void, Never>?
  private var captureHasImages = false
  private var pendingImages: [(id: UUID, data: [Data])] = []
  private var workspaceWrites: [UUID: Task<Void, Never>] = [:]
  @Published private(set) var isCreatingTask = false
  @Published private(set) var isSelectingNewTaskEffort = false
  @Published var newTaskTitle = ""
  @Published var newTaskEffort: Effort?
  @Published var isSettingsPresented = false {
    didSet {
      if oldValue != isSettingsPresented {
        InputDiagnostics.record("settings presented=\(isSettingsPresented)")
        onSettingsPresentationChanged?(isSettingsPresented)
      }
    }
  }
  @Published var errorMessage: String?
  @Published private(set) var remindersStatus: RemindersSyncStatus
  @Published private(set) var routedTaskDragID: UUID?
  @Published private(set) var routedTaskInsertionIndex: Int?
  @Published private(set) var routedNoteDragID: UUID?
  @Published private(set) var routedNoteInsertionIndex: Int?
  @Published private(set) var routedNoteAttachmentTargetID: UUID?
  @Published private(set) var routedStepDragID: UUID?
  @Published private(set) var routedStepInsertionIndex: Int?
  @Published var appearanceMode: AppearanceMode {
    didSet {
      userDefaults.set(appearanceMode.rawValue, forKey: Self.appearanceModeKey)
    }
  }
  @Published var mainTaskDensity: MainTaskDensity {
    didSet {
      userDefaults.set(mainTaskDensity.rawValue, forKey: Self.mainTaskDensityKey)
    }
  }
  @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus

  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?
  var onSettingsPresentationChanged: ((Bool) -> Void)?
  var onTaskRowsChanged: (([MainTaskRowGeometry]) -> Void)?
  var onQuickNotesFrameChanged: ((CGRect?) -> Void)?
  var onSecondaryCollapseStripFrameChanged: ((CGRect?) -> Void)?
  var onQuickNoteRowsChanged: (([MainTaskRowGeometry]) -> Void)?
  var onStepRowsChanged: (([MainTaskRowGeometry]) -> Void)?
  var onStepExclusionsChanged: (([UUID: [CGRect]]) -> Void)?

  private let repository: WorkspaceRepository
  private let remindersSync: RemindersSyncCoordinator
  private let launchAtLoginService: LaunchAtLoginService
  private let userDefaults: UserDefaults
  private var remindersStatusCancellable: AnyCancellable?
  private var observationTask: Task<Void, Never>?
  private var draftSaveTask: Task<Void, Never>?
  private var draftRevision = UUID()
  private var loadedInitialDraft = false
  private var isSubmittingNewTask = false

  static let appearanceModeKey = "appearanceMode"
  static let panelSideKey = "panelSide"
  static let mainTaskDensityKey = "mainTaskDensity"

  init(
    repository: WorkspaceRepository,
    remindersSync: RemindersSyncCoordinator? = nil,
    userDefaults: UserDefaults = .standard
  ) {
    self.repository = repository
    attachmentDirectory = repository.attachmentDirectory
    panelSide = PanelSide(rawValue: userDefaults.string(forKey: Self.panelSideKey) ?? "right") ?? .right
    self.userDefaults = userDefaults
    let sync =
      remindersSync
      ?? RemindersSyncCoordinator(
        repository: repository,
        adapter: DisabledRemindersAdapter()
      )
    self.remindersSync = sync
    launchAtLoginService = LaunchAtLoginService()
    launchAtLoginStatus = launchAtLoginService.status
    appearanceMode =
      AppearanceMode(
        rawValue: userDefaults.string(forKey: Self.appearanceModeKey) ?? "standard"
      ) ?? .standard
    mainTaskDensity =
      MainTaskDensity(
        rawValue: userDefaults.string(forKey: Self.mainTaskDensityKey) ?? "compact"
      ) ?? .compact
    remindersStatus = sync.status
    remindersStatusCancellable = sync.$status.sink { [weak self] in
      self?.remindersStatus = $0
    }
  }

  func start() {
    guard observationTask == nil else { return }
    observationTask = Task { [weak self, repository] in
      do {
        try await repository.maintainAttachmentFiles()
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
    commitQuickNoteOnFocusLoss()
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

  func refreshLaunchAtLoginStatus() {
    launchAtLoginStatus = launchAtLoginService.status
  }

  func setLaunchAtLogin(_ isEnabled: Bool) {
    do {
      try launchAtLoginService.setEnabled(isEnabled)
      refreshLaunchAtLoginStatus()
    } catch {
      errorMessage = "EasyFlow couldn't update Launch at Login."
      refreshLaunchAtLoginStatus()
    }
  }

  func requestQuickNoteFocus() {
    focusRequestID &+= 1
  }

  func toggleNewTaskCreation() {
    InputDiagnostics.record("newTask action=toggle creatingBefore=\(isCreatingTask)")
    if isCreatingTask {
      cancelNewTaskCreation()
    } else {
      beginNewTaskCreation()
    }
  }

  func beginNewTaskCreation() {
    isCreatingTask = true
    isSelectingNewTaskEffort = false
    newTaskTitleFocusRequestID &+= 1
    InputDiagnostics.record("newTask creating=true focusRequest=\(newTaskTitleFocusRequestID)")
    registerInteraction()
  }

  func cancelNewTaskCreation() {
    isCreatingTask = false
    isSelectingNewTaskEffort = false
    newTaskTitle = ""
    newTaskEffort = nil
    isSubmittingNewTask = false
    registerInteraction()
  }

  func advanceNewTaskTitleEntry() {
    guard isCreatingTask else { return }
    guard !newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }
    isSelectingNewTaskEffort = true
    registerInteraction()
  }

  @discardableResult
  func selectNewTaskEffortFromKeyboard(_ rawValue: Int) -> Bool {
    guard isCreatingTask, isSelectingNewTaskEffort, !isSubmittingNewTask,
      let effort = Effort(rawValue: rawValue)
    else { return false }
    newTaskEffort = effort
    createMainTask()
    return true
  }

  func registerInteraction() {
    onInteraction?()
  }

  func requestSecondary(_ context: SecondaryPanelContext) {
    if case .task(let id) = context {
      guard snapshot.activeTasks.contains(where: { $0.id == id }) else {
        assertionFailure("Requested Secondary context for an unknown task ID")
        return
      }
    }
    onInteraction?()
    onSecondaryRequested?(context)
  }

  func updateTaskRows(_ rows: [MainTaskRowGeometry]) {
    onTaskRowsChanged?(rows)
  }

  func updateQuickNotesFrame(_ frame: CGRect?) {
    onQuickNotesFrameChanged?(frame)
  }

  func updateSecondaryCollapseStripFrame(_ frame: CGRect?) {
    onSecondaryCollapseStripFrameChanged?(frame)
  }

  func updateQuickNoteRows(_ rows: [MainTaskRowGeometry]) {
    onQuickNoteRowsChanged?(rows)
  }

  func updateStepRows(_ rows: [MainTaskRowGeometry]) {
    onStepRowsChanged?(rows)
  }

  func updateStepExclusions(_ exclusions: [UUID: [CGRect]]) {
    onStepExclusionsChanged?(exclusions)
  }

  func routedTaskHover(_ taskID: UUID) {
    InputDiagnostics.record("hover task=\(taskID.uuidString)")
    requestSecondary(.task(id: taskID))
  }

  func routedQuickNotesHover() {
    InputDiagnostics.record("context=quickNotes")
    requestSecondary(.quickNotes)
  }

  func routedSecondaryCollapseStrip() {
    InputDiagnostics.record("context=secondaryCollapseStrip clearSecondary")
    clearSecondary()
  }

  func routedTaskDragChanged(taskID: UUID, insertionIndex: Int) {
    routedTaskDragID = taskID
    routedTaskInsertionIndex = insertionIndex
  }

  func routedTaskDragCommitted(taskID: UUID, insertionIndex: Int) {
    reorderMainTask(draggedID: taskID, toInsertionIndex: insertionIndex)
    routedTaskDragCancelled()
  }

  func routedTaskDragCancelled() {
    routedTaskDragID = nil
    routedTaskInsertionIndex = nil
  }

  func routedNoteDragChanged(noteID: UUID, insertionIndex: Int?, taskTargetID: UUID?) {
    routedNoteDragID = noteID
    routedNoteInsertionIndex = insertionIndex
    routedNoteAttachmentTargetID = taskTargetID
  }

  func routedNoteDragCommitted(noteID: UUID, insertionIndex: Int?, taskTargetID: UUID?) {
    if let taskTargetID {
      moveQuickNote(noteID, to: taskTargetID)
    } else if let insertionIndex {
      reorderQuickNote(draggedID: noteID, toInsertionIndex: insertionIndex)
    }
    routedNoteDragCancelled()
  }

  func routedNoteDragCancelled() {
    routedNoteDragID = nil
    routedNoteInsertionIndex = nil
    routedNoteAttachmentTargetID = nil
  }

  func routedStepDragChanged(stepID: UUID, insertionIndex: Int) {
    routedStepDragID = stepID
    routedStepInsertionIndex = insertionIndex
  }

  func routedStepDragCommitted(stepID: UUID, insertionIndex: Int) {
    guard let taskID = secondaryContext?.taskID else {
      routedStepDragCancelled()
      return
    }
    reorderStep(
      mainTaskID: taskID,
      draggedID: stepID,
      toInsertionIndex: insertionIndex
    )
    routedStepDragCancelled()
  }

  func routedStepDragCancelled() {
    routedStepDragID = nil
    routedStepInsertionIndex = nil
  }

  func clearSecondary() {
    onSecondaryCleared?()
  }

  func setQuickNoteDraft(_ body: String) {
    quickNoteDraft = body
    registerInteraction()
    scheduleDraftSave(body: body, revision: draftRevision)
  }

  private func enqueueCapture(_ operation: @escaping @MainActor () async -> Void) {
    let previous = captureTask
    captureTask = Task {
      await previous?.value
      await operation()
    }
  }

  func pasteCaptureImages(_ images: [Data]) {
    guard !images.isEmpty else { return }
    let batch = (id: UUID(), data: images)
    captureHasImages = true
    pendingImages.append(batch)
    pendingCaptureImageCount += images.count
    let revision = draftRevision
    registerInteraction()
    enqueueCapture { [self] in
      do {
        try await repository.addImages(images, to: .draft(revision: revision, body: quickNoteDraft))
        pendingImages.removeAll { $0.id == batch.id }
        pendingCaptureImageCount -= images.count
      } catch { errorMessage = error.localizedDescription }
    }
  }

  func pasteImages(_ images: [Data], into noteID: UUID) {
    registerInteraction()
    performWorkspaceWrite { [self] in
      do { try await repository.addImages(images, to: .note(noteID)) }
      catch { errorMessage = error.localizedDescription }
    }
  }

  func removeAttachment(_ id: UUID) {
    performWorkspaceWrite { [self] in
      do { try await repository.removeAttachment(id: id) }
      catch { errorMessage = error.localizedDescription }
    }
  }

  func previewImage(_ attachment: NoteAttachment) {
    onImagePreview?(attachment)
  }

  func commitQuickNoteIfNeeded() { commitCapture(refocus: true) }

  func commitQuickNoteOnFocusLoss() { commitCapture(refocus: false) }

  private func commitCapture(refocus: Bool) {
    guard !isCommittingCapture else { return }
    draftSaveTask?.cancel()
    let body = quickNoteDraft
    let revision = draftRevision
    let hasImages = captureHasImages || !pendingImages.isEmpty || !snapshot.draftAttachments.isEmpty
    guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasImages else {
      enqueueCapture { [repository] in try? await repository.clearDraft(revision: revision) }
      return
    }
    isCommittingCapture = true
    enqueueCapture { [self] in
      defer { isCommittingCapture = false }
      do {
        // Retry any failed import before committing; never clear failed content.
        for batch in pendingImages {
          try await repository.addImages(batch.data, to: .draft(revision: revision, body: body))
          pendingImages.removeAll { $0.id == batch.id }
          pendingCaptureImageCount -= batch.data.count
        }
        _ = try await repository.commitDraft(body: body, revision: revision)
        quickNoteDraft = ""
        draftRevision = UUID()
        snapshot.draftAttachments = []
        captureHasImages = false
        if refocus { requestQuickNoteFocus() }
      } catch { errorMessage = error.localizedDescription }
    }
  }

  private func performWorkspaceWrite(_ operation: @escaping @MainActor () async -> Void) {
    let id = UUID()
    workspaceWrites[id] = Task { [self] in
      await operation()
      workspaceWrites[id] = nil
    }
  }

  func flushPendingWrites() async -> Bool {
    commitQuickNoteOnFocusLoss()
    await captureTask?.value
    for write in Array(workspaceWrites.values) { await write.value }
    return !isCommittingCapture && pendingImages.isEmpty
      && quickNoteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func createMainTask() {
    guard isCreatingTask, !isSubmittingNewTask else { return }
    guard let effort = newTaskEffort else { return }
    let title = newTaskTitle
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    isSubmittingNewTask = true
    performWorkspaceWrite { [weak self, repository] in
      do {
        _ = try await repository.createMainTask(title: title, effort: effort)
        self?.newTaskTitle = ""
        self?.newTaskEffort = nil
        self?.isCreatingTask = false
        self?.isSelectingNewTaskEffort = false
        self?.isSubmittingNewTask = false
      } catch {
        self?.isSubmittingNewTask = false
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.completeMainTask(id: id) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteMainTask(_ id: UUID) {
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.reorderMainTasks(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func createStep(mainTaskID: UUID, title: String) {
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.reorderSteps(mainTaskID: mainTaskID, ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func updateNoteTitle(id: UUID, title: String?) {
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.updateNoteTitle(id: id, title: title) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func updateNoteBody(id: UUID, body: String) {
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.updateNoteBody(id: id, body: body) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func deleteNote(_ id: UUID) {
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
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
    performWorkspaceWrite { [weak self, repository] in
      do { try await repository.reorderQuickNotes(ids: ids) } catch {
        self?.errorMessage = error.localizedDescription
      }
    }
  }

  func moveQuickNote(_ noteID: UUID, to taskID: UUID) {
    performWorkspaceWrite { [weak self, repository] in
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
        captureHasImages = !newSnapshot.draftAttachments.isEmpty
      }
    }
  }

  private func scheduleDraftSave(body: String, revision: UUID) {
    draftSaveTask?.cancel()
    draftSaveTask = Task { [weak self, repository] in
      do {
        try await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        self?.enqueueCapture { [weak self, repository] in
          do { try await repository.saveDraft(body: body, revision: revision) }
          catch { self?.errorMessage = error.localizedDescription }
        }
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
