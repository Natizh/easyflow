import Foundation

enum ReorderLogic {
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
