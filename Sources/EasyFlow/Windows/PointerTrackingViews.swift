import AppKit
import SwiftUI

@MainActor
protocol PointerLocationReporting: AnyObject {
  var onPointerMoved: ((CGPoint) -> Void)? { get set }
}

final class PointerTrackingView: NSView, PointerLocationReporting {
  var onPointerMoved: ((CGPoint) -> Void)?
  private var pointerTrackingArea: NSTrackingArea?

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let pointerTrackingArea {
      removeTrackingArea(pointerTrackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    pointerTrackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    reportPointer()
  }

  override func mouseMoved(with event: NSEvent) {
    reportPointer()
  }

  override func mouseExited(with event: NSEvent) {
    reportPointer()
  }

  private func reportPointer() {
    onPointerMoved?(NSEvent.mouseLocation)
  }
}

final class PointerTrackingHostingView<Content: View>: NSHostingView<Content>,
  PointerLocationReporting
{
  var onPointerMoved: ((CGPoint) -> Void)?
  var onTaskHover: ((UUID) -> Void)?
  var onTaskDragChanged: ((UUID, Int) -> Void)?
  var onTaskDragCommitted: ((UUID, Int) -> Void)?
  var onTaskDragCancelled: (() -> Void)?
  private var pointerTrackingArea: NSTrackingArea?
  private var taskRouter = MainTaskPointerRouter()

  override var acceptsFirstResponder: Bool { true }

  func updateTaskRows(_ rows: [MainTaskRowGeometry]) {
    taskRouter.updateRows(rows)
    InputDiagnostics.record("registered task rows=\(rows.count)")
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    if NSApplication.shared.currentEvent?.type == .leftMouseDown,
      taskRouter.taskForReorder(at: point) != nil
    {
      return self
    }
    return super.hitTest(point)
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let pointerTrackingArea {
      removeTrackingArea(pointerTrackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    pointerTrackingArea = trackingArea
  }

  override func mouseEntered(with event: NSEvent) {
    reportPointer()
  }

  override func mouseMoved(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if let taskID = taskRouter.updateHover(at: point) {
      InputDiagnostics.record(
        "mouseMoved point=\(NSStringFromPoint(point)) hit=task id=\(taskID.uuidString)"
      )
      onTaskHover?(taskID)
    }
    reportPointer()
  }

  override func mouseExited(with event: NSEvent) {
    _ = taskRouter.updateHover(at: convert(event.locationInWindow, from: nil))
    reportPointer()
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard taskRouter.mouseDown(at: point) else {
      super.mouseDown(with: event)
      return
    }
    window?.makeFirstResponder(self)
    InputDiagnostics.record("mouseDown point=\(NSStringFromPoint(point)) reorderCandidate=yes")
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    guard let update = taskRouter.mouseDragged(to: point) else { return }
    InputDiagnostics.record(
      "mouseDragged id=\(update.taskID.uuidString) insertion=\(update.insertionIndex) began=\(update.didBegin)"
    )
    onTaskDragChanged?(update.taskID, update.insertionIndex)
  }

  override func mouseUp(with event: NSEvent) {
    if let commit = taskRouter.mouseUp() {
      InputDiagnostics.record(
        "mouseUp commit id=\(commit.taskID.uuidString) insertion=\(commit.insertionIndex)"
      )
      onTaskDragCommitted?(commit.taskID, commit.insertionIndex)
    } else {
      onTaskDragCancelled?()
    }
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53, taskRouter.cancelDrag() {
      InputDiagnostics.record("reorder cancelled by Escape")
      onTaskDragCancelled?()
      return
    }
    super.keyDown(with: event)
  }

  private func reportPointer() {
    onPointerMoved?(NSEvent.mouseLocation)
  }
}
