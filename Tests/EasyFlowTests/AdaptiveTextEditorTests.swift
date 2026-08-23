import CoreGraphics
import Testing

@testable import EasyFlow

@Suite("Adaptive Description metrics")
struct AdaptiveTextEditorTests {
  @Test(
    "Description grows and shrinks within its scroll cap",
    arguments: [
      (CGFloat(0), CGFloat(42)),
      (CGFloat(60), CGFloat(60)),
      (CGFloat(140), CGFloat(140)),
      (CGFloat(220), CGFloat(156)),
    ]
  )
  func adaptiveHeight(content: CGFloat, expected: CGFloat) {
    #expect(
      AdaptiveTextMetrics.height(
        contentHeight: content,
        minimum: 42,
        maximum: 156
      ) == expected
    )
  }
}
