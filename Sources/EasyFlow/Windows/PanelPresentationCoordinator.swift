import AppKit
import SwiftUI

struct FocusRestorationSession: Equatable, Sendable {
  enum State: Equatable, Sendable {
    case idle
    case eligible
    case invalidatedBySpaceChange
  }

  private(set) var state: State = .idle

  mutating func begin() {
    state = .eligible
  }

  mutating func activeSpaceChanged() {
    guard state == .eligible else { return }
    state = .invalidatedBySpaceChange
  }

  mutating func end(restoreRequested: Bool, stillOwnsActivation: Bool = true) -> Bool {
    defer { state = .idle }
    return restoreRequested && stillOwnsActivation && state == .eligible
  }
}

@MainActor
final class PanelPresentationCoordinator {
  var onPointerNavigation: (() -> Void)?
  var onKeyboardNavigation: (() -> Void)?
  var onDismissWorkspace: (() -> Void)?
  var onExplicitSecondaryCleared: (() -> Void)?
  var onExplicitSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onPointerMoved: ((CGPoint) -> Void)?
  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?
  var onSettingsPresentationChanged: ((Bool) -> Void)?
  var onPanelSideChanged: ((PanelSide) -> Void)?
  var onReminderBannerClicked: ((UUID) -> Bool)?
  var onWorkspaceSnapshotChanged: ((WorkspaceSnapshot) -> Void)?
  var panelSide: PanelSide { viewModel.panelSide }
  private var settingsController: SettingsWindowController!
  private let previewController = ImagePreviewWindowController()
  private weak var auxiliaryOrigin: NSWindow?
  private var keyboardNavigationIsActive = false
  private var mainGeneration = 0
  private var secondaryGeneration = 0

  private let activationPanel = ActivationEdgePanel()
  private let mainPanel = OverlayPanel()
  private let secondaryPanel = OverlayPanel()
  private let reminderBannerPanel = ReminderBannerPanel()
  private let viewModel: AppShellViewModel
  private var previousApplication: NSRunningApplication?
  private var focusRestorationSession = FocusRestorationSession()

  private let activationTrackingView = PointerTrackingView()
  private let mainHostingView: PointerTrackingHostingView<MainPanelView>
  private let secondaryHostingView: PointerTrackingHostingView<SecondaryPanelView>
  private var currentLayout: PanelLayout?
  private var reminderBannerGeneration = 0
  private var reminderBannerTaskID: UUID?
  private var reminderBannerDismissTask: Task<Void, Never>?

  static let secondaryOpenAnimationDuration: TimeInterval = 0.28
  static let secondaryCloseAnimationDuration: TimeInterval = 0.35

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
    secondaryHostingView.isFlipped = true

    viewModel.onInteraction = { [weak self] in
      self?.onInteraction?()
    }
    viewModel.onSecondaryRequested = { [weak self] context in
      self?.onSecondaryRequested?(context)
    }
    viewModel.onSecondaryCleared = { [weak self] in
      self?.onSecondaryCleared?()
    }
    settingsController = SettingsWindowController(model: viewModel)
    settingsController.onClose = { [weak self] in
      guard let self else { return }
      self.viewModel.isSettingsPresented = false
      self.auxiliaryClosed()
    }
    previewController.onClose = { [weak self] in self?.auxiliaryClosed() }
    viewModel.onSettingsPresentationChanged = { [weak self] isPresented in
      guard let self else { return }
      if isPresented, let screen = self.mainPanel.screen ?? NSScreen.main {
        self.auxiliaryOrigin = self.mainPanel
        self.onSettingsPresentationChanged?(true)
        self.settingsController.present(on: screen)
      } else if self.settingsController.window?.isVisible == true {
        self.settingsController.close()
      }
    }
    viewModel.onWorkspaceSnapshotChanged = { [weak self] snapshot in
      guard let self else { return }
      if let taskID = self.viewModel.secondaryContext?.taskID,
        !snapshot.activeTasks.contains(where: { $0.id == taskID }) {
        self.onExplicitSecondaryCleared?()
      }
      self.onWorkspaceSnapshotChanged?(snapshot)
    }
    viewModel.onPanelSideChanged = { [weak self] side in self?.onPanelSideChanged?(side) }
    viewModel.onImagePreview = { [weak self] attachment in self?.preview(attachment) }
    viewModel.onTaskRowsChanged = { [weak mainHostingView] rows in
      mainHostingView?.updateTaskRows(rows)
    }
    viewModel.onQuickNotesFrameChanged = { [weak mainHostingView] frame in
      mainHostingView?.updateQuickNotesFrame(frame)
    }
    viewModel.onSecondaryCollapseStripFrameChanged = { [weak mainHostingView] frame in
      mainHostingView?.updateSecondaryCollapseStripFrame(frame)
    }
    viewModel.onQuickNoteRowsChanged = { [weak mainHostingView] rows in
      mainHostingView?.updateQuickNoteRows(rows)
    }
    viewModel.onStepRowsChanged = { [weak secondaryHostingView] rows in
      secondaryHostingView?.updateStepRows(rows)
    }
    viewModel.onStepExclusionsChanged = { [weak secondaryHostingView] exclusions in
      secondaryHostingView?.updateStepExclusions(exclusions)
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
    mainHostingView.onTaskHover = { [weak self] taskID in
      guard let self, !self.keyboardNavigationIsActive else { return }
      self.viewModel.routedTaskHover(taskID)
    }
    mainHostingView.onQuickNotesHover = { [weak self] in
      guard let self, !self.keyboardNavigationIsActive else { return }
      self.viewModel.routedQuickNotesHover()
    }
    mainHostingView.onSecondaryCollapseStrip = { [weak self] in
      guard let self, !self.keyboardNavigationIsActive else { return }
      self.viewModel.routedSecondaryCollapseStrip()
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
    mainHostingView.onNoteDragChanged = { [weak viewModel] noteID, insertion, target in
      viewModel?.routedNoteDragChanged(
        noteID: noteID,
        insertionIndex: insertion,
        taskTargetID: target
      )
    }
    mainHostingView.onNoteDragCommitted = { [weak viewModel] noteID, insertion, target in
      viewModel?.routedNoteDragCommitted(
        noteID: noteID,
        insertionIndex: insertion,
        taskTargetID: target
      )
    }
    mainHostingView.onNoteDragCancelled = { [weak viewModel] in
      viewModel?.routedNoteDragCancelled()
    }
    secondaryHostingView.onStepDragChanged = { [weak viewModel] stepID, insertion in
      viewModel?.routedStepDragChanged(stepID: stepID, insertionIndex: insertion)
    }
    secondaryHostingView.onStepDragCommitted = { [weak viewModel] stepID, insertion in
      viewModel?.routedStepDragCommitted(stepID: stepID, insertionIndex: insertion)
    }
    secondaryHostingView.onStepDragCancelled = { [weak viewModel] in
      viewModel?.routedStepDragCancelled()
    }

    mainPanel.title = "EasyFlow Main"
    secondaryPanel.title = "EasyFlow Details"
    mainPanel.onPointerInteraction = { [weak self] in self?.beginPointerNavigation() }
    secondaryPanel.onPointerInteraction = { [weak self] in self?.beginPointerNavigation() }
    mainHostingView.onTaskActivated = { [weak viewModel] id in viewModel?.openSecondaryFromControl(.task(id: id)) }
    mainHostingView.onQuickNotesActivated = { [weak viewModel] in viewModel?.openSecondaryFromControl(.quickNotes) }
    mainPanel.onKeyboardInteraction = { [weak self] in self?.beginKeyboardNavigation() }
    secondaryPanel.onKeyboardInteraction = { [weak self] in self?.beginKeyboardNavigation() }
    mainPanel.onDismiss = { [weak self] in self?.onDismissWorkspace?() }
    secondaryPanel.onDismiss = { [weak self] in self?.returnToMain() }
    viewModel.onReturnToMain = { [weak self] in self?.returnToMain() }
    viewModel.onKeyboardSecondaryRequested = { [weak self] context in
      guard let self else { return }
      self.onExplicitSecondaryRequested?(context)
      self.focusSecondary()
    }
    activationTrackingView.setAccessibilityHidden(true)
    activationPanel.contentView = activationTrackingView
    mainPanel.contentView = mainHostingView
    secondaryPanel.contentView = secondaryHostingView
    EasyFlowOverlayWindowConfiguration.maskRoundedContent(mainHostingView)
    EasyFlowOverlayWindowConfiguration.maskRoundedContent(secondaryHostingView)
  }

  func start(layout: PanelLayout) {
    viewModel.start()
    apply(layout: layout)
    activationPanel.orderFrontRegardless()
  }

  func stop() {
    settingsController.close()
    previewController.close()
    hideReminderBanner()
    viewModel.stop()
    hideAll(restoreFocus: false)
    activationPanel.orderOut(nil)
  }

  func apply(layout: PanelLayout) {
    currentLayout = layout
    mainGeneration += 1
    secondaryGeneration += 1
    mainHostingView.resetRouting(side: layout.side)
    secondaryHostingView.resetRouting(side: layout.side)
    activationPanel.setFrame(layout.activationFrame, display: true)
    if !activationPanel.isVisible {
      activationPanel.orderFrontRegardless()
    }
    mainPanel.alphaValue = 1
    secondaryPanel.alphaValue = 1
    mainPanel.setFrame(layout.mainFrame, display: mainPanel.isVisible)
    secondaryPanel.setFrame(
      layout.secondaryFrame,
      display: secondaryPanel.isVisible
    )
  }

  func reconcileActiveSpace(
    _ presentation: PanelSpacePresentation,
    layout: PanelLayout
  ) {
    keyboardNavigationIsActive = false
    focusRestorationSession.activeSpaceChanged()
    previousApplication = nil
    mainGeneration += 1
    secondaryGeneration += 1
    prepareForSupersedingAnimation(on: mainPanel)
    prepareForSupersedingAnimation(on: secondaryPanel)
    currentLayout = layout
    mainHostingView.resetRouting(side: layout.side)
    secondaryHostingView.resetRouting(side: layout.side)

    activationPanel.setFrame(layout.activationFrame, display: true)
    activationPanel.orderFrontRegardless()

    // Keep native responder/selection on a visible current-Space surface. Never
    // activate the app merely because the user changed Spaces.
    for panel in [mainPanel, secondaryPanel] {
      if !panel.isOnActiveSpace { panel.retireFromInteraction() }
      panel.recalculateKeyViewLoop()
    }
    switch presentation {
    case .hidden:
      secondaryPanel.retireFromInteraction()
      secondaryPanel.orderOut(nil)
      mainPanel.retireFromInteraction()
      mainPanel.orderOut(nil)
      mainPanel.alphaValue = 1
      secondaryPanel.alphaValue = 1
      viewModel.secondaryContext = nil
    case .main:
      secondaryPanel.retireFromInteraction()
      secondaryPanel.orderOut(nil)
      secondaryPanel.alphaValue = 1
      viewModel.secondaryContext = nil
      mainPanel.setFrame(layout.mainFrame, display: true)
      mainPanel.alphaValue = 1
      mainPanel.exposeForInteraction()
      mainPanel.orderFrontRegardless()
    case .mainAndSecondary(let context):
      viewModel.secondaryContext = context
      mainPanel.setFrame(layout.mainFrame, display: true)
      secondaryPanel.setFrame(layout.secondaryFrame, display: true)
      mainPanel.alphaValue = 1
      secondaryPanel.alphaValue = 1
      mainPanel.exposeForInteraction()
      mainPanel.orderFrontRegardless()
      secondaryPanel.exposeForInteraction()
      secondaryPanel.orderFrontRegardless()
      secondaryPanel.order(.above, relativeTo: mainPanel.windowNumber)
    }

    if reminderBannerPanel.isVisible {
      reminderBannerPanel.orderFrontRegardless()
    }
    if settingsController.window?.isVisible == true {
      settingsController.window?.orderFrontRegardless()
    }
    if previewController.window?.isVisible == true {
      previewController.window?.orderFrontRegardless()
    }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      for panel in [self.mainPanel, self.secondaryPanel] {
        if panel.isAvailableForFocus {
          NSAccessibility.post(element: panel, notification: .layoutChanged)
        } else {
          panel.retireFromInteraction()
        }
      }
    }
  }

  func showMain(layout: PanelLayout) {
    mainGeneration += 1
    prepareForSupersedingAnimation(on: mainPanel)
    currentLayout = layout
    activationPanel.setFrame(layout.activationFrame, display: true)

    let wasVisible = mainPanel.isVisible && mainPanel.isOnActiveSpace
    if !wasVisible {
      capturePreviousApplication()
      focusRestorationSession.begin()
    }
    NSApplication.shared.activate(ignoringOtherApps: true)
    if !wasVisible {
      mainPanel.setFrame(layout.mainHiddenFrame, display: false)
      mainPanel.alphaValue = 0
    }
    mainPanel.exposeForInteraction()
    mainPanel.orderFrontRegardless()
    mainPanel.makeKey()
    animate(duration: 0.22) {
      self.mainPanel.animator().setFrame(layout.mainFrame, display: true)
      self.mainPanel.animator().alphaValue = 1
    }
  }

  func focusQuickNote() {
    guard mainPanel.isAvailableForFocus else { return }
    mainPanel.makeKey()
    DispatchQueue.main.async { [weak viewModel] in
      viewModel?.requestQuickNoteFocus()
    }
  }

  func showSecondary(context: SecondaryPanelContext, layout: PanelLayout) {
    secondaryGeneration += 1
    prepareForSupersedingAnimation(on: secondaryPanel)
    let generation = secondaryGeneration
    viewModel.secondaryContext = context
    secondaryPanel.exposeForInteraction()
    currentLayout = layout
    let intent = SecondaryPresentationIntent(layout: layout)
    assert(layout.display.frame.intersects(intent.targetFrame))
    InputDiagnostics.record(
      "showSecondary context=\(Self.contextLabel(context)) target=\(NSStringFromRect(intent.targetFrame)) level=\(secondaryPanel.level.rawValue)"
    )
    if secondaryPanel.isVisible && secondaryPanel.isOnActiveSpace {
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
    animate(duration: Self.secondaryOpenAnimationDuration) {
      self.secondaryPanel.animator().setFrame(intent.targetFrame, display: true)
      self.secondaryPanel.animator().alphaValue = intent.targetAlpha
    } completion: {
      guard self.secondaryGeneration == generation else { return }
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
    secondaryGeneration += 1
    prepareForSupersedingAnimation(on: secondaryPanel)
    let generation = secondaryGeneration
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
    let hadFocus = secondaryPanel.isKeyWindow
    secondaryPanel.retireFromInteraction()
    if hadFocus, mainPanel.isAvailableForFocus { mainPanel.makeKey() }
    guard secondaryPanel.isVisible, let currentLayout else {
      viewModel.secondaryContext = nil
      return
    }
    animate(duration: Self.secondaryCloseAnimationDuration) {
      self.secondaryPanel.animator().setFrame(
        currentLayout.secondaryHiddenFrame,
        display: true
      )
      self.secondaryPanel.animator().alphaValue = 0
    } completion: {
      guard self.secondaryGeneration == generation else { return }
      self.secondaryPanel.orderOut(nil)
      self.viewModel.secondaryContext = nil
    }
  }

  func hideAll(restoreFocus: Bool) {
    keyboardNavigationIsActive = false
    mainGeneration += 1
    secondaryGeneration += 1
    prepareForSupersedingAnimation(on: mainPanel)
    prepareForSupersedingAnimation(on: secondaryPanel)
    let generation = mainGeneration
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
    viewModel.commitQuickNoteOnFocusLoss()
    secondaryPanel.retireFromInteraction()
    mainPanel.retireFromInteraction()
    secondaryPanel.orderOut(nil)
    viewModel.secondaryContext = nil
    guard mainPanel.isVisible, let currentLayout else {
      if restoreFocus { restorePreviousApplication() } else { discardPreviousApplication() }
      return
    }
    animate(duration: 0.18) {
      self.mainPanel.animator().setFrame(currentLayout.mainHiddenFrame, display: true)
      self.mainPanel.animator().alphaValue = 0
    } completion: {
      guard self.mainGeneration == generation else { return }
      self.mainPanel.orderOut(nil)
      if restoreFocus {
        self.restorePreviousApplication()
      } else {
        self.discardPreviousApplication()
      }
    }
  }

  func showReminderBanner(task: MainTask, layout: PanelLayout) {
    reminderBannerGeneration += 1
    reminderBannerDismissTask?.cancel()
    reminderBannerTaskID = task.id
    let frame = reminderBannerFrame(layout: layout)
    let hostingView = NSHostingView(
      rootView: ReminderBannerView(
        title: task.title,
        appearanceMode: viewModel.appearanceMode,
        action: { [weak self] in self?.clickReminderBanner() }
      )
    )
    reminderBannerPanel.presentContent(title: task.title, view: hostingView)
    reminderBannerPanel.setFrame(frame.offsetBy(dx: 0, dy: 10), display: false)
    reminderBannerPanel.alphaValue = 0
    reminderBannerPanel.orderFrontRegardless()
    animate(duration: 0.18) {
      self.reminderBannerPanel.animator().setFrame(frame, display: true)
      self.reminderBannerPanel.animator().alphaValue = 1
    }
    reminderBannerDismissTask = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .seconds(6)) } catch { return }
      self?.hideReminderBanner()
    }
  }

  func hideReminderBanner() {
    reminderBannerGeneration += 1
    let generation = reminderBannerGeneration
    reminderBannerDismissTask?.cancel()
    reminderBannerDismissTask = nil
    reminderBannerTaskID = nil
    prepareForSupersedingAnimation(on: reminderBannerPanel)
    reminderBannerPanel.retireContent()
    guard reminderBannerPanel.isVisible else { return }
    animate(duration: 0.14) {
      self.reminderBannerPanel.animator().alphaValue = 0
    } completion: {
      guard self.reminderBannerGeneration == generation else { return }
      self.reminderBannerPanel.orderOut(nil)
      self.reminderBannerPanel.alphaValue = 1
    }
  }

  private func clickReminderBanner() {
    guard let taskID = reminderBannerTaskID else { return }
    hideReminderBanner()
    guard onReminderBannerClicked?(taskID) == true else { return }
    beginKeyboardNavigation()
    focusSecondary()
  }

  private func reminderBannerFrame(layout: PanelLayout) -> CGRect {
    let size = CGSize(width: 320, height: 64)
    let horizontalInset: CGFloat = 20
    let x =
      layout.side == .right
      ? min(layout.display.frame.maxX - size.width - horizontalInset, layout.mainFrame.minX)
      : max(layout.display.frame.minX + horizontalInset, layout.mainFrame.minX)
    let y = layout.display.frame.maxY - size.height - 48
    return CGRect(x: x, y: y, width: size.width, height: size.height)
  }

  private func capturePreviousApplication() {
    let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    let candidate = NSWorkspace.shared.frontmostApplication
    previousApplication =
      candidate?.processIdentifier == currentProcessIdentifier
      ? nil
      : candidate
  }

  private func restorePreviousApplication() {
    defer { previousApplication = nil }
    let ownsActivation = NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
    guard focusRestorationSession.end(restoreRequested: true, stillOwnsActivation: ownsActivation) else { return }
    guard let previousApplication, !previousApplication.isTerminated else { return }
    previousApplication.activate(options: [])
  }

  private func discardPreviousApplication() {
    previousApplication = nil
    _ = focusRestorationSession.end(restoreRequested: false)
  }

  func prepareToTerminate() async -> Bool {
    mainPanel.makeFirstResponder(nil)
    secondaryPanel.makeFirstResponder(nil)
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
    await Task.yield()
    return await viewModel.flushPendingWrites()
  }

  private func auxiliaryClosed() {
    // windowWillClose precedes isVisible changing. Transfer only after closing,
    // and only while EasyFlow still owns activation on the current Space.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let open = self.settingsController.window?.isVisible == true || self.previewController.window?.isVisible == true
      if !open, NSApp.isActive {
        let origin = self.auxiliaryOrigin as? OverlayPanel
        if let target = origin?.isAvailableForFocus == true ? origin :
          (self.mainPanel.isAvailableForFocus ? self.mainPanel : nil) {
          target.makeKey()
        }
      }
      self.onSettingsPresentationChanged?(open)
    }
  }

  private func beginPointerNavigation() {
    guard keyboardNavigationIsActive else { return }
    keyboardNavigationIsActive = false
    mainHostingView.resetRouting(side: viewModel.panelSide)
    secondaryHostingView.resetRouting(side: viewModel.panelSide)
    onPointerNavigation?()
  }

  private func beginKeyboardNavigation() {
    keyboardNavigationIsActive = true
    onKeyboardNavigation?()
  }

  func focusSecondary() {
    beginKeyboardNavigation()
    DispatchQueue.main.async { [weak self] in
      guard let self, self.secondaryPanel.isAvailableForFocus, NSApp.isActive else { return }
      self.secondaryPanel.makeKey()
      self.secondaryPanel.makeFirstResponder(nil)
      self.secondaryPanel.selectNextKeyView(nil)
    }
  }

  private func returnToMain() {
    beginKeyboardNavigation()
    // Explicit dismissal must not be vetoed by the pointer traversal guard.
    onExplicitSecondaryCleared?()
    if mainPanel.isAvailableForFocus {
      mainPanel.makeKey()
      if let responder = mainPanel.firstResponder as? NSView, responder.window === mainPanel {
        // The originating Main control remains the native first responder.
      } else {
        mainPanel.selectNextKeyView(nil)
      }
    }
  }

  private func preview(_ attachment: NoteAttachment) {
    let origin = NSApp.keyWindow ?? secondaryPanel
    guard let screen = origin.screen ?? mainPanel.screen ?? NSScreen.main else { return }
    let url = viewModel.attachmentDirectory.appendingPathComponent(attachment.filename)
    auxiliaryOrigin = origin
    onSettingsPresentationChanged?(true)
    Task { [weak self] in
      let data = await Task.detached { try? Data(contentsOf: url) }.value
      guard let self else { return }
      let image = data.flatMap(NSImage.init(data:))
      guard let image else {
        self.viewModel.errorMessage = AttachmentError.unavailable.localizedDescription
        self.auxiliaryClosed()
        return
      }
      self.previewController.present(image: image,
        pixels: CGSize(width: attachment.pixelWidth, height: attachment.pixelHeight), on: screen)
    }
  }

  private func animate(
    duration: TimeInterval,
    changes: () -> Void,
    completion: (@MainActor @Sendable () -> Void)? = nil
  ) {
    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
      changes()
      completion?()
      return
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      changes()
    } completionHandler: {
      Task { @MainActor in completion?() }
    }
  }

  private func prepareForSupersedingAnimation(on window: NSWindow) {
    // NSWindow animator() does not expose a reliable public cancellation hook.
    // Presentation generations are the correctness guard for stale completions;
    // this only clears hosted-view layer animations before the next explicit
    // frame/alpha write starts a superseding transition.
    window.contentView?.layer?.removeAllAnimations()
  }

  private static func contextLabel(_ context: SecondaryPanelContext) -> String {
    switch context {
    case .quickNotes: "quickNotes"
    case .task(let id): "task:\(id.uuidString)"
    }
  }
}
