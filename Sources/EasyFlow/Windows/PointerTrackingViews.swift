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
