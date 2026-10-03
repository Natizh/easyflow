import AppKit

@MainActor
final class AppShellCoordinator {
  private var stateMachine: PanelStateMachine
  private let screenConfigurationMonitor: ScreenConfigurationMonitor
  private let panelPresenter: PanelPresentationCoordinator

  private var deactivationObserver: NSObjectProtocol?
  private var timerTasks: [PanelTimer: Task<Void, Never>] = [:]
  private var reminderTimerTask: Task<Void, Never>?
  private var layout: PanelLayout?
  private var lastPointerRegion: PointerRegion?
  private var settingsIsPresented = false
  private var latestSnapshot = WorkspaceSnapshot.empty
  private var reminderScheduleState: ReminderScheduleState?

  init(
    repository: WorkspaceRepository,
    remindersSync: RemindersSyncCoordinator,
    timing: PanelTiming = PanelTiming(),
    sizing: PanelSizing = PanelSizing()
  ) {
    stateMachine = PanelStateMachine(timing: timing)
    screenConfigurationMonitor = ScreenConfigurationMonitor()
    panelPresenter = PanelPresentationCoordinator(
      repository: repository,
      remindersSync: remindersSync
    )
    self.sizing = sizing
  }

  private let sizing: PanelSizing

  func start() {
    deactivationObserver = NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.process(.applicationDeactivated) }
    }
    panelPresenter.onPointerNavigation = { [weak self] in self?.process(.pointerNavigation) }
    panelPresenter.onKeyboardNavigation = { [weak self] in self?.process(.keyboardNavigation) }
    panelPresenter.onDismissWorkspace = { [weak self] in self?.process(.dismissWorkspace) }
    panelPresenter.onExplicitSecondaryCleared = { [weak self] in self?.process(.clearSecondary) }
    panelPresenter.onExplicitSecondaryRequested = { [weak self] context in
      self?.process(.openFromReminder(context))
      self?.process(.keyboardNavigation)
    }
    panelPresenter.onInteraction = { [weak self] in
      self?.process(.userInteracted)
    }
    panelPresenter.onSecondaryRequested = { [weak self] context in
      self?.process(.requestSecondary(context))
    }
    panelPresenter.onSecondaryCleared = { [weak self] in
      self?.clearSecondaryIfCurrentPointerAllows()
    }
    panelPresenter.onSettingsPresentationChanged = { [weak self] isPresented in
      guard let self else { return }
      self.settingsIsPresented = isPresented
      self.process(.auxiliaryPresentationChanged(isPresented))
      if isPresented {
        self.process(.userInteracted)
      } else {
        self.lastPointerRegion = nil
        self.pointerMoved(to: NSEvent.mouseLocation)
      }
    }

    panelPresenter.onWorkspaceSnapshotChanged = { [weak self] snapshot in
      guard let self else { return }
      self.latestSnapshot = snapshot
      self.updateReminderSchedule(from: snapshot)
    }

    panelPresenter.onReminderBannerClicked = { [weak self] taskID in
      self?.openTaskFromReminder(taskID) ?? false
    }

    panelPresenter.onPanelSideChanged = { [weak self] _ in
      guard let self else { return }
      for timer in Array(self.timerTasks.keys) { self.cancel(timer: timer) }
      self.stateMachine = self.stateMachine.stabilized(auxiliaryIsPresented: self.settingsIsPresented)
      self.screenConfigurationChanged()
    }
    panelPresenter.onPointerMoved = { [weak self] point in
      self?.pointerMoved(to: point)
    }
    screenConfigurationMonitor.onScreenConfigurationChanged = { [weak self] in
      self?.screenConfigurationChanged()
    }
    screenConfigurationMonitor.onActiveSpaceChanged = { [weak self] in
      self?.activeSpaceChanged()
    }

    refreshLayout()
    if let layout {
      panelPresenter.start(layout: layout)
    }
    screenConfigurationMonitor.start()
    pointerMoved(to: NSEvent.mouseLocation)
  }

  func prepareToTerminate() async -> Bool {
    await panelPresenter.prepareToTerminate()
  }

  func stop() {
    if let deactivationObserver { NotificationCenter.default.removeObserver(deactivationObserver) }
    deactivationObserver = nil
    screenConfigurationMonitor.stop()
    for task in timerTasks.values {
      task.cancel()
    }
    timerTasks.removeAll()
    reminderTimerTask?.cancel()
    reminderTimerTask = nil
    reminderScheduleState = nil
    panelPresenter.stop()
  }

  private func screenConfigurationChanged() {
    lastPointerRegion = nil
    refreshLayout()
    if let layout {
      panelPresenter.apply(layout: layout)
    }
    pointerMoved(to: NSEvent.mouseLocation)
  }

  private func activeSpaceChanged() {
    lastPointerRegion = nil
    refreshLayout()
    process(.activeSpaceChanged)
    // AppKit finishes assigning windows to the new Space on the next run-loop
    // turn. Re-evaluate the pointer only after window ordering is reconciled.
    DispatchQueue.main.async { [weak self] in
      self?.pointerMoved(to: NSEvent.mouseLocation)
    }
  }

  private func refreshLayout() {
    guard let display = DisplayGeometry.rightmostScreen(side: panelPresenter.panelSide) else {
      layout = nil
      return
    }
    layout = PanelLayout(display: display, sizing: sizing, side: panelPresenter.panelSide)
  }

  private func pointerMoved(to point: CGPoint) {
    guard let layout else { return }
    let region = layout.pointerRegion(
      at: point,
      secondaryIsVisible: stateMachine.state.isSecondaryPresented
    )
    if settingsIsPresented, region == .outside {
      return
    }
    guard region != lastPointerRegion else { return }

    lastPointerRegion = region
    process(.pointerChanged(region))
  }

  private func process(_ event: PanelEvent) {
    let commands = stateMachine.handle(event)
    commands.forEach(execute)
  }

  private func clearSecondaryIfCurrentPointerAllows() {
    guard let layout else { return }
    let region = layout.pointerRegion(
      at: NSEvent.mouseLocation,
      secondaryIsVisible: stateMachine.state.isSecondaryPresented
    )
    if !Self.shouldApplySecondaryClear(latestPointerRegion: region) {
      lastPointerRegion = region
      process(.pointerChanged(region))
      return
    }
    process(.clearSecondary)
  }

  nonisolated static func shouldApplySecondaryClear(latestPointerRegion region: PointerRegion)
    -> Bool
  {
    region != .secondary && region != .bridge
  }

  private func execute(_ command: PanelCommand) {
    switch command {
    case .schedule(let timer, let delay):
      schedule(timer: timer, after: delay)
    case .cancel(let timer):
      cancel(timer: timer)
    case .showMain:
      guard let layout else { return }
      panelPresenter.showMain(layout: layout)
    case .focusQuickNote:
      panelPresenter.focusQuickNote()
    case .hideMain(let restoreFocus):
      panelPresenter.hideAll(restoreFocus: restoreFocus)
    case .showSecondary(let context):
      guard let layout else { return }
      panelPresenter.showSecondary(context: context, layout: layout)
    case .hideSecondary:
      panelPresenter.hideSecondary()
    case .reconcileActiveSpace(let presentation):
      guard let layout else { return }
      panelPresenter.reconcileActiveSpace(presentation, layout: layout)
    }
  }

  private func updateReminderSchedule(from snapshot: WorkspaceSnapshot) {
    let now = Date()
    let current = ReminderScheduleState(
      settings: snapshot.reminderSettings,
      activeTasks: snapshot.activeTasks
    )
    let action = ReminderSchedulePolicy.action(
      previous: reminderScheduleState,
      current: current,
      timerIsActive: reminderTimerTask != nil,
      now: now
    )
    reminderScheduleState = current
    executeReminderTimerAction(action)
  }

  private func executeReminderTimerAction(_ action: ReminderTimerAction) {
    switch action {
    case .keep:
      return
    case .cancel:
      reminderTimerTask?.cancel()
      reminderTimerTask = nil
      panelPresenter.hideReminderBanner()
    case .schedule(let delay):
      scheduleReminderTimer(after: delay)
    }
  }

  private func scheduleReminderTimer(after delay: TimeInterval) {
    reminderTimerTask?.cancel()
    reminderTimerTask = nil
    reminderTimerTask = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
      } catch { return }
      self?.fireReminderIfPossible()
    }
  }

  private func fireReminderIfPossible() {
    reminderTimerTask = nil
    let snapshot = latestSnapshot
    guard snapshot.reminderSettings.isEnabled,
      !snapshot.reminderSettings.isPaused(at: Date()),
      let task = ReminderEligibility.firstEligibleTask(in: snapshot.activeTasks),
      let layout
    else {
      updateReminderSchedule(from: snapshot)
      return
    }
    panelPresenter.showReminderBanner(task: task, layout: layout)
    updateReminderSchedule(from: snapshot)
  }

  func openWorkspace() {
    process(.openFromReminder(.quickNotes))
    process(.keyboardNavigation)
    panelPresenter.focusQuickNote()
  }

  private func openTaskFromReminder(_ taskID: UUID) -> Bool {
    guard latestSnapshot.activeTasks.contains(where: { $0.id == taskID }) else {
      panelPresenter.hideReminderBanner()
      return false
    }
    process(.openFromReminder(.task(id: taskID)))
    return true
  }

  private func schedule(timer: PanelTimer, after delay: TimeInterval) {
    cancel(timer: timer)
    let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)

    timerTasks[timer] = Task { @MainActor [weak self] in
      do {
        try await Task.sleep(nanoseconds: nanoseconds)
      } catch {
        return
      }
      guard !Task.isCancelled else { return }
      self?.timerTasks[timer] = nil
      self?.process(timer.elapsedEvent)
    }
  }

  private func cancel(timer: PanelTimer) {
    timerTasks[timer]?.cancel()
    timerTasks[timer] = nil
  }
}

extension PanelTimer {
  fileprivate var elapsedEvent: PanelEvent {
    switch self {
    case .activationDwell:
      .activationDwellElapsed
    case .secondaryDismissal:
      .secondaryDismissalElapsed
    case .mainDismissal:
      .mainDismissalElapsed
    }
  }
}
