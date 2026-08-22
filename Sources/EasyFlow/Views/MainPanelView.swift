import SwiftUI

struct MainPanelView: View {
  @ObservedObject var model: AppShellViewModel
  @FocusState private var quickNoteIsFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      quickNotes
      mainTasks
      Spacer(minLength: 12)
      recentlyCompleted
      footer
    }
    .padding(22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
    .onChange(of: model.focusRequestID) { _, _ in
      quickNoteIsFocused = true
    }
  }

  private var quickNotes: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Quick Notes", systemImage: "square.and.pencil")
        .font(.headline)

      TextEditor(text: $model.quickNoteDraft)
        .font(.body)
        .scrollContentBackground(.hidden)
        .padding(8)
        .frame(minHeight: 92, maxHeight: 132)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topLeading) {
          if model.quickNoteDraft.isEmpty {
            Text("Start typing…")
              .foregroundStyle(.secondary)
              .padding(.horizontal, 13)
              .padding(.vertical, 15)
              .allowsHitTesting(false)
          }
        }
        .focused($quickNoteIsFocused)
        .onChange(of: model.quickNoteDraft) { _, _ in
          model.registerInteraction()
        }

      Text("Local draft persistence arrives with the workspace data layer.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .contentShape(Rectangle())
    .onHover { isInside in
      if isInside {
        model.requestSecondary(.quickNotes)
      }
    }
  }

  private var mainTasks: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Main Tasks")
          .font(.headline)
        Spacer()
        Label("New Task", systemImage: "plus")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      placeholderRow(
        title: "Your current work will appear here",
        symbol: "checklist"
      )
    }
    .contentShape(Rectangle())
    .onHover { isInside in
      if isInside {
        model.clearSecondary()
      }
    }
  }

  private var recentlyCompleted: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Recently Completed")
        .font(.headline)
      placeholderRow(
        title: "Completed tasks stay within reach",
        symbol: "checkmark.circle"
      )
    }
    .contentShape(Rectangle())
    .onHover { isInside in
      if isInside {
        model.clearSecondary()
      }
    }
  }

  private var footer: some View {
    HStack {
      Text("App Shell")
        .font(.caption2)
        .foregroundStyle(.tertiary)
      Spacer()
      Image(systemName: "gearshape")
        .foregroundStyle(.secondary)
        .accessibilityLabel("Settings")
    }
    .contentShape(Rectangle())
    .onHover { isInside in
      if isInside {
        model.clearSecondary()
      }
    }
  }

  private func placeholderRow(title: String, symbol: String) -> some View {
    Label(title, systemImage: symbol)
      .font(.callout)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
  }
}
