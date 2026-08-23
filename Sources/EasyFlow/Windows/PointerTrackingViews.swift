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
  var onQuickNotesHover: (() -> Void)?
  var onSecondaryCollapseStrip: (() -> Void)?
  var onTaskDragChanged: ((UUID, Int) -> Void)?
  var onTaskDragCommitted: ((UUID, Int) -> Void)?
  var onTaskDragCancelled: (() -> Void)?
  var onNoteDragChanged: ((UUID, Int?, UUID?) -> Void)?
  var onNoteDragCommitted: ((UUID, Int?, UUID?) -> Void)?
  var onNoteDragCancelled: (() -> Void)?
  var onStepDragChanged: ((UUID, Int) -> Void)?
  var onStepDragCommitted: ((UUID, Int) -> Void)?
  var onStepDragCancelled: (() -> Void)?
  private var pointerTrackingArea: NSTrackingArea?
  private var taskRouter = MainTaskPointerRouter()
  private var noteRouter = MainTaskPointerRouter()
  private var stepRouter = MainTaskPointerRouter()
  private var stepExclusions: [UUID: [CGRect]] = [:]
  private var contextRouter = MainPanelContextRouter()
  private var lastMousePoint: CGPoint?
  private var capturedDrag: CapturedDrag?
  private var noteAttachmentTargetID: UUID?

  private enum CapturedDrag: Equatable {
    case task
    case note
    case step
  }

  override var acceptsFirstResponder: Bool { true }

  func updateTaskRows(_ rows: [MainTaskRowGeometry]) {
    taskRouter.updateRows(rows)
    contextRouter.updateRows(rows)
    InputDiagnostics.record("registered task rows=\(rows.count)")
  }

  func updateQuickNotesFrame(_ frame: CGRect?) {
    contextRouter.updateQuickNotesFrame(frame)
    InputDiagnostics.record("registered quickNotes frame=\(String(describing: frame))")
  }

  func updateSecondaryCollapseStripFrame(_ frame: CGRect?) {
    contextRouter.updateSecondaryCollapseStripFrame(frame)
    InputDiagnostics.record("registered secondaryCollapseStrip frame=\(String(describing: frame))")
  }

  func updateQuickNoteRows(_ rows: [MainTaskRowGeometry]) {
    noteRouter.updateRows(rows)
    InputDiagnostics.record("registered quickNote rows=\(rows.count)")
  }

  func updateStepRows(_ rows: [MainTaskRowGeometry]) {
    stepRouter.updateRows(rows)
  }

  func updateStepExclusions(_ exclusions: [UUID: [CGRect]]) {
    stepExclusions = exclusions
  }

  private func stepForReorder(at point: CGPoint) -> UUID? {
    guard let id = stepRouter.rowID(at: point) else { return nil }
    if stepExclusions[id, default: []].contains(where: { $0.contains(point) }) {
      return nil
    }
    return id
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    if NSApplication.shared.currentEvent?.type == .leftMouseDown,
      taskRouter.taskForReorder(at: point) != nil
        || noteRouter.taskForReorder(at: point) != nil
        || stepForReorder(at: point) != nil
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
    if let context = contextRouter.update(at: point, previousPoint: lastMousePoint) {
      switch context {
      case .task(let taskID):
        InputDiagnostics.record(
          "mouseMoved point=\(NSStringFromPoint(point)) context=task id=\(taskID.uuidString)"
        )
        onTaskHover?(taskID)
      case .quickNotes:
        InputDiagnostics.record(
          "mouseMoved point=\(NSStringFromPoint(point)) context=quickNotes"
        )
        onQuickNotesHover?()
      case .empty:
        InputDiagnostics.record(
          "mouseMoved point=\(NSStringFromPoint(point)) context=emptyMain"
        )
      case .secondaryCollapseStrip:
        InputDiagnostics.record(
          "mouseMoved point=\(NSStringFromPoint(point)) context=secondaryCollapseStrip"
        )
        onSecondaryCollapseStrip?()
      case .traversal:
        InputDiagnostics.record(
          "mouseMoved point=\(NSStringFromPoint(point)) context=traversal"
        )
      }
    }
    lastMousePoint = point
    reportPointer()
  }

  override func mouseExited(with event: NSEvent) {
    contextRouter.pointerLeftMain()
    lastMousePoint = nil
    reportPointer()
  }

  override func mouseDown(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    if taskRouter.mouseDown(at: point) {
      capturedDrag = .task
    } else if noteRouter.mouseDown(at: point) {
      capturedDrag = .note
    } else if stepForReorder(at: point) != nil, stepRouter.mouseDown(at: point) {
      capturedDrag = .step
    } else {
      super.mouseDown(with: event)
      return
    }
    window?.makeFirstResponder(self)
    InputDiagnostics.record("mouseDown point=\(NSStringFromPoint(point)) reorderCandidate=yes")
  }

  override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    switch capturedDrag {
    case .task:
      guard let update = taskRouter.mouseDragged(to: point) else { return }
      InputDiagnostics.record(
        "mouseDragged task=\(update.taskID.uuidString) insertion=\(update.insertionIndex)"
      )
      onTaskDragChanged?(update.taskID, update.insertionIndex)
    case .note:
      guard let update = noteRouter.mouseDragged(to: point) else { return }
      let target = taskRouter.rowID(at: point)
      noteAttachmentTargetID = target
      InputDiagnostics.record(
        "mouseDragged note=\(update.taskID.uuidString) insertion=\(update.insertionIndex) target=\(String(describing: target))"
      )
      onNoteDragChanged?(
        update.taskID,
        target == nil ? update.insertionIndex : nil,
        target
      )
    case .step:
      guard let update = stepRouter.mouseDragged(to: point) else { return }
      onStepDragChanged?(update.taskID, update.insertionIndex)
    case nil:
      return
    }
  }

  override func mouseUp(with event: NSEvent) {
    defer {
      capturedDrag = nil
      noteAttachmentTargetID = nil
    }
    switch capturedDrag {
    case .task:
      if let commit = taskRouter.mouseUp() {
        onTaskDragCommitted?(commit.taskID, commit.insertionIndex)
      } else {
        onTaskDragCancelled?()
      }
    case .note:
      if let commit = noteRouter.mouseUp() {
        onNoteDragCommitted?(
          commit.taskID,
          noteAttachmentTargetID == nil ? commit.insertionIndex : nil,
          noteAttachmentTargetID
        )
      } else {
        onNoteDragCancelled?()
      }
    case .step:
      if let commit = stepRouter.mouseUp() {
        onStepDragCommitted?(commit.taskID, commit.insertionIndex)
      } else {
        onStepDragCancelled?()
      }
    case nil:
      break
    }
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      if capturedDrag == .task, taskRouter.cancelDrag() {
        onTaskDragCancelled?()
        capturedDrag = nil
        return
      }
      if capturedDrag == .note, noteRouter.cancelDrag() {
        onNoteDragCancelled?()
        capturedDrag = nil
        noteAttachmentTargetID = nil
        return
      }
      if capturedDrag == .step, stepRouter.cancelDrag() {
        onStepDragCancelled?()
        capturedDrag = nil
        return
      }
    }
    super.keyDown(with: event)
  }

  private func reportPointer() {
    onPointerMoved?(NSEvent.mouseLocation)
  }
}
