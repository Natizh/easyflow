import CoreGraphics
import Foundation
import Testing

@testable import EasyFlow

@Suite("AppKit Main Task pointer router")
struct MainTaskPointerRouterTests {
  private let firstID = UUID()
  private let secondID = UUID()

  @Test("Rendered row registration drives hover hit testing without duplicate events")
  func hoverRouting() {
    var router = configuredRouter()
    let enteredFirst = router.updateHover(at: CGPoint(x: 80, y: 20))
    let stayedFirst = router.updateHover(at: CGPoint(x: 90, y: 25))
    let enteredSecond = router.updateHover(at: CGPoint(x: 80, y: 70))
    let leftRows = router.updateHover(at: CGPoint(x: 250, y: 110))
    #expect(enteredFirst == firstID)
    #expect(stayedFirst == nil)
    #expect(enteredSecond == secondID)
    #expect(leftRows == nil)
    #expect(router.hoveredTaskID == nil)
  }

  @Test("Checkbox and effort regions are outside reorder initiation")
  func excludedControls() {
    let router = configuredRouter()
    #expect(router.taskForReorder(at: CGPoint(x: 12, y: 20)) == nil)
    #expect(router.taskForReorder(at: CGPoint(x: 205, y: 20)) == nil)
    #expect(router.taskForReorder(at: CGPoint(x: 80, y: 20)) == firstID)
  }

  @Test("Movement threshold starts drag and actual row midpoints choose insertion")
  func dragThresholdAndInsertion() {
    var router = configuredRouter()
    let accepted = router.mouseDown(at: CGPoint(x: 80, y: 20))
    #expect(accepted)
    let belowThreshold = router.mouseDragged(to: CGPoint(x: 82, y: 21), threshold: 4)
    #expect(belowThreshold == nil)
    let update = router.mouseDragged(to: CGPoint(x: 82, y: 100), threshold: 4)
    #expect(update?.taskID == firstID)
    #expect(update?.didBegin == true)
    #expect(update?.insertionIndex == 2)
  }

  @Test("Mouse up commits exactly once and cancellation commits zero")
  func commitAndCancel() {
    var router = configuredRouter()
    let firstAccepted = router.mouseDown(at: CGPoint(x: 80, y: 20))
    #expect(firstAccepted)
    _ = router.mouseDragged(to: CGPoint(x: 80, y: 100))
    let commit = router.mouseUp()
    #expect(commit?.taskID == firstID)
    #expect(commit?.insertionIndex == 2)
    let repeatedMouseUp = router.mouseUp()
    #expect(repeatedMouseUp == nil)

    let secondAccepted = router.mouseDown(at: CGPoint(x: 80, y: 20))
    #expect(secondAccepted)
    _ = router.mouseDragged(to: CGPoint(x: 80, y: 100))
    let cancelled = router.cancelDrag()
    #expect(cancelled)
    let cancelledMouseUp = router.mouseUp()
    #expect(cancelledMouseUp == nil)
  }

  private func configuredRouter() -> MainTaskPointerRouter {
    var router = MainTaskPointerRouter()
    router.updateRows([
      MainTaskRowGeometry(
        taskID: firstID,
        rowFrame: CGRect(x: 0, y: 0, width: 220, height: 44),
        reorderFrame: CGRect(x: 32, y: 0, width: 150, height: 44)
      ),
      MainTaskRowGeometry(
        taskID: secondID,
        rowFrame: CGRect(x: 0, y: 50, width: 220, height: 70),
        reorderFrame: CGRect(x: 32, y: 50, width: 150, height: 70)
      ),
    ])
    return router
  }
}
