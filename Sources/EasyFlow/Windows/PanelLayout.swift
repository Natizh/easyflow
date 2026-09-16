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
  let side: PanelSide
  let activationFrame: CGRect
  let mainFrame: CGRect
  let secondaryFrame: CGRect
  let mainInteractionFrame: CGRect
  let combinedInteractionFrame: CGRect

  init(display: DisplaySnapshot, sizing: PanelSizing = PanelSizing(), side: PanelSide = .right) {
    self.display = display
    self.side = side

    let screenFrame = display.frame
    let width = sizing.width(for: screenFrame.width)
    let verticalInset = sizing.verticalInset(for: screenFrame.height)
    let height = max(1, screenFrame.height - (verticalInset * 2))
    let panelY = screenFrame.minY + verticalInset
    let mainX = side == .right ? screenFrame.maxX - sizing.outerMargin - width : screenFrame.minX + sizing.outerMargin
    let secondaryX = mainX - side.outwardSign * (sizing.panelGap + width)

    activationFrame = CGRect(
      x: side == .right ? screenFrame.maxX - sizing.hotZoneWidth : screenFrame.minX,
      y: screenFrame.minY,
      width: sizing.hotZoneWidth,
      height: screenFrame.height
    )
    mainFrame = CGRect(x: mainX, y: panelY, width: width, height: height)
    secondaryFrame = CGRect(x: secondaryX, y: panelY, width: width, height: height)
    let edgeMargin = CGRect(x: side == .right ? mainFrame.maxX : screenFrame.minX,
      y: panelY, width: sizing.outerMargin, height: height)
    mainInteractionFrame = mainFrame.union(edgeMargin)
    combinedInteractionFrame = mainInteractionFrame.union(secondaryFrame)
  }

  var mainHiddenFrame: CGRect {
    mainFrame.offsetBy(dx: side.outwardSign * (mainFrame.width + 16), dy: 0)
  }

  var secondaryHiddenFrame: CGRect {
    CGRect(x: mainFrame.minX, y: secondaryFrame.minY,
      width: secondaryFrame.width, height: secondaryFrame.height)
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

struct SecondaryPresentationIntent: Equatable, Sendable {
  let startFrame: CGRect
  let targetFrame: CGRect
  let startAlpha: CGFloat
  let targetAlpha: CGFloat

  init(layout: PanelLayout) {
    targetFrame = layout.secondaryFrame
    startFrame = layout.secondaryFrame.offsetBy(dx: layout.side.outwardSign * 28, dy: 0)
    startAlpha = 0.15
    targetAlpha = 1
  }
}
