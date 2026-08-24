import Testing

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
