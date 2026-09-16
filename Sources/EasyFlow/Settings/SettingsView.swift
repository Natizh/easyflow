import SwiftUI

struct SettingsView: View {
  let dismiss: () -> Void
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
          LabeledContent("Storage", value: "Stored on this Mac")
          LabeledContent("Activation", value: "\(model.panelSide == .right ? "Far-right" : "Far-left") edge · 300 ms")
          LabeledContent("Panels", value: "20% · 360–520 pt")
          Picker("Panel Side", selection: $model.panelSide) {
            ForEach(PanelSide.allCases) { side in Text(side.label).tag(side) }
          }
          .pickerStyle(.segmented)
          Picker("Appearance", selection: $model.appearanceMode) {
            ForEach(AppearanceMode.available) { mode in
              Text(mode.label).tag(mode)
            }
          }
          Picker("Main Task Rows", selection: $model.mainTaskDensity) {
            ForEach(MainTaskDensity.allCases) { density in
              Text(density.label).tag(density)
            }
          }
          .pickerStyle(.segmented)
          Toggle(
            "Launch at Login",
            isOn: Binding(
              get: { model.launchAtLoginStatus == .enabled },
              set: { model.setLaunchAtLogin($0) }
            )
          )
          if model.launchAtLoginStatus == .requiresApproval {
            Text("Approve EasyFlow in System Settings > General > Login Items.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
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
      }
      .formStyle(.grouped)
      Text(AppVersion.label())
        .font(.caption).foregroundStyle(.secondary).padding(.bottom, 16)
    }
    .frame(width: 480)
    .onExitCommand { dismiss() }
    .onAppear { model.refreshLaunchAtLoginStatus() }
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

