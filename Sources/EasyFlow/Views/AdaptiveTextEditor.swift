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
  var label = "Task Description"
  var onPasteImages: (([Data]) -> Void)? = nil

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.autohidesScrollers = true

    let textView = MeasuredNoteTextView()
    textView.onPasteImages = onPasteImages
    textView.onWidthChanged = { [weak coordinator = context.coordinator] in coordinator?.measure() }
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
    textView.setAccessibilityLabel(label)
    textView.textContainer?.containerSize.height = CGFloat.greatestFiniteMagnitude
    scrollView.documentView = textView
    context.coordinator.textView = textView
    context.coordinator.scrollView = scrollView
    DispatchQueue.main.async { context.coordinator.measure() }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.parent = self
    guard let textView = context.coordinator.textView else { return }
    if textView.string != text, textView.window?.firstResponder !== textView { textView.string = text }
    (textView as? NoteImageTextView)?.onPasteImages = onPasteImages
    DispatchQueue.main.async { context.coordinator.measure() }
  }

  static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
    coordinator.textDidEndEditing(Notification(name: NSText.didEndEditingNotification))
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: AdaptiveTextEditor
    weak var textView: NSTextView?
    weak var scrollView: NSScrollView?
    var saveTask: Task<Void, Never>?
    var isDirty = false

    init(parent: AdaptiveTextEditor) {
      self.parent = parent
      super.init()
      NotificationCenter.default.addObserver(self, selector: #selector(flush), name: .easyFlowFlushEditors, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc func flush() {
      saveTask?.cancel()
      guard isDirty, let textView else { return }
      parent.onSave(textView.string)
      isDirty = false
    }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      isDirty = true
      parent.text = textView.string
      measure()
      saveTask?.cancel()
      let value = textView.string
      saveTask = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
        parent.onSave(value)
        if textView.string == value { isDirty = false }
      }
    }

    func textDidEndEditing(_ notification: Notification) {
      flush()
    }

    func measure() {
      guard let textView, let textContainer = textView.textContainer else { return }
      let width = scrollView?.contentSize.width ?? textView.bounds.width
      guard width > 1 else { return }
      textContainer.containerSize = NSSize(width: max(1, width - textView.textContainerInset.width * 2), height: CGFloat.greatestFiniteMagnitude)
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

final class MeasuredNoteTextView: NoteImageTextView {
  var onWidthChanged: (() -> Void)?
  override func setFrameSize(_ newSize: NSSize) {
    let changed = abs(newSize.width - frame.width) > 0.5
    super.setFrameSize(newSize)
    if changed { DispatchQueue.main.async { [weak self] in self?.onWidthChanged?() } }
  }
}
