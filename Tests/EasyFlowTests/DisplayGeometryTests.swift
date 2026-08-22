import CoreGraphics
import Testing

@testable import EasyFlow

@Suite("Display geometry")
struct DisplayGeometryTests {
  @Test("Selects the far-right outer display regardless of input order")
  func selectsRightmostDisplay() {
    let displays = [
      DisplaySnapshot(id: 2, frame: CGRect(x: -1440, y: 0, width: 1440, height: 900)),
      DisplaySnapshot(id: 3, frame: CGRect(x: 1512, y: -200, width: 1920, height: 1080)),
      DisplaySnapshot(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982)),
    ]

    #expect(DisplayGeometry.rightmost(in: displays)?.id == 3)
  }

  @Test("Uses deterministic tie breaking when maxX is equal")
  func deterministicTieBreak() {
    let displays = [
      DisplaySnapshot(id: 10, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
      DisplaySnapshot(id: 11, frame: CGRect(x: 440, y: 100, width: 1000, height: 1000)),
    ]

    #expect(DisplayGeometry.rightmost(in: displays)?.id == 11)
  }

  @Test("Empty display topology has no activation target")
  func emptyTopology() {
    #expect(DisplayGeometry.rightmost(in: []) == nil)
  }
}
