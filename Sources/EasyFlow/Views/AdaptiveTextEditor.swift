import AppKit
import SwiftUI

enum AdaptiveTextMetrics {
  static func height(
    contentHeight: CGFloat,
    minimum: CGFloat,
    maximum: CGFloat
  ) -> CGFloat {
    min(max(contentHeight, minimum), maximum)
  }
}

struct AdaptiveTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var height: CGFloat
  let minimumHeight: CGFloat
  let maximumHeight: CGFloat
  let onSave: (String) -> Void

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.autohidesScrollers = true

    let textView = NSTextView()
    textView.delegate = context.coordinator
    textView.font = NSFont.preferredFont(forTextStyle: .body)
    textView.drawsBackground = false
    textView.isRichText = false
    textView.allowsUndo = true
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainerInset = NSSize(width: 8, height: 7)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.string = text
    scrollView.documentView = textView
    context.coordinator.textView = textView
    context.coordinator.scrollView = scrollView
    DispatchQueue.main.async { context.coordinator.measure() }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let textView = context.coordinator.textView else { return }
    if textView.string != text { textView.string = text }
    DispatchQueue.main.async { context.coordinator.measure() }
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: AdaptiveTextEditor
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    var saveTask: Task<Void, Never>?

    init(parent: AdaptiveTextEditor) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      parent.text = textView.string
      measure()
      saveTask?.cancel()
      let value = textView.string
      saveTask = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
        parent.onSave(value)
      }
    }

    func textDidEndEditing(_ notification: Notification) {
      saveTask?.cancel()
      if let textView { parent.onSave(textView.string) }
    }

    func measure() {
      guard let textView, let textContainer = textView.textContainer else { return }
      textView.layoutManager?.ensureLayout(for: textContainer)
      let usedHeight = textView.layoutManager?.usedRect(for: textContainer).height ?? 0
      let contentHeight = usedHeight + (textView.textContainerInset.height * 2) + 2
      let clamped = AdaptiveTextMetrics.height(
        contentHeight: contentHeight,
        minimum: parent.minimumHeight,
        maximum: parent.maximumHeight
      )
      if abs(parent.height - clamped) > 0.5 { parent.height = clamped }
      scrollView?.hasVerticalScroller = contentHeight > parent.maximumHeight
    }
  }
}

struct AdaptiveDescriptionEditor: View {
  let value: String
  let onSave: (String) -> Void
  @State private var text: String
  @State private var height: CGFloat = 42

  init(value: String, onSave: @escaping (String) -> Void) {
    self.value = value
    self.onSave = onSave
    _text = State(initialValue: value)
  }

  var body: some View {
    AdaptiveTextEditor(
      text: $text,
      height: $height,
      minimumHeight: 42,
      maximumHeight: 156,
      onSave: onSave
    )
    .frame(height: height)
    .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
    .onChange(of: value) { _, newValue in text = newValue }
  }
}
