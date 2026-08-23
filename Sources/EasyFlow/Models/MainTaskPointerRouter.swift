import CoreGraphics
import Foundation

struct MainTaskRowGeometry: Equatable, Sendable {
  let taskID: UUID
  var rowFrame: CGRect
  var reorderFrame: CGRect
}

struct MainTaskDragUpdate: Equatable, Sendable {
  var taskID: UUID
  var insertionIndex: Int
  var didBegin: Bool
}

struct MainTaskPointerRouter: Equatable, Sendable {
  private(set) var rows: [MainTaskRowGeometry] = []
  private(set) var hoveredTaskID: UUID?
  private(set) var pressedTaskID: UUID?
  private(set) var dragStart: CGPoint?
  private(set) var isDragging = false
  private(set) var insertionIndex: Int?

  mutating func updateRows(_ newRows: [MainTaskRowGeometry]) {
    rows = newRows.sorted {
      if $0.rowFrame.minY == $1.rowFrame.minY {
        return $0.taskID.uuidString < $1.taskID.uuidString
      }
      return $0.rowFrame.minY < $1.rowFrame.minY
    }
  }

  mutating func updateHover(at point: CGPoint) -> UUID? {
    let taskID = rows.first(where: { $0.rowFrame.contains(point) })?.taskID
    guard taskID != hoveredTaskID else { return nil }
    hoveredTaskID = taskID
    return taskID
  }

  func taskForReorder(at point: CGPoint) -> UUID? {
    rows.first(where: { $0.reorderFrame.contains(point) })?.taskID
  }

  func rowID(at point: CGPoint) -> UUID? {
    rows.first(where: { $0.rowFrame.contains(point) })?.taskID
  }

  mutating func mouseDown(at point: CGPoint) -> Bool {
    guard let taskID = taskForReorder(at: point) else { return false }
    pressedTaskID = taskID
    dragStart = point
    isDragging = false
    insertionIndex = nil
    return true
  }

  mutating func mouseDragged(
    to point: CGPoint,
    threshold: CGFloat = 4
  ) -> MainTaskDragUpdate? {
    guard let taskID = pressedTaskID, let dragStart else { return nil }
    let distance = hypot(point.x - dragStart.x, point.y - dragStart.y)
    guard isDragging || distance >= threshold else { return nil }
    let didBegin = !isDragging
    isDragging = true
    let insertion = insertionBoundary(atY: point.y)
    insertionIndex = insertion
    return MainTaskDragUpdate(
      taskID: taskID,
      insertionIndex: insertion,
      didBegin: didBegin
    )
  }

  mutating func mouseUp() -> (taskID: UUID, insertionIndex: Int)? {
    defer { resetDrag() }
    guard isDragging, let taskID = pressedTaskID, let insertionIndex else { return nil }
    return (taskID, insertionIndex)
  }

  mutating func cancelDrag() -> Bool {
    let wasDragging = isDragging || pressedTaskID != nil
    resetDrag()
    return wasDragging
  }

  private func insertionBoundary(atY y: CGFloat) -> Int {
    for (index, row) in rows.enumerated() where y < row.rowFrame.midY {
      return index
    }
    return rows.count
  }

  private mutating func resetDrag() {
    pressedTaskID = nil
    dragStart = nil
    isDragging = false
    insertionIndex = nil
  }
}

enum MainPanelPointerContext: Equatable, Sendable {
  case quickNotes
  case task(UUID)
  case secondaryCollapseStrip
  case empty
  case traversal
}

struct MainPanelContextRouter: Equatable, Sendable {
  private(set) var rows: [MainTaskRowGeometry] = []
  private(set) var quickNotesFrame: CGRect?
  private(set) var secondaryCollapseStripFrame: CGRect?
  private(set) var currentContext: MainPanelPointerContext?

  mutating func updateRows(_ newRows: [MainTaskRowGeometry]) {
    rows = newRows.sorted { $0.rowFrame.minY < $1.rowFrame.minY }
  }

  mutating func updateQuickNotesFrame(_ frame: CGRect?) {
    quickNotesFrame = frame
  }

  mutating func updateSecondaryCollapseStripFrame(_ frame: CGRect?) {
    secondaryCollapseStripFrame = frame
  }

  mutating func update(
    at point: CGPoint,
    previousPoint: CGPoint?,
    leftTraversalWidth: CGFloat = 24,
    rowGapTolerance: CGFloat = 12
  ) -> MainPanelPointerContext? {
    let next: MainPanelPointerContext
    if let task = rows.first(where: { $0.rowFrame.contains(point) }) {
      next = .task(task.taskID)
    } else if quickNotesFrame?.contains(point) == true {
      next = .quickNotes
    } else if secondaryCollapseStripFrame?.contains(point) == true {
      next = .secondaryCollapseStrip
    } else if isBetweenAdjacentRows(point, tolerance: rowGapTolerance) {
      next = .traversal
    } else if point.x <= leftTraversalWidth,
      let previousPoint,
      point.x < previousPoint.x
    {
      next = .traversal
    } else {
      next = .empty
    }

    guard next != currentContext else { return nil }
    currentContext = next
    return next
  }

  mutating func pointerLeftMain() {
    currentContext = .traversal
  }

  private func isBetweenAdjacentRows(_ point: CGPoint, tolerance: CGFloat) -> Bool {
    guard rows.count > 1 else { return false }
    for index in 0..<(rows.count - 1) {
      let upper = rows[index].rowFrame
      let lower = rows[index + 1].rowFrame
      let gap = lower.minY - upper.maxY
      guard gap >= 0, gap <= tolerance else { continue }
      let horizontalRange = min(upper.minX, lower.minX)...max(upper.maxX, lower.maxX)
      if horizontalRange.contains(point.x),
        point.y >= upper.maxY,
        point.y <= lower.minY
      {
        return true
      }
    }
    return false
  }
}
