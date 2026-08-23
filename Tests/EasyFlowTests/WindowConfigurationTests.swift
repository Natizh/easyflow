import AppKit
import Testing

@testable import EasyFlow

@Suite("AppKit window configuration")
@MainActor
struct WindowConfigurationTests {
  @Test("Overlay panels are key-capable fullscreen auxiliaries on every Space")
  func overlayConfiguration() {
    let panel = OverlayPanel()

    #expect(panel.level == .statusBar)
    #expect(panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(panel.collectionBehavior.contains(.stationary))
    #expect(panel.collectionBehavior.contains(.ignoresCycle))
    #expect(!panel.hidesOnDeactivate)
    #expect(!panel.isOpaque)
  }

  @Test("Invisible activation edge accepts pointer events without taking focus")
  func activationEdgeConfiguration() {
    let panel = ActivationEdgePanel()

    #expect(panel.level == .statusBar)
    #expect(!panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(!panel.ignoresMouseEvents)
    #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
    #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    #expect(!panel.hasShadow)
    #expect(!panel.isOpaque)
  }

  @Test("Secondary uses calmer independent motion")
  func secondaryAnimationTiming() {
    #expect(PanelPresentationCoordinator.secondaryOpenAnimationDuration == 0.28)
    #expect(PanelPresentationCoordinator.secondaryCloseAnimationDuration == 0.35)
    #expect(
      PanelPresentationCoordinator.secondaryCloseAnimationDuration
        > PanelPresentationCoordinator.secondaryOpenAnimationDuration
    )
  }
}
