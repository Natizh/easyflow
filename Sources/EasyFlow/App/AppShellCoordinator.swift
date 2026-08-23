import AppKit

@MainActor
final class AppShellCoordinator {
  private var stateMachine: PanelStateMachine
  private let screenConfigurationMonitor: ScreenConfigurationMonitor
  private let panelPresenter: PanelPresentationCoordinator

  private var timerTasks: [PanelTimer: Task<Void, Never>] = [:]
  private var layout: PanelLayout?
  private var lastPointerRegion: PointerRegion?
  private var settingsIsPresented = false

  init(
    repository: WorkspaceRepository,
    timing: PanelTiming = PanelTiming(),
    sizing: PanelSizing = PanelSizing()
  ) {
    stateMachine = PanelStateMachine(timing: timing)
    screenConfigurationMonitor = ScreenConfigurationMonitor()
    panelPresenter = PanelPresentationCoordinator(repository: repository)
    self.sizing = sizing
  }

  private let sizing: PanelSizing

  func start() {
    panelPresenter.onInteraction = { [weak self] in
      self?.process(.userInteracted)
    }
    panelPresenter.onSecondaryRequested = { [weak self] context in
      self?.process(.requestSecondary(context))
    }
    panelPresenter.onSecondaryCleared = { [weak self] in
      self?.process(.clearSecondary)
    }
    panelPresenter.onSettingsPresentationChanged = { [weak self] isPresented in
      guard let self else { return }
      self.settingsIsPresented = isPresented
      if isPresented {
        self.process(.userInteracted)
      } else {
        self.lastPointerRegion = nil
        self.pointerMoved(to: NSEvent.mouseLocation)
      }
    }

    panelPresenter.onPointerMoved = { [weak self] point in
      self?.pointerMoved(to: point)
    }
    screenConfigurationMonitor.onScreenConfigurationChanged = { [weak self] in
      self?.screenConfigurationChanged()
    }

    refreshLayout()
    if let layout {
      panelPresenter.start(layout: layout)
    }
    screenConfigurationMonitor.start()
    pointerMoved(to: NSEvent.mouseLocation)
  }

  func stop() {
    screenConfigurationMonitor.stop()
    for task in timerTasks.values {
      task.cancel()
    }
    timerTasks.removeAll()
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

  private func refreshLayout() {
    guard let display = DisplayGeometry.rightmostScreen() else {
      layout = nil
      return
    }
    layout = PanelLayout(display: display, sizing: sizing)
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
    }
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
