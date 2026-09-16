import Testing
import AppKit
import SwiftUI

@testable import EasyFlow

@Suite("Main Panel input routing")
struct WindowInputPolicyTests {
  @Test("Normal SwiftUI interactions keep the complete mouse sequence")
  func normalInteractionForwardsMouseDownAndMouseUp() {
    #expect(PointerInputRouting.shouldForward(.mouseDown, hasCapturedDrag: false))
    #expect(PointerInputRouting.shouldForward(.mouseUp, hasCapturedDrag: false))
  }

  @Test("Captured reorder drags keep mouse-up in custom routing")
  func capturedDragRetainsMouseUp() {
    #expect(!PointerInputRouting.shouldForward(.mouseUp, hasCapturedDrag: true))
  }
}

@Suite("Native hosting coordinate routing")
@MainActor
struct HostingCoordinateTests {
  @Test("Flipped hosting hit tests convert superview coordinates and preserve editing exclusions")
  func transformedHitTesting() {
    let parent = NSView(frame: CGRect(x: 0, y: 0, width: 400, height: 900))
    let host = PointerTrackingHostingView(rootView: Color.clear)
    host.isFlipped = true
    host.frame = parent.bounds
    parent.addSubview(host)
    let id = UUID()
    let row = CGRect(x: 20, y: 100, width: 360, height: 180)
    host.updateStepRows([MainTaskRowGeometry(taskID: id, rowFrame: row, reorderFrame: row)])
    host.updateStepExclusions([id: [CGRect(x: 50, y: 110, width: 320, height: 160)]])
    let drag = host.convert(CGPoint(x: 25, y: 120), to: parent)
    let editor = host.convert(CGPoint(x: 100, y: 120), to: parent)
    #expect(host.capturesReorder(atSuperviewPoint: drag, eventType: .leftMouseDown))
    #expect(!host.capturesReorder(atSuperviewPoint: editor, eventType: .leftMouseDown))
    #expect(!host.capturesReorder(atSuperviewPoint: drag, eventType: .leftMouseUp))
    #expect(!host.capturesReorder(atSuperviewPoint: drag, eventType: .rightMouseDown))
    #expect(!host.capturesReorder(atSuperviewPoint: drag, eventType: .keyDown))
  }
}
