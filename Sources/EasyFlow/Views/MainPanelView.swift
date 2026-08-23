import SwiftUI

struct MainPanelView: View {
  @ObservedObject var model: AppShellViewModel
  @State private var draggedTaskID: UUID?
  @State private var taskInsertionIndex: Int?
  @State private var draggedNoteID: UUID?
  @State private var noteInsertionIndex: Int?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      quickNotes
      mainTasks
      recentlyCompleted
      Spacer(minLength: 4)
      footer
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
    .sheet(isPresented: $model.isSettingsPresented) { SettingsView(model: model) }
    .alert(
      "EasyFlow",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("OK") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Unknown error")
    }
  }

  private var quickNotes: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Quick Notes", systemImage: "square.and.pencil").font(.headline)
      QuickNoteCaptureEditor(
        text: Binding(
          get: { model.quickNoteDraft },
          set: { model.setQuickNoteDraft($0) }
        ),
        focusRequestID: model.focusRequestID,
        onCommit: model.commitQuickNoteIfNeeded,
        onFocusLost: model.commitQuickNoteIfNeeded
      )
      .frame(minHeight: 76, maxHeight: 110)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
      .onHover { if $0 { model.requestSecondary(.quickNotes) } }
      if !model.snapshot.quickNotes.isEmpty {
        ScrollView {
          LazyVStack(spacing: 3) {
            ForEach(Array(model.snapshot.quickNotes.enumerated()), id: \.element.id) {
              index, note in
              if noteInsertionIndex == index { ReorderInsertionBar() }
              CompactQuickNoteRow(
                note: note,
                model: model,
                onReorderChanged: { translation in
                  draggedNoteID = note.id
                  noteInsertionIndex = ReorderLogic.insertionIndex(
                    ids: model.snapshot.quickNotes.map(\.id),
                    draggedID: note.id,
                    translation: translation,
                    rowExtent: 42
                  )
                },
                onReorderEnded: {
                  if let insertion = noteInsertionIndex {
                    model.reorderQuickNote(
                      draggedID: note.id,
                      toInsertionIndex: insertion
                    )
                  }
                  draggedNoteID = nil
                  noteInsertionIndex = nil
                }
              )
              .opacity(draggedNoteID == note.id ? 0.55 : 1)
            }
            if noteInsertionIndex == model.snapshot.quickNotes.count {
              ReorderInsertionBar()
            }
          }
        }
        .frame(maxHeight: 112)
      }
    }
    .contentShape(Rectangle())
    .onHover { if $0 { model.requestSecondary(.quickNotes) } }
  }

  private var mainTasks: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Main Tasks").font(.headline)
        Spacer()
        Button {
          model.isCreatingTask.toggle()
        } label: {
          Label("New Task", systemImage: "plus").font(.caption)
        }
        .buttonStyle(.plain)
      }
      if model.isCreatingTask { NewTaskComposer(model: model) }
      if model.snapshot.activeTasks.isEmpty {
        Text("No active tasks")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.vertical, 8)
      } else {
        ScrollView {
          LazyVStack(spacing: 3) {
            ForEach(Array(model.snapshot.activeTasks.enumerated()), id: \.element.id) {
              index, task in
              if taskInsertionIndex == index { ReorderInsertionBar() }
              MainTaskRow(
                task: task,
                model: model,
                onReorderChanged: { translation in
                  draggedTaskID = task.id
                  taskInsertionIndex = ReorderLogic.insertionIndex(
                    ids: model.snapshot.activeTasks.map(\.id),
                    draggedID: task.id,
                    translation: translation,
                    rowExtent: 46
                  )
                },
                onReorderEnded: {
                  if let insertion = taskInsertionIndex {
                    model.reorderMainTask(
                      draggedID: task.id,
                      toInsertionIndex: insertion
                    )
                  }
                  draggedTaskID = nil
                  taskInsertionIndex = nil
                }
              )
              .opacity(draggedTaskID == task.id ? 0.55 : 1)
            }
            if taskInsertionIndex == model.snapshot.activeTasks.count {
              ReorderInsertionBar()
            }
          }
        }
        .frame(maxHeight: 320)
      }
    }
  }

  private var recentlyCompleted: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Recently Completed").font(.headline)
      if model.snapshot.recentlyCompleted.isEmpty {
        Text("Nothing completed yet").font(.callout).foregroundStyle(.secondary)
      } else {
        ForEach(model.snapshot.recentlyCompleted) { task in
          Label(task.title, systemImage: "checkmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
    }
    .contentShape(Rectangle())
    .onHover { if $0 { model.clearSecondary() } }
  }

  private var footer: some View {
    HStack {
      Text("Local Workspace").font(.caption2).foregroundStyle(.tertiary)
      Spacer()
      Button {
        model.isSettingsPresented = true
      } label: {
        Image(systemName: "gearshape")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Settings")
    }
  }
}

private struct NewTaskComposer: View {
  @ObservedObject var model: AppShellViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Task title", text: $model.newTaskTitle)
        .textFieldStyle(.roundedBorder)
        .onSubmit { model.createMainTask() }
      HStack {
        Text("Effort").font(.caption).foregroundStyle(.secondary)
        ForEach(Effort.allCases, id: \.rawValue) { effort in
          Button("\(effort.rawValue)") { model.newTaskEffort = effort }
            .buttonStyle(.bordered)
            .tint(model.newTaskEffort == effort ? .accentColor : .secondary)
        }
        Spacer()
        Button("Add") { model.createMainTask() }
          .disabled(
            model.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || model.newTaskEffort == nil
          )
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
  }
}

private struct MainTaskRow: View {
  let task: MainTask
  @ObservedObject var model: AppShellViewModel
  let onReorderChanged: (CGFloat) -> Void
  let onReorderEnded: () -> Void
  @State private var isDropTarget = false

  var body: some View {
    HStack(spacing: 8) {
      Button {
        model.completeMainTask(task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      DirectReorderHandle(
        onChanged: onReorderChanged,
        onEnded: onReorderEnded
      )
      StyledLabel(task.title, style: task.style).lineLimit(2)
      Spacer(minLength: 6)
      EffortIndicator(effort: task.effort)
    }
    .padding(.horizontal, 9)
    .padding(.vertical, 8)
    .background(
      isDropTarget ? Color.accentColor.opacity(0.18) : Color.clear,
      in: RoundedRectangle(cornerRadius: 9)
    )
    .contentShape(Rectangle())
    .onHover { if $0 { model.requestSecondary(.task(id: task.id)) } }
    .workspaceDrop(isTargeted: $isDropTarget) {
      guard $0.hasPrefix("note:") else { return false }
      return model.handleDrop($0, on: task.id)
    }
    .contextMenu {
      AppearanceMenu(style: task.style) { model.updateMainTask(id: task.id, style: $0) }
      Divider()
      Button("Delete", role: .destructive) { model.deleteMainTask(task.id) }
    }
  }
}

struct EffortIndicator: View {
  let effort: Effort?

  var body: some View {
    Group {
      if let effort {
        HStack(spacing: 2) {
          ForEach(1...4, id: \.self) { value in
            Circle()
              .fill(
                value <= effort.rawValue
                  ? Color.accentColor : Color.secondary.opacity(0.2)
              )
              .frame(width: 5, height: 5)
          }
        }
        .accessibilityLabel("Effort \(effort.rawValue) of 4")
      } else {
        Text("?")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
          .help("Effort not set")
          .accessibilityLabel("Effort not set")
      }
    }
  }
}

private struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var model: AppShellViewModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Settings").font(.title2.weight(.semibold))
        Spacer()
        Button("Done") { dismiss() }
          .keyboardShortcut(.defaultAction)
          .accessibilityLabel("Close Settings")
      }
      .padding()
      Divider()
      Form {
        Section("EasyFlow") {
          LabeledContent("Storage", value: "Local SQLite with GRDB")
          LabeledContent("Activation", value: "Far-right edge · 300 ms")
          LabeledContent("Panels", value: "20% · 360–520 pt")
          LabeledContent("Appearance", value: "Standard")
          HStack {
            Text("Reminders")
            Spacer()
            Text(remindersStatusLabel).foregroundStyle(.secondary)
            if model.remindersStatus != .connected {
              Button("Retry") { model.retryRemindersSync() }
            }
            if model.remindersStatus == .denied {
              Button("Privacy Settings") { model.openRemindersPrivacySettings() }
            }
          }
        }
        Text("Launch at login and advanced appearance are reserved for Production Polish.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .formStyle(.grouped)
    }
    .frame(width: 430, height: 290)
    .onExitCommand { dismiss() }
    .background {
      Button("") { dismiss() }
        .keyboardShortcut("w", modifiers: .command)
        .hidden()
    }
  }

  private var remindersStatusLabel: String {
    switch model.remindersStatus {
    case .connected: "Connected"
    case .needsAccess: "Needs Access"
    case .requesting: "Requesting…"
    case .synchronizing: "Synchronizing…"
    case .denied: "Access Denied"
    case .ambiguousList: "Multiple EasyFlow Lists"
    case .error: "Error"
    }
  }
}

private struct CompactQuickNoteRow: View {
  let note: WorkspaceNote
  @ObservedObject var model: AppShellViewModel
  let onReorderChanged: (CGFloat) -> Void
  let onReorderEnded: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      DirectReorderHandle(
        onChanged: onReorderChanged,
        onEnded: onReorderEnded
      )
      VStack(alignment: .leading, spacing: 1) {
        Text(note.displayTitle).font(.callout.weight(.medium)).lineLimit(1)
        Text(note.preview).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer(minLength: 4)
      Image(systemName: "arrowshape.turn.up.right")
        .font(.caption)
        .foregroundStyle(.secondary)
        .workspaceDrag("note:\(note.id.uuidString)")
        .help("Attach to Main Task")
    }
    .padding(.horizontal, 7)
    .padding(.vertical, 5)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    .contentShape(Rectangle())
    .onHover { if $0 { model.requestSecondary(.quickNotes) } }
    .contextMenu {
      Button("Delete", role: .destructive) { model.deleteNote(note.id) }
    }
  }
}
