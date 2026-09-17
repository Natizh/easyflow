import AppKit
import Testing
@testable import EasyFlow

@Suite("Mirrored panel system")
struct PanelSideTests {
  @Test("Both sides select the true desktop extremes regardless of order and offsets")
  func displays() {
    let left = DisplaySnapshot(id: 1, frame: CGRect(x: -1920, y: -200, width: 1920, height: 1080))
    let mac = DisplaySnapshot(id: 2, frame: CGRect(x: 0, y: 0, width: 1470, height: 956))
    let right = DisplaySnapshot(id: 3, frame: CGRect(x: 1470, y: 100, width: 2560, height: 1440))
    #expect(DisplayGeometry.outermost(in: [mac, left], side: .right) == mac)
    #expect(DisplayGeometry.outermost(in: [right, mac], side: .right) == right)
    #expect(DisplayGeometry.outermost(in: [mac, left, right], side: .left) == left)
    #expect(DisplayGeometry.outermost(in: [right, mac], side: .left) == mac)
    let tie = DisplaySnapshot(id: 4, frame: left.frame)
    #expect(DisplayGeometry.outermost(in: [left, tie], side: .left) == tie)
    #expect(DisplayGeometry.outermost(in: [], side: .left) == nil)
  }

  @Test("Visible, hidden, activation and bridge frames are geometric mirrors", arguments: [CGFloat(-1920), 0, 1470])
  func frames(origin: CGFloat) {
    let display = DisplaySnapshot(id: 1, frame: CGRect(x: origin, y: -120, width: 1920, height: 1080))
    let right = PanelLayout(display: display, side: .right)
    let left = PanelLayout(display: display, side: .left)
    func mirror(_ rect: CGRect) -> CGRect {
      CGRect(x: 2 * display.frame.midX - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
    }
    #expect(left.mainFrame == mirror(right.mainFrame))
    #expect(left.secondaryFrame == mirror(right.secondaryFrame))
    #expect(left.mainHiddenFrame == mirror(right.mainHiddenFrame))
    #expect(left.secondaryHiddenFrame == mirror(right.secondaryHiddenFrame))
    #expect(left.activationFrame == mirror(right.activationFrame))
    #expect(left.combinedInteractionFrame == mirror(right.combinedInteractionFrame))
    #expect(left.secondaryFrame.minX > left.mainFrame.maxX)
    #expect(left.mainHiddenFrame.maxX < display.frame.minX)
    #expect(SecondaryPresentationIntent(layout: left).startFrame == mirror(SecondaryPresentationIntent(layout: right).startFrame))
    for secondary in [true, false] {
      for frame in [right.mainFrame, right.secondaryFrame, right.activationFrame] {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        #expect(right.pointerRegion(at: point, secondaryIsVisible: secondary) == left.pointerRegion(at: CGPoint(x: 2 * display.frame.midX - point.x, y: point.y), secondaryIsVisible: secondary))
      }
    }
    let bridge = CGPoint(x: left.mainFrame.maxX + 4, y: left.mainFrame.midY)
    #expect(left.pointerRegion(at: bridge, secondaryIsVisible: true) == .bridge)
    #expect(left.pointerRegion(at: bridge, secondaryIsVisible: false) == .outside)
  }

  @Test("Left mode traverses the inward right boundary")
  func traversal() {
    var router = MainPanelContextRouter()
    #expect(router.update(at: CGPoint(x: 355, y: 150), previousPoint: CGPoint(x: 340, y: 150), side: .left, viewWidth: 360) == .traversal)
    #expect(router.update(at: CGPoint(x: 10, y: 150), previousPoint: CGPoint(x: 30, y: 150), side: .left, viewWidth: 360) == .empty)
  }

  @Test("Auxiliary presentation cancels closing and stale timer events")
  func auxiliaryHold() {
    var machine = PanelStateMachine()
    _ = machine.handle(.pointerChanged(.activationEdge))
    _ = machine.handle(.activationDwellElapsed)
    _ = machine.handle(.userInteracted)
    _ = machine.handle(.pointerChanged(.outside))
    #expect(machine.handle(.auxiliaryPresentationChanged(true)).contains(.cancel(timer: .mainDismissal)))
    #expect(machine.handle(.mainDismissalElapsed).isEmpty)
    #expect(machine.handle(.pointerChanged(.outside)).isEmpty)
    #expect(machine.state == .mainVisible(isEngaged: true))
    _ = machine.handle(.auxiliaryPresentationChanged(false))
    #expect(!machine.handle(.pointerChanged(.outside)).isEmpty)
  }

  @Test("Auxiliary frames stay centered inside negative-origin screens")
  func centering() {
    let visible = CGRect(x: -1920, y: 25, width: 1920, height: 1055)
    let frame = AuxiliaryWindowLayout.centered(size: CGSize(width: 480, height: 500), in: visible)
    #expect(frame.midX == visible.midX && frame.midY == visible.midY)
    let oversized = AuxiliaryWindowLayout.centered(size: CGSize(width: 9000, height: 9000), in: visible)
    #expect(visible.contains(oversized))
  }

  @Test("Panel Side persists and immediately emits one change")
  @MainActor func preference() throws {
    let suite = UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let repository = WorkspaceRepository(database: try AppDatabase(inMemoryNamed: UUID().uuidString))
    let model = AppShellViewModel(repository: repository, userDefaults: defaults)
    #expect(model.panelSide == .right)
    var changes: [PanelSide] = []
    model.onPanelSideChanged = { changes.append($0) }
    model.panelSide = .left
    model.panelSide = .left
    #expect(changes == [.left])
    #expect(AppShellViewModel(repository: repository, userDefaults: defaults).panelSide == .left)
  }
}

@Suite("Native auxiliary window lifecycle", .serialized)
@MainActor
struct AuxiliaryLifecycleTests {
  @Test("Preview owns a reusable visible window and closes normally")
  func previewLifecycle() throws {
    _ = NSApplication.shared
    let screen = try #require(NSScreen.screens.first)
    let controller = ImagePreviewWindowController()
    let window = try #require(controller.window)
    let image = try #require(NSImage(data: fixtureImage()))
    controller.present(image: image, pixels: CGSize(width: 48, height: 24), on: screen)
    #expect(window.isVisible)
    #expect(screen.visibleFrame.contains(window.frame))
    #expect((window.contentView as? NSImageView)?.imageScaling == .scaleProportionallyUpOrDown)
    window.close()
    #expect(!window.isVisible)
    controller.present(image: image, pixels: CGSize(width: 48, height: 24), on: screen)
    #expect(window.isVisible)
    window.close()
  }
}
