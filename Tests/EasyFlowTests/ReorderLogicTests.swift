import Foundation
import Testing

@testable import EasyFlow

@Suite("UI reorder logic")
struct ReorderLogicTests {
  @Test("Moves stable identity before the drop target")
  func moveBeforeTarget() throws {
    let ids = [UUID(), UUID(), UUID(), UUID()]
    let result = try #require(
      ReorderLogic.moving(ids, draggedID: ids[3], before: ids[1])
    )
    #expect(result == [ids[0], ids[3], ids[1], ids[2]])
  }

  @Test("No-op and unknown payloads do not produce a database order")
  func invalidMoves() {
    let ids = [UUID(), UUID()]
    #expect(ReorderLogic.moving(ids, draggedID: ids[0], before: ids[0]) == nil)
    #expect(ReorderLogic.moving(ids, draggedID: UUID(), before: ids[0]) == nil)
    #expect(ReorderLogic.moving(ids, draggedID: ids[0], before: UUID()) == nil)
  }
}
