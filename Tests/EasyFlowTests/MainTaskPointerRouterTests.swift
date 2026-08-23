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
    #expect(router.taskForReorder(at: CGPoint(x: 24, y: 20)) == nil)
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

  @Test("Main contextual regions distinguish Quick Notes, tasks, collapse strip, and empty space")
  func mainContextClassification() {
    var router = MainPanelContextRouter()
    let rows = configuredRouter().rows
    router.updateRows(rows)
    router.updateQuickNotesFrame(CGRect(x: 0, y: 140, width: 220, height: 90))
    router.updateSecondaryCollapseStripFrame(CGRect(x: 0, y: 240, width: 220, height: 22))

    #expect(
      router.update(at: CGPoint(x: 80, y: 20), previousPoint: nil)
        == .task(firstID)
    )
    #expect(
      router.update(at: CGPoint(x: 80, y: 160), previousPoint: CGPoint(x: 80, y: 20))
        == .quickNotes
    )
    #expect(
      router.update(at: CGPoint(x: 100, y: 250), previousPoint: CGPoint(x: 80, y: 160))
        == .secondaryCollapseStrip
    )
    #expect(
      router.update(at: CGPoint(x: 100, y: 280), previousPoint: CGPoint(x: 100, y: 250))
        == .empty
    )
  }

  @Test("Generic empty Main space is not the collapse strip")
  func emptyMainIsNotCollapseStrip() {
    var router = MainPanelContextRouter()
    router.updateRows(configuredRouter().rows)
    router.updateQuickNotesFrame(CGRect(x: 0, y: 140, width: 220, height: 90))
    router.updateSecondaryCollapseStripFrame(CGRect(x: 0, y: 240, width: 220, height: 22))

    #expect(
      router.update(at: CGPoint(x: 100, y: 300), previousPoint: nil)
        == .empty
    )
    #expect(router.currentContext == .empty)
  }

  @Test("Row gaps and leftward bridge exit do not produce empty Main context")
  func contextualTraversal() {
    var router = MainPanelContextRouter()
    router.updateRows(configuredRouter().rows)

    #expect(
      router.update(at: CGPoint(x: 80, y: 47), previousPoint: CGPoint(x: 80, y: 20))
        == .traversal
    )
    router.pointerLeftMain()
    #expect(
      router.update(at: CGPoint(x: 10, y: 20), previousPoint: CGPoint(x: 80, y: 20))
        == nil
    )
    #expect(router.currentContext == .traversal)
  }

  private func configuredRouter() -> MainTaskPointerRouter {
    var router = MainTaskPointerRouter()
    router.updateRows([
      MainTaskRowGeometry(
        taskID: firstID,
        rowFrame: CGRect(x: 20, y: 0, width: 200, height: 44),
        reorderFrame: CGRect(x: 32, y: 0, width: 150, height: 44)
      ),
      MainTaskRowGeometry(
        taskID: secondID,
        rowFrame: CGRect(x: 20, y: 50, width: 200, height: 70),
        reorderFrame: CGRect(x: 32, y: 50, width: 150, height: 70)
      ),
    ])
    return router
  }
}
