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

enum NativeTextUpdatePolicy {
  static func shouldReplace(isEditing: Bool, hasMarkedText: Bool, contentDiffers: Bool, committedCaptureReset: Bool = false) -> Bool {
    contentDiffers && !hasMarkedText && (!isEditing || committedCaptureReset)
  }
}

struct AdaptiveTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var height: CGFloat
  var attributes: RichTextAttributes = .empty
  let minimumHeight: CGFloat
  let maximumHeight: CGFloat
  let onSave: (String) -> Void
  var onSaveRichText: ((RichTextValue) -> Void)? = nil
  var label = "Task Description"
  var onPasteImages: (([Data]) -> Void)? = nil

  func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.autohidesScrollers = true

    let storage = EasyFlowRichText.textStorage()
    let textView = MeasuredNoteTextView(
      frame: .zero,
      textContainer: storage.layoutManagers.first?.textContainers.first
    )
    textView.onPasteImages = onPasteImages
    textView.onWidthChanged = { [weak coordinator = context.coordinator] in coordinator?.measure() }
    textView.delegate = context.coordinator
    textView.font = NSFont.preferredFont(forTextStyle: .body)
    textView.drawsBackground = false
    textView.isRichText = true
    textView.importsGraphics = false
    textView.allowsUndo = true
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainerInset = NSSize(width: 8, height: 7)
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = true
    textView.textStorage?.setAttributedString(
      EasyFlowRichText.attributedString(text: text, attributes: attributes)
    )
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
    if NativeTextUpdatePolicy.shouldReplace(
      isEditing: textView.window?.firstResponder === textView,
      hasMarkedText: textView.hasMarkedText(),
      contentDiffers: textView.string != text || EasyFlowRichText.sidecar(from: textView.attributedString()) != attributes
    ) {
      textView.textStorage?.setAttributedString(
        EasyFlowRichText.attributedString(text: text, attributes: attributes)
      )
    }
    textView.setAccessibilityLabel(label)
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
      save(textView)
      isDirty = false
    }

    func textDidChange(_ notification: Notification) {
      guard let textView else { return }
      isDirty = true
      parent.text = textView.string
      measure()
      saveTask?.cancel()
      let value = RichTextValue(
        text: textView.string,
        attributes: EasyFlowRichText.sidecar(from: textView.attributedString())
      )
      saveTask = Task { @MainActor in
        do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
        parent.save(value)
        if textView.string == value.text { isDirty = false }
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

    private func save(_ textView: NSTextView) {
      parent.save(
        RichTextValue(
          text: textView.string,
          attributes: EasyFlowRichText.sidecar(from: textView.attributedString())
        )
      )
    }
  }

  fileprivate func save(_ value: RichTextValue) {
    if let onSaveRichText {
      onSaveRichText(value)
    } else {
      onSave(value.text)
    }
  }
}

struct AdaptiveDescriptionEditor: View {
  let value: String
  var attributes: RichTextAttributes = .empty
  let onSave: (String) -> Void
  var onSaveRichText: ((RichTextValue) -> Void)? = nil
  @State private var text: String
  @State private var height: CGFloat = 42

  init(
    value: String,
    attributes: RichTextAttributes = .empty,
    onSaveRichText: ((RichTextValue) -> Void)? = nil,
    onSave: @escaping (String) -> Void
  ) {
    self.value = value
    self.attributes = attributes
    self.onSaveRichText = onSaveRichText
    self.onSave = onSave
    _text = State(initialValue: value)
  }

  var body: some View {
    AdaptiveTextEditor(
      text: $text,
      height: $height,
      attributes: attributes,
      minimumHeight: 42,
      maximumHeight: 156,
      onSave: onSave,
      onSaveRichText: onSaveRichText
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
