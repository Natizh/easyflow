import CoreGraphics
import Testing

@testable import EasyFlow

@Suite("Responsive panel layout")
struct PanelLayoutTests {
  @Test(
    "Width follows one fifth with stable minimum and maximum",
    arguments: [
      (CGFloat(1_440), CGFloat(360)),
      (CGFloat(2_560), CGFloat(512)),
      (CGFloat(4_000), CGFloat(520)),
    ]
  )
  func responsiveWidth(displayWidth: CGFloat, expected: CGFloat) {
    let sizing = PanelSizing()
    #expect(sizing.width(for: displayWidth) == expected)
  }

  @Test(
    "Vertical inset exposes a substantial responsive band",
    arguments: [
      (CGFloat(700), CGFloat(64)),
      (CGFloat(956), CGFloat(76.48)),
      (CGFloat(1_440), CGFloat(96)),
    ]
  )
  func responsiveVerticalInset(displayHeight: CGFloat, expected: CGFloat) {
    #expect(abs(PanelSizing().verticalInset(for: displayHeight) - expected) < 0.001)
  }

  @Test("Main anchors to the right and Secondary sits immediately to its left")
  func panelFrames() {
    let display = DisplaySnapshot(
      id: 1,
      frame: CGRect(x: 100, y: -50, width: 2_560, height: 1_440)
    )
    let layout = PanelLayout(display: display)

    #expect(layout.mainFrame.width == 512)
    #expect(layout.mainFrame.maxX == display.frame.maxX - 8)
    #expect(layout.secondaryFrame.maxX == layout.mainFrame.minX - 8)
    #expect(layout.mainFrame.minY == display.frame.minY + 96)
    #expect(layout.mainFrame.height == display.frame.height - 192)
    #expect(layout.secondaryFrame.minY == layout.mainFrame.minY)
    #expect(layout.secondaryFrame.height == layout.mainFrame.height)
    #expect(layout.activationFrame.width == 3)
    #expect(layout.activationFrame.maxX == display.frame.maxX)
  }

  @Test("Pointer classification bridges panel gaps without widening hidden hit areas")
  func pointerRegions() {
    let display = DisplaySnapshot(
      id: 1,
      frame: CGRect(x: 0, y: 0, width: 2_560, height: 1_440)
    )
    let layout = PanelLayout(display: display)

    #expect(
      layout.pointerRegion(
        at: CGPoint(x: display.frame.maxX - 1, y: display.frame.midY),
        secondaryIsVisible: false
      ) == .activationEdge
    )
    #expect(
      layout.pointerRegion(
        at: CGPoint(x: layout.mainFrame.minX - 4, y: layout.mainFrame.midY),
        secondaryIsVisible: true
      ) == .bridge
    )
    #expect(
      layout.pointerRegion(
        at: CGPoint(x: layout.mainFrame.midX, y: layout.mainFrame.midY),
        secondaryIsVisible: false
      ) == .main
    )
    #expect(
      layout.pointerRegion(
        at: CGPoint(x: layout.secondaryFrame.midX, y: layout.secondaryFrame.midY),
        secondaryIsVisible: false
      ) == .outside
    )
    #expect(
      layout.pointerRegion(
        at: CGPoint(x: layout.secondaryFrame.midX, y: layout.secondaryFrame.midY),
        secondaryIsVisible: true
      ) == .secondary
    )
  }
}
