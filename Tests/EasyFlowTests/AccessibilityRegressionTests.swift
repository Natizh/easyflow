import AppKit
import SwiftUI
import Testing
@testable import EasyFlow

@Suite("Accessibility and keyboard regressions", .serialized)
@MainActor
struct AccessibilityRegressionTests {
  @Test("Focus eligibility requires visible, current-Space, nonclosing content", arguments: [
    (false, false, false, false), (false, true, false, false),
    (true, false, false, false), (true, true, true, false), (true, true, false, true),
  ])
  func focusEligibility(visible: Bool, currentSpace: Bool, closing: Bool, expected: Bool) {
    #expect(PanelFocusPolicy.canFocus(isVisible: visible, isOnActiveSpace: currentSpace, isClosing: closing) == expected)
  }

  @Test("Retiring an overlay removes its responder and hides its accessibility subtree")
  func retiringOverlay() {
    _ = NSApplication.shared
    let panel = OverlayPanel()
    let view = NoteImageTextView()
    panel.contentView = view
    panel.exposeForInteraction()
    #expect(!panel.isAccessibilityHidden())
    #expect(!view.isAccessibilityHidden())
    #expect(panel.makeFirstResponder(view))
    panel.retireFromInteraction()
    #expect(panel.firstResponder !== view)
    #expect(panel.isAccessibilityHidden())
    #expect(view.isAccessibilityHidden())
    #expect(!panel.isAvailableForFocus)
    panel.exposeForInteraction()
    #expect(!panel.isClosing)
    #expect(!view.isAccessibilityHidden())
    #expect(panel.autorecalculatesKeyViewLoop)
  }

  @Test("Invisible edge is not an accessibility element; banner never takes key/main")
  func passiveWindows() {
    let edge = ActivationEdgePanel()
    #expect(edge.isAccessibilityHidden())
    #expect(!edge.isAccessibilityElement())
    let banner = ReminderBannerPanel()
    #expect(banner.isAccessibilityHidden())
    #expect(!banner.canBecomeKey)
    #expect(!banner.canBecomeMain)
    #expect(banner.styleMask.contains(.nonactivatingPanel))
  }

  @Test("Editor updates preserve active selection and IME, but acknowledge committed capture reset")
  func editorUpdatePolicy() {
    #expect(!NativeTextUpdatePolicy.shouldReplace(isEditing: true, hasMarkedText: false, contentDiffers: true))
    #expect(!NativeTextUpdatePolicy.shouldReplace(isEditing: false, hasMarkedText: true, contentDiffers: true))
    #expect(NativeTextUpdatePolicy.shouldReplace(isEditing: false, hasMarkedText: false, contentDiffers: true))
    #expect(NativeTextUpdatePolicy.shouldReplace(isEditing: true, hasMarkedText: false, contentDiffers: true, committedCaptureReset: true))
    #expect(!NativeTextUpdatePolicy.shouldReplace(isEditing: true, hasMarkedText: true, contentDiffers: true, committedCaptureReset: true))
    #expect(!NativeTextUpdatePolicy.shouldReplace(isEditing: false, hasMarkedText: false, contentDiffers: false))
  }

  @Test("Multiline Tab and Shift-Tab use the native key loop without inserting text")
  func editorTabNavigation() {
    let window = KeyLoopProbePanel()
    let editor = NoteImageTextView()
    window.contentView = editor
    editor.string = "Line one\nLine two"
    editor.setSelectedRange(NSRange(location: 5, length: 2))
    editor.insertTab(nil)
    editor.insertBacktab(nil)
    #expect(window.nextCount == 1)
    #expect(window.previousCount == 1)
    #expect(editor.string == "Line one\nLine two")
    #expect(editor.selectedRange() == NSRange(location: 5, length: 2))
  }

  @Test("Rich editor retains native text role, value, and selected text")
  func editorAccessibility() {
    let editor = QuickNoteCaptureTextView()
    editor.configureForEasyFlowCapture()
    editor.string = "alpha beta"
    editor.setSelectedRange(NSRange(location: 6, length: 4))
    #expect(editor.accessibilityRole() == .textArea)
    #expect(editor.accessibilityLabel() == "Quick Note")
    #expect(editor.accessibilityValue() == "alpha beta")
    #expect(editor.accessibilitySelectedText() == "beta")
  }

  @Test("Escape and Command-W route through overlay dismissal")
  func overlayDismissal() {
    let panel = OverlayPanel()
    var dismissals = 0
    panel.onDismiss = { dismissals += 1 }
    panel.cancelOperation(nil)
    panel.performClose(nil)
    #expect(dismissals == 2)
  }

  @Test("Keyboard interaction cancels pending pointer dismissal and holds both panels")
  func keyboardHoldsWorkspace() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.pointerChanged(.outside))
    let commands = machine.handle(.keyboardNavigation)
    #expect(commands.contains(.cancel(timer: .secondaryDismissal)))
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
    #expect(machine.handle(.pointerChanged(.outside)).isEmpty)
    #expect(machine.handle(.secondaryDismissalElapsed).isEmpty)
    #expect(machine.handle(.mainDismissalElapsed).isEmpty)
    #expect(machine.state.isSecondaryPresented)
    let dismiss = machine.handle(.dismissWorkspace)
    #expect(dismiss.contains(.hideMain(restoreFocus: true)))
    #expect(machine.state == .hidden)
  }

  @Test("Deliberate pointer interaction restores ordinary hover/dismissal behavior")
  func pointerResumesNavigation() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.keyboardNavigation)
    _ = machine.handle(.pointerNavigation)
    let commands = machine.handle(.pointerChanged(.outside))
    #expect(commands.contains(.schedule(timer: .secondaryDismissal, after: 0.25)))
  }

  @Test("Panel-side reconfiguration preserves keyboard ownership when Settings closes")
  func panelSidePreservesKeyboardNavigation() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.keyboardNavigation)
    _ = machine.handle(.auxiliaryPresentationChanged(true))
    machine = machine.stabilized(auxiliaryIsPresented: true)
    _ = machine.handle(.auxiliaryPresentationChanged(false))
    let commands = machine.handle(.pointerChanged(.outside))
    #expect(commands.isEmpty)
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
  }

  @Test("Changing application ends keyboard ownership without reactivating the old app")
  func deactivationEndsKeyboardSession() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.keyboardNavigation)
    #expect(machine.handle(.applicationDeactivated).contains(.hideMain(restoreFocus: false)))
    #expect(machine.state == .hidden)
  }

  @Test("A Space transition invalidates keyboard pinning and old restoration")
  func spaceInvalidation() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.keyboardNavigation)
    let spaceCommands = machine.handle(.activeSpaceChanged)
    #expect(spaceCommands.contains(.reconcileActiveSpace(.mainAndSecondary(.quickNotes))))
    #expect(!machine.handle(.pointerChanged(.outside)).isEmpty)
    var restoration = FocusRestorationSession()
    restoration.begin()
    restoration.activeSpaceChanged()
    let restores = restoration.end(restoreRequested: true)
    #expect(!restores)
  }

  @Test("Closing Secondary leaves Main logically presented")
  func secondaryFocusReturn() {
    var machine = PanelStateMachine()
    _ = machine.handle(.openFromReminder(.quickNotes))
    _ = machine.handle(.keyboardNavigation)
    #expect(machine.handle(.clearSecondary) == [.hideSecondary])
    #expect(machine.state == .mainVisible(isEngaged: true))
  }

  @Test("Reminder content exposes its task and retires its accessibility subtree")
  func reminderContentLifecycle() {
    let panel = ReminderBannerPanel()
    let host = NSHostingView(rootView: ReminderBannerView(title: "Prepare slides", appearanceMode: .standard, action: {}))
    panel.presentContent(title: "Prepare slides", view: host)
    #expect(panel.accessibilityLabel() == "Reminder: Prepare slides")
    #expect(!panel.isAccessibilityHidden())
    #expect(!host.isAccessibilityHidden())
    #expect(!panel.isKeyWindow)
    panel.retireContent()
    #expect(panel.isAccessibilityHidden())
    #expect(host.isAccessibilityHidden())
    panel.presentContent(title: "Review draft", view: host)
    #expect(panel.accessibilityLabel() == "Reminder: Review draft")
    #expect(!host.isAccessibilityHidden())
    #expect(!panel.canBecomeKey)
  }

  @Test("Symbol controls and rich editors have contextual names")
  func names() {
    #expect(AccessibilityNames.completeTask("Prepare slides") == "Complete task: Prepare slides")
    #expect(AccessibilityNames.stepActions("Outline") == "Step actions: Outline")
    #expect(AccessibilityNames.stepTitle("Outline") == "Step title: Outline")
    #expect(AccessibilityNames.stepNotes("Outline") == "Step notes: Outline")
    #expect(AccessibilityNames.reminderTask("Prepare slides") == "Open reminded task: Prepare slides")
    #expect(AccessibilityNames.minuteAdjustment(purpose: "Reminder frequency", increasing: true) == "Increase reminder frequency")
    #expect(AccessibilityNames.minuteAdjustment(purpose: "Reminder pause", increasing: false) == "Decrease reminder pause")
  }
}

private final class KeyLoopProbePanel: NSPanel {
  var nextCount = 0
  var previousCount = 0
  override func selectNextKeyView(_ sender: Any?) { nextCount += 1 }
  override func selectPreviousKeyView(_ sender: Any?) { previousCount += 1 }
}
