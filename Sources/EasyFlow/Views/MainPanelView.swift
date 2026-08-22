import SwiftUI

struct MainPanelView: View {
  @ObservedObject var model: AppShellViewModel
  @FocusState private var quickNoteIsFocused: Bool

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
    .onChange(of: model.focusRequestID) { _, _ in quickNoteIsFocused = true }
    .sheet(isPresented: $model.isSettingsPresented) { SettingsView() }
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
      TextEditor(
        text: Binding(
          get: { model.quickNoteDraft },
          set: { model.setQuickNoteDraft($0) }
        )
      )
      .font(.body)
      .scrollContentBackground(.hidden)
      .padding(7)
      .frame(minHeight: 76, maxHeight: 110)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
      .overlay(alignment: .topLeading) {
        if model.quickNoteDraft.isEmpty {
          Text("Start typing…")
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .allowsHitTesting(false)
        }
      }
      .focused($quickNoteIsFocused)
      .onKeyPress(keys: [.return]) { press in
        guard press.modifiers.contains(.command) else { return .ignored }
        model.commitQuickNoteIfNeeded()
        return .handled
      }
      .onChange(of: quickNoteIsFocused) { wasFocused, isFocused in
        if wasFocused && !isFocused { model.commitQuickNoteIfNeeded() }
      }
      if !model.snapshot.quickNotes.isEmpty {
        Text("\(model.snapshot.quickNotes.count) in inbox")
          .font(.caption)
          .foregroundStyle(.secondary)
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
          LazyVStack(spacing: 5) {
            ForEach(model.snapshot.activeTasks) { task in
              MainTaskRow(task: task, model: model)
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
  @State private var isDropTarget = false

  var body: some View {
    HStack(spacing: 8) {
      Button {
        model.completeMainTask(task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
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
    .workspaceDrag("task:\(task.id.uuidString)")
    .workspaceDrop(isTargeted: $isDropTarget) {
      model.handleDrop($0, on: task.id)
    }
    .contextMenu {
      AppearanceMenu(style: task.style) { model.updateMainTask(id: task.id, style: $0) }
      Divider()
      Button("Delete", role: .destructive) { model.deleteMainTask(task.id) }
    }
  }
}

struct EffortIndicator: View {
  let effort: Effort

  var body: some View {
    HStack(spacing: 2) {
      ForEach(1...4, id: \.self) { value in
        Circle()
          .fill(value <= effort.rawValue ? Color.accentColor : Color.secondary.opacity(0.2))
          .frame(width: 5, height: 5)
      }
    }
    .accessibilityLabel("Effort \(effort.rawValue) of 4")
  }
}

private struct SettingsView: View {
  var body: some View {
    Form {
      Section("EasyFlow") {
        LabeledContent("Storage", value: "Local SQLite with GRDB")
        LabeledContent("Activation", value: "Far-right edge · 300 ms")
        LabeledContent("Panels", value: "20% · 360–520 pt")
        LabeledContent("Appearance", value: "Standard")
      }
      Text("Launch at login and advanced appearance are reserved for Production Polish.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 430, height: 290)
  }
}
