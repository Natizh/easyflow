import AppKit

struct DisplaySnapshot: Equatable, Sendable {
  let id: CGDirectDisplayID
  let frame: CGRect
}

enum DisplayGeometry {
  static func rightmost(in displays: [DisplaySnapshot]) -> DisplaySnapshot? {
    displays.max { lhs, rhs in
      if lhs.frame.maxX != rhs.frame.maxX {
        return lhs.frame.maxX < rhs.frame.maxX
      }
      if lhs.frame.maxY != rhs.frame.maxY {
        return lhs.frame.maxY < rhs.frame.maxY
      }
      return lhs.id < rhs.id
    }
  }

  @MainActor
  static func rightmostScreen(from screens: [NSScreen] = NSScreen.screens) -> DisplaySnapshot? {
    let snapshots = screens.enumerated().map { index, screen in
      let screenNumber =
        screen.deviceDescription[
          NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber

      return DisplaySnapshot(
        id: screenNumber?.uint32Value ?? CGDirectDisplayID(index),
        frame: screen.frame
      )
    }

    return rightmost(in: snapshots)
  }
}
