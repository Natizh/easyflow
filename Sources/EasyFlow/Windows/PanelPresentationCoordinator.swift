import AppKit
import SwiftUI

@MainActor
final class PanelPresentationCoordinator {
  var onPointerMoved: ((CGPoint) -> Void)?
  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?

  private let activationPanel = ActivationEdgePanel()
  private let mainPanel = OverlayPanel()
  private let secondaryPanel = OverlayPanel()
  private let viewModel = AppShellViewModel()
  private var previousApplication: NSRunningApplication?

  private let activationTrackingView = PointerTrackingView()
  private let mainHostingView: PointerTrackingHostingView<MainPanelView>
  private let secondaryHostingView: PointerTrackingHostingView<SecondaryPanelView>

  init() {
    mainHostingView = PointerTrackingHostingView(
      rootView: MainPanelView(model: viewModel)
    )
    secondaryHostingView = PointerTrackingHostingView(
      rootView: SecondaryPanelView(model: viewModel)
    )

    viewModel.onInteraction = { [weak self] in
      self?.onInteraction?()
    }
    viewModel.onSecondaryRequested = { [weak self] context in
      self?.onSecondaryRequested?(context)
    }
    viewModel.onSecondaryCleared = { [weak self] in
      self?.onSecondaryCleared?()
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

    activationPanel.contentView = activationTrackingView
    mainPanel.contentView = mainHostingView
    secondaryPanel.contentView = secondaryHostingView
  }

  func start(layout: PanelLayout) {
    apply(layout: layout)
    activationPanel.orderFrontRegardless()
  }

  func stop() {
    hideAll(restoreFocus: false)
    activationPanel.orderOut(nil)
  }

  func apply(layout: PanelLayout) {
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
    apply(layout: layout)

    NSApplication.shared.activate(ignoringOtherApps: true)
    mainPanel.alphaValue = 1
    mainPanel.orderFrontRegardless()
    mainPanel.makeKey()
  }

  func focusQuickNote() {
    mainPanel.makeKey()
    DispatchQueue.main.async { [weak viewModel] in
      viewModel?.requestQuickNoteFocus()
    }
  }

  func showSecondary(context: SecondaryPanelContext, layout: PanelLayout) {
    viewModel.secondaryContext = context
    apply(layout: layout)
    secondaryPanel.alphaValue = 1
    secondaryPanel.orderFrontRegardless()
    mainPanel.orderFrontRegardless()
  }

  func hideSecondary() {
    secondaryPanel.orderOut(nil)
    viewModel.secondaryContext = nil
  }

  func hideAll(restoreFocus: Bool) {
    secondaryPanel.orderOut(nil)
    mainPanel.orderOut(nil)
    viewModel.secondaryContext = nil

    if restoreFocus {
      restorePreviousApplication()
    } else {
      previousApplication = nil
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
}
