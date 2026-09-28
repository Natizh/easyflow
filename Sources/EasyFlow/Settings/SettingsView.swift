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
        Section("EasyFlow Reminders") {
          Toggle(
            "Show reminder banners",
            isOn: Binding(
              get: { model.reminderSettings.isEnabled },
              set: { model.setRemindersEnabled($0) }
            )
          )
          Picker(
            "Frequency",
            selection: Binding(
              get: { frequencySelection },
              set: { model.setReminderFrequency($0.frequency(customInterval: model.reminderSettings.customInterval)) }
            )
          ) {
            ForEach(ReminderFrequencySelection.allCases) { option in
              Text(option.label).tag(option)
            }
          }
          if frequencySelection == .custom {
            Stepper(
              "Every \(customMinutes) minutes",
              value: Binding(
                get: { customMinutes },
                set: { model.setReminderCustomInterval(minutes: $0) }
              ),
              in: 1...720,
              step: 5
            )
          }
          if let pausedUntil = model.reminderSettings.pausedUntil,
            pausedUntil > Date()
          {
            HStack {
              Text("Paused until \(pausedUntil.formatted(date: .abbreviated, time: .shortened))")
              Spacer()
              Button("Resume") { model.resumeReminders() }
            }
          }
          HStack {
            Text("Pause")
            Spacer()
            Button("1 hour") { model.pauseReminders(.oneHour) }
            Button("3 hours") { model.pauseReminders(.threeHours) }
            Button("Until Tomorrow") { model.pauseReminders(.untilTomorrow) }
          }
          Stepper(
            "Custom pause \(customPauseMinutes) minutes",
            value: Binding(
              get: { customPauseMinutes },
              set: { customPauseMinutes = $0 }
            ),
            in: 1...720,
            step: 5
          )
          Button("Pause Custom") {
            model.pauseReminders(minutes: customPauseMinutes)
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

  @State private var customPauseMinutes = 60

  private var customMinutes: Int {
    max(1, Int(model.reminderSettings.customInterval / 60))
  }

  private var frequencySelection: ReminderFrequencySelection {
    switch model.reminderSettings.frequency {
    case .minutes15: .minutes15
    case .minutes30: .minutes30
    case .hour1: .hour1
    case .hours2: .hours2
    case .hours3: .hours3
    case .custom: .custom
    }
  }
}

private enum ReminderFrequencySelection: String, CaseIterable, Identifiable {
  case minutes15
  case minutes30
  case hour1
  case hours2
  case hours3
  case custom

  var id: Self { self }

  var label: String {
    switch self {
    case .minutes15: "15 minutes"
    case .minutes30: "30 minutes"
    case .hour1: "1 hour"
    case .hours2: "2 hours"
    case .hours3: "3 hours"
    case .custom: "Custom..."
    }
  }

  func frequency(customInterval: TimeInterval) -> ReminderFrequency {
    switch self {
    case .minutes15: .minutes15
    case .minutes30: .minutes30
    case .hour1: .hour1
    case .hours2: .hours2
    case .hours3: .hours3
    case .custom: .custom(customInterval)
    }
  }
}
