import SwiftUI

struct PersistedTextField: View {
  let title: String
  let value: String
  let onSave: (String) -> Void
  @State private var text: String
  @FocusState private var isFocused: Bool

  init(title: String, value: String, onSave: @escaping (String) -> Void) {
    self.title = title
    self.value = value
    self.onSave = onSave
    _text = State(initialValue: value)
  }

  var body: some View {
    TextField(title, text: $text, axis: .vertical)
      .fixedSize(horizontal: false, vertical: true)
      .focused($isFocused)
      .onSubmit { onSave(text) }
      .onDisappear { if text != value { onSave(text) } }
      .onReceive(NotificationCenter.default.publisher(for: .easyFlowFlushEditors)) { _ in if text != value { onSave(text) } }
      .onChange(of: isFocused) { wasFocused, focused in
        if wasFocused && !focused { onSave(text) }
      }
      .onChange(of: value) { _, newValue in
        if !isFocused { text = newValue }
      }
  }
}

struct PersistedTextEditor: View {
  let value: String
  var minimumHeight: CGFloat = 58
  var maximumHeight: CGFloat = 180
  var label = "Note body"
  var onPasteImages: (([Data]) -> Void)? = nil
  let onSave: (String) -> Void
  @State private var text: String
  @State private var height: CGFloat = 58

  init(value: String, minimumHeight: CGFloat = 58, maximumHeight: CGFloat = 180,
    label: String = "Note body", onPasteImages: (([Data]) -> Void)? = nil,
    onSave: @escaping (String) -> Void) {
    self.value = value
    self.minimumHeight = minimumHeight
    self.maximumHeight = maximumHeight
    self.label = label
    self.onPasteImages = onPasteImages
    self.onSave = onSave
    _text = State(initialValue: value)
  }

  var body: some View {
    AdaptiveTextEditor(text: $text, height: $height,
      minimumHeight: minimumHeight, maximumHeight: maximumHeight,
      onSave: onSave, label: label, onPasteImages: onPasteImages)
      .frame(height: max(minimumHeight, height))
      .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
      .onChange(of: value) { _, newValue in text = newValue }
  }
}

extension Notification.Name {
  static let easyFlowFlushEditors = Notification.Name("EasyFlow.flushEditors")
}
