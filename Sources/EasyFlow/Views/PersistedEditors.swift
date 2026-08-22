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
    TextField(title, text: $text)
      .focused($isFocused)
      .onSubmit { onSave(text) }
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
  let minimumHeight: CGFloat
  let onSave: (String) -> Void
  @State private var text: String
  @State private var saveTask: Task<Void, Never>?
  @FocusState private var isFocused: Bool

  init(value: String, minimumHeight: CGFloat = 70, onSave: @escaping (String) -> Void) {
    self.value = value
    self.minimumHeight = minimumHeight
    self.onSave = onSave
    _text = State(initialValue: value)
  }

  var body: some View {
    TextEditor(text: $text)
      .scrollContentBackground(.hidden)
      .padding(6)
      .frame(minHeight: minimumHeight)
      .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
      .focused($isFocused)
      .onChange(of: text) { _, newValue in scheduleSave(newValue) }
      .onChange(of: isFocused) { wasFocused, focused in
        if wasFocused && !focused { flush() }
      }
      .onChange(of: value) { _, newValue in
        if !isFocused { text = newValue }
      }
      .onDisappear(perform: flush)
  }

  private func scheduleSave(_ value: String) {
    saveTask?.cancel()
    saveTask = Task { @MainActor in
      do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
      guard !Task.isCancelled else { return }
      onSave(value)
    }
  }

  private func flush() {
    saveTask?.cancel()
    saveTask = nil
    onSave(text)
  }
}
