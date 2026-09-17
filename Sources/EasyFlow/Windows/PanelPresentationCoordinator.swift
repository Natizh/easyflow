import AppKit
import SwiftUI

@MainActor
final class PanelPresentationCoordinator {
  var onPointerMoved: ((CGPoint) -> Void)?
  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?
  var onSettingsPresentationChanged: ((Bool) -> Void)?
  var onPanelSideChanged: ((PanelSide) -> Void)?
  var panelSide: PanelSide { viewModel.panelSide }
  private var settingsController: SettingsWindowController!
  private let previewController = ImagePreviewWindowController()
  private weak var auxiliaryOrigin: NSWindow?
  private var mainGeneration = 0
  private var secondaryGeneration = 0

  private let activationPanel = ActivationEdgePanel()
  private let mainPanel = OverlayPanel()
  private let secondaryPanel = OverlayPanel()
  private let viewModel: AppShellViewModel
  private var previousApplication: NSRunningApplication?

  private let activationTrackingView = PointerTrackingView()
  private let mainHostingView: PointerTrackingHostingView<MainPanelView>
  private let secondaryHostingView: PointerTrackingHostingView<SecondaryPanelView>
  private var currentLayout: PanelLayout?

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
    mainHostingView.onTaskHover = { [weak viewModel] taskID in
      viewModel?.routedTaskHover(taskID)
    }
    mainHostingView.onQuickNotesHover = { [weak viewModel] in
      viewModel?.routedQuickNotesHover()
    }
    mainHostingView.onSecondaryCollapseStrip = { [weak viewModel] in
      viewModel?.routedSecondaryCollapseStrip()
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
    settingsController.close()
    previewController.close()
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

  func showMain(layout: PanelLayout) {
    mainGeneration += 1
    capturePreviousApplicationIfNeeded()
    currentLayout = layout
    activationPanel.setFrame(layout.activationFrame, display: true)

    NSApplication.shared.activate(ignoringOtherApps: true)
    let wasVisible = mainPanel.isVisible
    if !wasVisible {
      mainPanel.setFrame(layout.mainHiddenFrame, display: false)
      mainPanel.alphaValue = 0
    }
    mainPanel.orderFrontRegardless()
    mainPanel.makeKey()
    animate(duration: 0.22) {
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
    secondaryGeneration += 1
    let generation = secondaryGeneration
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
    let generation = secondaryGeneration
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
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
    mainGeneration += 1
    secondaryGeneration += 1
    let generation = mainGeneration
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
    viewModel.commitQuickNoteOnFocusLoss()
    secondaryPanel.orderOut(nil)
    viewModel.secondaryContext = nil
    guard mainPanel.isVisible, let currentLayout else {
      if restoreFocus { restorePreviousApplication() } else { previousApplication = nil }
      return
    }
    animate(duration: 0.18) {
      self.mainPanel.animator().setFrame(currentLayout.mainHiddenFrame, display: true)
      self.mainPanel.animator().alphaValue = 0
    } completion: {
      guard self.mainGeneration == generation else { return }
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

  func prepareToTerminate() async -> Bool {
    mainPanel.makeFirstResponder(nil)
    secondaryPanel.makeFirstResponder(nil)
    NotificationCenter.default.post(name: .easyFlowFlushEditors, object: nil)
    await Task.yield()
    return await viewModel.flushPendingWrites()
  }

  private func auxiliaryClosed() {
    let stillOpen = settingsController.window?.isVisible == true || previewController.window?.isVisible == true
    if !stillOpen { (auxiliaryOrigin ?? mainPanel).makeKey() }
    // windowWillClose is called before isVisible flips; re-evaluate next turn.
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let open = self.settingsController.window?.isVisible == true || self.previewController.window?.isVisible == true
      if !open { (self.auxiliaryOrigin ?? self.mainPanel).makeKey() }
      self.onSettingsPresentationChanged?(open)
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

  private static func contextLabel(_ context: SecondaryPanelContext) -> String {
    switch context {
    case .quickNotes: "quickNotes"
    case .task(let id): "task:\(id.uuidString)"
    }
  }
}
