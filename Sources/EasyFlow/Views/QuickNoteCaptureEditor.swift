import AppKit
import SwiftUI

struct QuickNoteCaptureEditor: NSViewRepresentable {
  @Binding var text: String
  let focusRequestID: Int
  let onCommit: () -> Void
  let onFocusLost: () -> Void
  let onHover: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    let textView = QuickNoteCaptureTextView()
    textView.delegate = context.coordinator
    textView.string = text
    textView.onCommit = onCommit
    textView.onHover = onHover
    textView.configureForEasyFlowCapture()
    scrollView.documentView = textView
    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let textView = scrollView.documentView as? QuickNoteCaptureTextView else { return }
    textView.onCommit = onCommit
    textView.onHover = onHover
    if textView.string != text {
      textView.string = text
    }
    if context.coordinator.lastFocusRequestID != focusRequestID {
      context.coordinator.lastFocusRequestID = focusRequestID
      DispatchQueue.main.async {
        textView.window?.makeFirstResponder(textView)
      }
    }
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: QuickNoteCaptureEditor
    weak var textView: QuickNoteCaptureTextView?
    var lastFocusRequestID: Int

    init(parent: QuickNoteCaptureEditor) {
      self.parent = parent
      lastFocusRequestID = parent.focusRequestID
    }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      parent.text = textView.string
    }

    func textDidEndEditing(_ notification: Notification) {
      parent.onFocusLost()
    }

    func textView(
      _ textView: NSTextView,
      doCommandBy commandSelector: Selector
    ) -> Bool {
      guard commandSelector == #selector(NSResponder.insertNewline(_:)),
        NSApplication.shared.currentEvent?.modifierFlags.contains(.command) == true
      else {
        return false
      }
      parent.onCommit()
      return true
    }
  }
}

final class QuickNoteCaptureTextView: NSTextView {
  var onCommit: (() -> Void)?
  var onHover: (() -> Void)?
  private var hoverTrackingArea: NSTrackingArea?

  func configureForEasyFlowCapture() {
    font = NSFont.preferredFont(forTextStyle: .body)
    textColor = .labelColor
    insertionPointColor = .controlAccentColor
    drawsBackground = false
    isRichText = false
    importsGraphics = false
    allowsUndo = true
    isAutomaticQuoteSubstitutionEnabled = true
    isAutomaticDashSubstitutionEnabled = true
    isAutomaticTextReplacementEnabled = true
    isVerticallyResizable = true
    isHorizontallyResizable = false
    autoresizingMask = [.width]
    textContainerInset = NSSize(width: 10, height: 9)
    textContainer?.lineFragmentPadding = 0
    textContainer?.widthTracksTextView = true
    textContainer?.containerSize = NSSize(
      width: 0,
      height: CGFloat.greatestFiniteMagnitude
    )
    setAccessibilityLabel("Quick Note")
  }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
    let area = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    hoverTrackingArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    super.mouseEntered(with: event)
    onHover?()
  }
}
