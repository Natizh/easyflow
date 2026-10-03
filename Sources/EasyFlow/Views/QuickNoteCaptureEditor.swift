import AppKit
import SwiftUI

struct QuickNoteCaptureEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var attributes: RichTextAttributes
  let focusRequestID: Int
  let onCommit: () -> Void
  let onFocusLost: () -> Void
  var onPasteImages: (([Data]) -> Void)? = nil

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    let storage = EasyFlowRichText.textStorage()
    let textView = QuickNoteCaptureTextView(
      frame: .zero,
      textContainer: storage.layoutManagers.first?.textContainers.first
    )
    textView.delegate = context.coordinator
    textView.textStorage?.setAttributedString(
      EasyFlowRichText.attributedString(text: text, attributes: attributes)
    )
    textView.onCommit = onCommit
    textView.onPasteImages = onPasteImages
    textView.configureForEasyFlowCapture()
    scrollView.documentView = textView
    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let textView = scrollView.documentView as? QuickNoteCaptureTextView else { return }
    textView.onCommit = onCommit
    textView.onPasteImages = onPasteImages
    // A successful Return submission explicitly clears the still-focused
    // composer. Ordinary SwiftUI updates must preserve selection/IME state.
    let committedReset = context.coordinator.lastFocusRequestID != focusRequestID
      && text.isEmpty && attributes.isEmpty
    if NativeTextUpdatePolicy.shouldReplace(
      isEditing: textView.window?.firstResponder === textView,
      hasMarkedText: textView.hasMarkedText(),
      contentDiffers: textView.string != text || EasyFlowRichText.sidecar(from: textView.attributedString()) != attributes,
      committedCaptureReset: committedReset
    ) {
      textView.textStorage?.setAttributedString(
        EasyFlowRichText.attributedString(text: text, attributes: attributes)
      )
    }
    if context.coordinator.lastFocusRequestID != focusRequestID {
      context.coordinator.lastFocusRequestID = focusRequestID
      DispatchQueue.main.async {
        guard let window = textView.window as? OverlayPanel, window.isAvailableForFocus,
          window.isKeyWindow else { return }
        window.makeFirstResponder(textView)
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
      parent.attributes = EasyFlowRichText.sidecar(from: textView.attributedString())
      parent.text = textView.string
    }

    func textDidEndEditing(_ notification: Notification) {
      parent.onFocusLost()
    }

    func textView(
      _ textView: NSTextView,
      doCommandBy commandSelector: Selector
    ) -> Bool {
      guard Self.shouldCommit(commandSelector: commandSelector) else { return false }
      parent.onCommit()
      return true
    }

    static func shouldCommit(commandSelector: Selector) -> Bool {
      commandSelector == #selector(NSResponder.insertNewline(_:))
    }
  }
}

final class QuickNoteCaptureTextView: NoteImageTextView {
  var onCommit: (() -> Void)?

  func configureForEasyFlowCapture() {
    font = NSFont.preferredFont(forTextStyle: .body)
    textColor = .labelColor
    insertionPointColor = .controlAccentColor
    drawsBackground = false
    isRichText = true
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

}
