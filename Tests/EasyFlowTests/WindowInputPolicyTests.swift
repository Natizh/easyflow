import AppKit
import SwiftUI
import Testing

@testable import EasyFlow

@Suite("Main Panel input policy")
@MainActor
struct WindowInputPolicyTests {
  @Test("Overlay panels are key-capable activating panels")
  func overlayPanelKeyPolicy() {
    let panel = OverlayPanel()

    #expect(panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(!panel.styleMask.contains(.nonactivatingPanel))
  }

  @Test("Hosting view accepts the first click")
  func hostingViewAcceptsFirstMouse() {
    let hostingView = PointerTrackingHostingView(rootView: EmptyView())

    #expect(hostingView.acceptsFirstMouse(for: nil))
  }

  @Test("Only reorder geometry without a normal control is captured")
  func reorderCaptureRouting() {
    #expect(
      PointerInputRouting.shouldCaptureReorder(
        isLeftMouseDown: true,
        isReorderCandidate: true,
        hitsInteractiveControl: false
      )
    )
    #expect(
      !PointerInputRouting.shouldCaptureReorder(
        isLeftMouseDown: true,
        isReorderCandidate: true,
        hitsInteractiveControl: true
      )
    )
    #expect(
      !PointerInputRouting.shouldCaptureReorder(
        isLeftMouseDown: true,
        isReorderCandidate: false,
        hitsInteractiveControl: false
      )
    )
  }
}
