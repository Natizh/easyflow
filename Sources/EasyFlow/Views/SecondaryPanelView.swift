import SwiftUI

struct SecondaryPanelView: View {
  @ObservedObject var model: AppShellViewModel

  var body: some View {
    Group {
      switch model.secondaryContext {
      case .quickNotes:
        quickNotesPlaceholder
      case .task(let id):
        taskPlaceholder(id: id)
      case nil:
        Color.clear
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(22)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
    .onTapGesture {
      model.registerInteraction()
    }
  }

  private var quickNotesPlaceholder: some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Quick Notes", systemImage: "note.text")
        .font(.title3.weight(.semibold))
      Text(
        "Saved notes will be browsable, editable, reorderable, and movable to Main Tasks in the local workspace chunk."
      )
      .foregroundStyle(.secondary)
      Spacer()
    }
  }

  private func taskPlaceholder(id: UUID) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("Task Details", systemImage: "checklist")
        .font(.title3.weight(.semibold))
      Text("Description, Steps, and Attached Notes will share this contextual panel.")
        .foregroundStyle(.secondary)
      Text(id.uuidString)
        .font(.caption2.monospaced())
        .foregroundStyle(.tertiary)
      Spacer()
    }
  }
}
