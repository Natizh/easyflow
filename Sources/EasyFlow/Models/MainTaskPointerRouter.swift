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
