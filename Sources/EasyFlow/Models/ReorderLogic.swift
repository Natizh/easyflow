import Foundation

enum ReorderLogic {
  static func insertionIndex(
    ids: [UUID],
    draggedID: UUID,
    translation: CGFloat,
    rowExtent: CGFloat
  ) -> Int? {
    guard let sourceIndex = ids.firstIndex(of: draggedID), rowExtent > 0 else { return nil }
    let delta = Int((translation / rowExtent).rounded())
    let targetIndex = min(max(sourceIndex + delta, 0), ids.count - 1)
    return targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
  }

  static func moving(
    _ ids: [UUID],
    draggedID: UUID,
    toInsertionIndex insertionIndex: Int
  ) -> [UUID]? {
    guard let sourceIndex = ids.firstIndex(of: draggedID),
      (0...ids.count).contains(insertionIndex)
    else { return nil }

    var reordered = ids
    reordered.remove(at: sourceIndex)
    let adjustedIndex = insertionIndex > sourceIndex ? insertionIndex - 1 : insertionIndex
    reordered.insert(draggedID, at: min(max(adjustedIndex, 0), reordered.count))
    return reordered == ids ? nil : reordered
  }

  static func moving(
    _ ids: [UUID],
    draggedID: UUID,
    before targetID: UUID
  ) -> [UUID]? {
    guard draggedID != targetID,
      let sourceIndex = ids.firstIndex(of: draggedID),
      ids.contains(targetID)
    else {
      return nil
    }

    var reordered = ids
    reordered.remove(at: sourceIndex)
    guard let targetIndex = reordered.firstIndex(of: targetID) else {
      return nil
    }
    reordered.insert(draggedID, at: targetIndex)
    return reordered
  }
}
