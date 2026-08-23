import CoreGraphics

struct PanelSizing: Equatable, Sendable {
  var widthFraction: CGFloat = 0.20
  var minimumWidth: CGFloat = 360
  var maximumWidth: CGFloat = 520
  var hotZoneWidth: CGFloat = 3
  var outerMargin: CGFloat = 8
  var panelGap: CGFloat = 8
  var verticalInsetFraction: CGFloat = 0.08
  var minimumVerticalInset: CGFloat = 64
  var maximumVerticalInset: CGFloat = 96

  func width(for displayWidth: CGFloat) -> CGFloat {
    min(max(displayWidth * widthFraction, minimumWidth), maximumWidth)
  }

  func verticalInset(for displayHeight: CGFloat) -> CGFloat {
    min(
      max(displayHeight * verticalInsetFraction, minimumVerticalInset),
      maximumVerticalInset
    )
  }
}

struct PanelLayout: Equatable, Sendable {
  let display: DisplaySnapshot
  let activationFrame: CGRect
  let mainFrame: CGRect
  let secondaryFrame: CGRect
  let mainInteractionFrame: CGRect
  let combinedInteractionFrame: CGRect

  init(display: DisplaySnapshot, sizing: PanelSizing = PanelSizing()) {
    self.display = display

    let screenFrame = display.frame
    let width = sizing.width(for: screenFrame.width)
    let verticalInset = sizing.verticalInset(for: screenFrame.height)
    let height = max(1, screenFrame.height - (verticalInset * 2))
    let panelY = screenFrame.minY + verticalInset
    let mainX = screenFrame.maxX - sizing.outerMargin - width
    let secondaryX = mainX - sizing.panelGap - width

    activationFrame = CGRect(
      x: screenFrame.maxX - sizing.hotZoneWidth,
      y: screenFrame.minY,
      width: sizing.hotZoneWidth,
      height: screenFrame.height
    )
    mainFrame = CGRect(x: mainX, y: panelY, width: width, height: height)
    secondaryFrame = CGRect(x: secondaryX, y: panelY, width: width, height: height)
    mainInteractionFrame = CGRect(
      x: mainFrame.minX,
      y: mainFrame.minY,
      width: screenFrame.maxX - mainFrame.minX,
      height: mainFrame.height
    )
    combinedInteractionFrame = CGRect(
      x: secondaryFrame.minX,
      y: secondaryFrame.minY,
      width: screenFrame.maxX - secondaryFrame.minX,
      height: secondaryFrame.height
    )
  }

  func pointerRegion(at point: CGPoint, secondaryIsVisible: Bool) -> PointerRegion {
    if activationFrame.contains(point) {
      return .activationEdge
    }
    if mainFrame.contains(point) {
      return .main
    }
    if secondaryIsVisible, secondaryFrame.contains(point) {
      return .secondary
    }

    let interactionFrame =
      secondaryIsVisible
      ? combinedInteractionFrame
      : mainInteractionFrame
    if interactionFrame.contains(point) {
      return .bridge
    }
    return .outside
  }
}
