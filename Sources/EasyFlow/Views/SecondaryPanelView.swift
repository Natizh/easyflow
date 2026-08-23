import SwiftUI

struct SecondaryPanelView: View {
  @ObservedObject var model: AppShellViewModel

  var body: some View {
    Group {
      switch model.secondaryContext {
      case .quickNotes:
        QuickNotesBrowser(model: model)
      case .task(let id):
        if let task = model.snapshot.activeTasks.first(where: { $0.id == id }) {
          TaskDetailView(task: task, model: model).id(task.id)
        } else {
          ContentUnavailableView("Task unavailable", systemImage: "questionmark.circle")
        }
      case nil:
        Color.clear
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .coordinateSpace(name: SecondaryPanelCoordinateSpace.name)
    .padding(20)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
    .onTapGesture { model.registerInteraction() }
    .onPreferenceChange(StepRowGeometryPreferenceKey.self) { geometries in
      model.updateStepRows(Array(geometries.values))
    }
    .onPreferenceChange(StepExclusionGeometryPreferenceKey.self) {
      model.updateStepExclusions($0)
    }
  }
}

private struct QuickNotesBrowser: View {
  @ObservedObject var model: AppShellViewModel
  @State private var draggedNoteID: UUID?
  @State private var insertionIndex: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("Quick Notes", systemImage: "note.text").font(.title3.weight(.semibold))
      if model.snapshot.quickNotes.isEmpty {
        ContentUnavailableView(
          "Inbox Empty",
          systemImage: "tray",
          description: Text("Captured notes will appear here.")
        )
      } else {
        ScrollView {
          LazyVStack(spacing: 10) {
            ForEach(Array(model.snapshot.quickNotes.enumerated()), id: \.element.id) {
              index, note in
              if insertionIndex == index { ReorderInsertionBar() }
              NoteCard(
                note: note,
                model: model,
                isInbox: true,
                onReorderChanged: { translation in
                  draggedNoteID = note.id
                  insertionIndex = ReorderLogic.insertionIndex(
                    ids: model.snapshot.quickNotes.map(\.id),
                    draggedID: note.id,
                    translation: translation,
                    rowExtent: 132
                  )
                },
                onReorderEnded: {
                  if let insertionIndex {
                    model.reorderQuickNote(
                      draggedID: note.id,
                      toInsertionIndex: insertionIndex
                    )
                  }
                  draggedNoteID = nil
                  insertionIndex = nil
                }
              )
              .opacity(draggedNoteID == note.id ? 0.55 : 1)
            }
            if insertionIndex == model.snapshot.quickNotes.count {
              ReorderInsertionBar()
            }
          }
        }
      }
    }
  }
}

private struct NoteCard: View {
  let note: WorkspaceNote
  @ObservedObject var model: AppShellViewModel
  let isInbox: Bool
  let onReorderChanged: ((CGFloat) -> Void)?
  let onReorderEnded: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack {
        if let onReorderChanged, let onReorderEnded {
          DirectReorderHandle(
            onChanged: onReorderChanged,
            onEnded: onReorderEnded
          )
        }
        Text(note.displayTitle)
          .font(.headline)
          .lineLimit(1)
        Spacer()
        if isInbox {
          Image(systemName: "arrowshape.turn.up.right")
            .foregroundStyle(.secondary)
            .workspaceDrag("note:\(note.id.uuidString)")
            .help("Attach to Main Task")
        }
      }
      PersistedTextField(title: "Optional title", value: note.title ?? "") {
        model.updateNote(id: note.id, title: $0, body: note.body)
      }
      PersistedTextEditor(value: note.body, minimumHeight: 58) {
        model.updateNote(id: note.id, title: note.title, body: $0)
      }
      HStack {
        Text(note.createdAt, style: .relative)
          .font(.caption2)
          .foregroundStyle(.tertiary)
        Spacer()
        Button(role: .destructive) {
          model.deleteNote(note.id)
        } label: {
          Image(systemName: "trash")
        }
        .buttonStyle(.plain)
      }
    }
    .padding(10)
    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    .help(note.displayTitle + "\n" + note.preview)
  }
}

private struct TaskDetailView: View {
  let task: MainTask
  @ObservedObject var model: AppShellViewModel
  @State private var newStepTitle = ""

  private var steps: [TaskStep] { model.snapshot.stepsByTask[task.id] ?? [] }
  private var attachedNotes: [WorkspaceNote] {
    model.snapshot.attachedNotesByTask[task.id] ?? []
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack {
          PersistedTextField(title: "Task title", value: task.title) {
            model.updateMainTask(id: task.id, title: $0)
          }
          if task.effort == nil {
            VStack(alignment: .trailing, spacing: 3) {
              Text("Set effort")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
              HStack(spacing: 3) {
                ForEach(Effort.allCases, id: \.rawValue) { effort in
                  Button("\(effort.rawValue)") {
                    model.updateMainTask(id: task.id, effort: effort)
                  }
                  .buttonStyle(.bordered)
                  .controlSize(.small)
                }
              }
            }
            .accessibilityLabel("Effort not set")
          } else {
            Menu {
              ForEach(Effort.allCases, id: \.rawValue) { effort in
                Button("Effort \(effort.rawValue)") {
                  model.updateMainTask(id: task.id, effort: effort)
                }
              }
            } label: {
              EffortIndicator(effort: task.effort)
            }
            .menuStyle(.borderlessButton)
          }
        }
        section("Description") {
          AdaptiveDescriptionEditor(value: task.taskDescription) {
            model.updateMainTask(id: task.id, description: $0)
          }
        }
        section("Steps") {
          VStack(spacing: 7) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
              if model.routedStepInsertionIndex == index { ReorderInsertionBar() }
              StepRow(step: step, taskID: task.id, model: model)
                .opacity(model.routedStepDragID == step.id ? 0.55 : 1)
            }
            if model.routedStepInsertionIndex == steps.count {
              ReorderInsertionBar()
            }
            HStack {
              TextField("New step", text: $newStepTitle).onSubmit(addStep)
              Button(action: addStep) { Image(systemName: "plus.circle.fill") }
                .buttonStyle(.plain)
                .disabled(
                  newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
          }
        }
        section("Notes") {
          if attachedNotes.isEmpty {
            Text("Drag a Quick Note onto this task.")
              .font(.callout)
              .foregroundStyle(.secondary)
          } else {
            VStack(spacing: 10) {
              ForEach(attachedNotes) { note in
                NoteCard(
                  note: note,
                  model: model,
                  isInbox: false,
                  onReorderChanged: nil,
                  onReorderEnded: nil
                )
              }
            }
          }
        }
      }
    }
  }

  private func addStep() {
    let title = newStepTitle
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    model.createStep(mainTaskID: task.id, title: title)
    newStepTitle = ""
  }

  private func section<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      content()
    }
  }
}

private struct StepRow: View {
  let step: TaskStep
  let taskID: UUID
  @ObservedObject var model: AppShellViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Button {
          model.updateStep(id: step.id, isCompleted: !step.isCompleted)
        } label: {
          Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
        }
        .buttonStyle(.plain)
        .background { StepExclusionReporter(stepID: step.id) }
        PersistedTextField(title: "Step", value: step.title) {
          model.updateStep(id: step.id, title: $0)
        }
        .background { StepExclusionReporter(stepID: step.id) }
        .textFieldStyle(.plain)
        .foregroundStyle(step.style.textColor?.color ?? .primary)
        .padding(.horizontal, step.style.highlightColor == nil ? 0 : 3)
        .background(step.style.highlightColor?.color.opacity(0.25))
        .overlay(alignment: .bottom) {
          if step.style.isUnderlined {
            Rectangle()
              .fill(step.style.textColor?.color ?? .primary)
              .frame(height: 1)
          }
        }
      }
      PersistedTextField(title: "Notes", value: step.notes) {
        model.updateStep(id: step.id, notes: $0)
      }
      .font(.caption)
      .background { StepExclusionReporter(stepID: step.id) }
    }
    .opacity(step.isCompleted ? 0.52 : 1)
    .padding(8)
    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    .background {
      GeometryReader { proxy in
        let frame = proxy.frame(in: .named(SecondaryPanelCoordinateSpace.name))
        Color.clear.preference(
          key: StepRowGeometryPreferenceKey.self,
          value: [
            step.id: MainTaskRowGeometry(
              taskID: step.id,
              rowFrame: frame,
              reorderFrame: frame
            )
          ]
        )
      }
    }
    .contextMenu {
      AppearanceMenu(style: step.style) { model.updateStep(id: step.id, style: $0) }
      Divider()
      Button("Delete", role: .destructive) { model.deleteStep(step.id) }
    }
  }
}

private struct StepExclusionReporter: View {
  let stepID: UUID

  var body: some View {
    GeometryReader { proxy in
      Color.clear.preference(
        key: StepExclusionGeometryPreferenceKey.self,
        value: [
          stepID: [proxy.frame(in: .named(SecondaryPanelCoordinateSpace.name))]
        ]
      )
    }
  }
}
