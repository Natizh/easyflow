import AppKit
import SwiftUI

@MainActor
final class PanelPresentationCoordinator {
  var onPointerMoved: ((CGPoint) -> Void)?
  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?
  var onSettingsPresentationChanged: ((Bool) -> Void)?

  private let activationPanel = ActivationEdgePanel()
  private let mainPanel = OverlayPanel()
  private let secondaryPanel = OverlayPanel()
  private let viewModel: AppShellViewModel
  private var previousApplication: NSRunningApplication?

  private let activationTrackingView = PointerTrackingView()
  private let mainHostingView: PointerTrackingHostingView<MainPanelView>
  private let secondaryHostingView: PointerTrackingHostingView<SecondaryPanelView>
  private var currentLayout: PanelLayout?

  init(repository: WorkspaceRepository, remindersSync: RemindersSyncCoordinator) {
    viewModel = AppShellViewModel(
      repository: repository,
      remindersSync: remindersSync
    )
    mainHostingView = PointerTrackingHostingView(
      rootView: MainPanelView(model: viewModel)
    )
    secondaryHostingView = PointerTrackingHostingView(
      rootView: SecondaryPanelView(model: viewModel)
    )
    mainHostingView.isFlipped = true

    viewModel.onInteraction = { [weak self] in
      self?.onInteraction?()
    }
    viewModel.onSecondaryRequested = { [weak self] context in
      self?.onSecondaryRequested?(context)
    }
    viewModel.onSecondaryCleared = { [weak self] in
      self?.onSecondaryCleared?()
    }
    viewModel.onSettingsPresentationChanged = { [weak self] isPresented in
      self?.onSettingsPresentationChanged?(isPresented)
    }
    viewModel.onTaskRowsChanged = { [weak mainHostingView] rows in
      mainHostingView?.updateTaskRows(rows)
    }

    activationTrackingView.onPointerMoved = { [weak self] point in
      self?.onPointerMoved?(point)
    }
    mainHostingView.onPointerMoved = { [weak self] point in
      self?.onPointerMoved?(point)
    }
    secondaryHostingView.onPointerMoved = { [weak self] point in
      self?.onPointerMoved?(point)
    }
    mainHostingView.onTaskHover = { [weak viewModel] taskID in
      viewModel?.routedTaskHover(taskID)
    }
    mainHostingView.onTaskDragChanged = { [weak viewModel] taskID, insertion in
      viewModel?.routedTaskDragChanged(taskID: taskID, insertionIndex: insertion)
    }
    mainHostingView.onTaskDragCommitted = { [weak viewModel] taskID, insertion in
      viewModel?.routedTaskDragCommitted(taskID: taskID, insertionIndex: insertion)
    }
    mainHostingView.onTaskDragCancelled = { [weak viewModel] in
      viewModel?.routedTaskDragCancelled()
    }

    activationPanel.contentView = activationTrackingView
    mainPanel.contentView = mainHostingView
    secondaryPanel.contentView = secondaryHostingView
  }

  func start(layout: PanelLayout) {
    viewModel.start()
    apply(layout: layout)
    activationPanel.orderFrontRegardless()
  }

  func stop() {
    viewModel.stop()
    hideAll(restoreFocus: false)
    activationPanel.orderOut(nil)
  }

  func apply(layout: PanelLayout) {
    currentLayout = layout
    activationPanel.setFrame(layout.activationFrame, display: true)
    if !activationPanel.isVisible {
      activationPanel.orderFrontRegardless()
    }
    mainPanel.setFrame(layout.mainFrame, display: mainPanel.isVisible)
    secondaryPanel.setFrame(
      layout.secondaryFrame,
      display: secondaryPanel.isVisible
    )
  }

  func showMain(layout: PanelLayout) {
    capturePreviousApplicationIfNeeded()
    currentLayout = layout
    activationPanel.setFrame(layout.activationFrame, display: true)

    NSApplication.shared.activate(ignoringOtherApps: true)
    let wasVisible = mainPanel.isVisible
    if !wasVisible {
      mainPanel.setFrame(mainHiddenFrame(for: layout), display: false)
      mainPanel.alphaValue = 0
    }
    mainPanel.orderFrontRegardless()
    mainPanel.makeKey()
    animate(duration: 0.20) {
      self.mainPanel.animator().setFrame(layout.mainFrame, display: true)
      self.mainPanel.animator().alphaValue = 1
    }
  }

  func focusQuickNote() {
    mainPanel.makeKey()
    DispatchQueue.main.async { [weak viewModel] in
      viewModel?.requestQuickNoteFocus()
    }
  }

  func showSecondary(context: SecondaryPanelContext, layout: PanelLayout) {
    viewModel.secondaryContext = context
    currentLayout = layout
    let intent = SecondaryPresentationIntent(layout: layout)
    assert(layout.display.frame.intersects(intent.targetFrame))
    InputDiagnostics.record(
      "showSecondary context=\(Self.contextLabel(context)) target=\(NSStringFromRect(intent.targetFrame)) level=\(secondaryPanel.level.rawValue)"
    )
    if secondaryPanel.isVisible {
      secondaryPanel.alphaValue = 1
      secondaryPanel.setFrame(layout.secondaryFrame, display: true)
      secondaryPanel.orderFrontRegardless()
      secondaryPanel.order(.above, relativeTo: mainPanel.windowNumber)
      return
    }
    secondaryPanel.setFrame(intent.startFrame, display: false)
    secondaryPanel.alphaValue = intent.startAlpha
    mainPanel.orderFrontRegardless()
    secondaryPanel.orderFrontRegardless()
    secondaryPanel.order(.above, relativeTo: mainPanel.windowNumber)
    animate(duration: 0.18) {
      self.secondaryPanel.animator().setFrame(intent.targetFrame, display: true)
      self.secondaryPanel.animator().alphaValue = intent.targetAlpha
    } completion: {
      self.secondaryPanel.setFrame(intent.targetFrame, display: true)
      self.secondaryPanel.alphaValue = intent.targetAlpha
      self.secondaryPanel.order(.above, relativeTo: self.mainPanel.windowNumber)
      InputDiagnostics.record(
        "secondary visible=\(self.secondaryPanel.isVisible) frame=\(NSStringFromRect(self.secondaryPanel.frame)) alpha=\(self.secondaryPanel.alphaValue) window=\(self.secondaryPanel.windowNumber)"
      )
      assert(self.secondaryPanel.isVisible)
      assert(self.secondaryPanel.alphaValue == 1)
      assert(self.secondaryPanel.windowNumber > 0)
      assert(layout.display.frame.intersects(self.secondaryPanel.frame))
    }
  }

  func hideSecondary() {
    guard secondaryPanel.isVisible, let currentLayout else {
      viewModel.secondaryContext = nil
      return
    }
    animate(duration: 0.16) {
      self.secondaryPanel.animator().setFrame(
        self.secondaryHiddenFrame(for: currentLayout),
        display: true
      )
      self.secondaryPanel.animator().alphaValue = 0
    } completion: {
      self.secondaryPanel.orderOut(nil)
      self.viewModel.secondaryContext = nil
    }
  }

  func hideAll(restoreFocus: Bool) {
    viewModel.commitQuickNoteIfNeeded()
    secondaryPanel.orderOut(nil)
    viewModel.secondaryContext = nil
    guard mainPanel.isVisible, let currentLayout else {
      if restoreFocus { restorePreviousApplication() } else { previousApplication = nil }
      return
    }
    animate(duration: 0.16) {
      self.mainPanel.animator().setFrame(self.mainHiddenFrame(for: currentLayout), display: true)
      self.mainPanel.animator().alphaValue = 0
    } completion: {
      self.mainPanel.orderOut(nil)
      if restoreFocus { self.restorePreviousApplication() } else { self.previousApplication = nil }
    }
  }

  private func capturePreviousApplicationIfNeeded() {
    guard !mainPanel.isVisible else { return }
    let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let candidate = NSWorkspace.shared.frontmostApplication
    previousApplication =
      candidate?.processIdentifier == currentProcessIdentifier
      ? nil
      : candidate
  }

  private func restorePreviousApplication() {
    defer { previousApplication = nil }
    guard let previousApplication, !previousApplication.isTerminated else { return }
    previousApplication.activate(options: [])
  }

  private func mainHiddenFrame(for layout: PanelLayout) -> CGRect {
    layout.mainFrame.offsetBy(dx: layout.mainFrame.width + 16, dy: 0)
  }

  private func secondaryHiddenFrame(for layout: PanelLayout) -> CGRect {
    CGRect(
      x: layout.mainFrame.minX,
      y: layout.secondaryFrame.minY,
      width: layout.secondaryFrame.width,
      height: layout.secondaryFrame.height
    )
  }

  private func animate(
    duration: TimeInterval,
    changes: () -> Void,
    completion: (@MainActor @Sendable () -> Void)? = nil
  ) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      changes()
    } completionHandler: {
      Task { @MainActor in completion?() }
    }
  }

  private static func contextLabel(_ context: SecondaryPanelContext) -> String {
    switch context {
    case .quickNotes: "quickNotes"
    case .task(let id): "task:\(id.uuidString)"
    }
  }
}
