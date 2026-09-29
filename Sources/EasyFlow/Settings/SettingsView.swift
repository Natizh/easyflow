import SwiftUI

enum SettingsWindowMetrics {
  static let contentWidth: CGFloat = 480

  static func contentHeight(
    remindersEnabled: Bool,
    showsCustomFrequency: Bool,
    showsCustomPause: Bool,
    showsPausedStatus: Bool
  ) -> CGFloat {
    guard remindersEnabled else { return 480 }
    let revealedRows =
      (showsCustomFrequency ? 1 : 0)
      + (showsCustomPause ? 1 : 0)
      + (showsPausedStatus ? 1 : 0)
    return 580 + CGFloat(revealedRows * 42)
  }
}

struct SettingsView: View {
  let dismiss: () -> Void
  @ObservedObject var model: AppShellViewModel
  let preferredHeightChanged: (CGFloat) -> Void

  @State private var customPauseMinutes = 60
  @State private var showsCustomPause = false

  init(
    dismiss: @escaping () -> Void,
    model: AppShellViewModel,
    preferredHeightChanged: @escaping (CGFloat) -> Void = { _ in }
  ) {
    self.dismiss = dismiss
    self.model = model
    self.preferredHeightChanged = preferredHeightChanged
  }

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
              set: { enabled in
                withAnimation(.easeInOut(duration: 0.18)) {
                  if !enabled { showsCustomPause = false }
                  model.setRemindersEnabled(enabled)
                }
              }
            )
          )

          if model.reminderSettings.isEnabled {
            Group {
              Picker(
                "Frequency",
                selection: Binding(
                  get: { frequencySelection },
                  set: { selection in
                    withAnimation(.easeInOut(duration: 0.18)) {
                      model.setReminderFrequency(
                        selection.frequency(
                          customInterval: model.reminderSettings.customInterval
                        )
                      )
                    }
                  }
                )
              ) {
                ForEach(ReminderFrequencySelection.allCases) { option in
                  Text(option.label).tag(option)
                }
              }

              if frequencySelection == .custom {
                HStack {
                  Text("Custom")
                  Spacer()
                  MinuteAdjuster(
                    minutes: customMinutes,
                    decrement: {
                      model.setReminderCustomInterval(
                        minutes: ReminderMinuteRange.decrementing(customMinutes)
                      )
                    },
                    increment: {
                      model.setReminderCustomInterval(
                        minutes: ReminderMinuteRange.incrementing(customMinutes)
                      )
                    }
                  )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

              HStack(spacing: 8) {
                Text("Pause")
                Spacer()
                Button("1 hour") { pause(.oneHour) }
                Button("3 hours") { pause(.threeHours) }
                Button("Until Tomorrow") { pause(.untilTomorrow) }
                Button("Custom…") {
                  withAnimation(.easeInOut(duration: 0.18)) {
                    showsCustomPause.toggle()
                  }
                }
              }
              .controlSize(.small)

              if showsCustomPause {
                HStack {
                  Text("Pause for")
                  Spacer()
                  MinuteAdjuster(
                    minutes: customPauseMinutes,
                    decrement: {
                      customPauseMinutes = ReminderMinuteRange.decrementing(customPauseMinutes)
                    },
                    increment: {
                      customPauseMinutes = ReminderMinuteRange.incrementing(customPauseMinutes)
                    }
                  )
                  Button("Pause") {
                    model.pauseReminders(minutes: customPauseMinutes)
                    withAnimation(.easeInOut(duration: 0.18)) {
                      showsCustomPause = false
                    }
                  }
                  .buttonStyle(.borderedProminent)
                  .controlSize(.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
              }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
      }
      .formStyle(.grouped)
      Text(AppVersion.label())
        .font(.caption).foregroundStyle(.secondary).padding(.bottom, 16)
    }
    .frame(width: SettingsWindowMetrics.contentWidth)
    .animation(.easeInOut(duration: 0.18), value: model.reminderSettings.isEnabled)
    .onExitCommand { dismiss() }
    .onAppear {
      model.refreshLaunchAtLoginStatus()
      reportPreferredHeight()
    }
    .onChange(of: model.reminderSettings.isEnabled) { _, _ in reportPreferredHeight() }
    .onChange(of: frequencySelection) { _, _ in reportPreferredHeight() }
    .onChange(of: model.reminderSettings.pausedUntil) { _, _ in reportPreferredHeight() }
    .onChange(of: showsCustomPause) { _, _ in reportPreferredHeight() }
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

  private var customMinutes: Int {
    ReminderMinuteRange.clamped(Int(model.reminderSettings.customInterval / 60))
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

  private func pause(_ preset: ReminderPausePreset) {
    showsCustomPause = false
    model.pauseReminders(preset)
  }

  private func reportPreferredHeight() {
    preferredHeightChanged(
      SettingsWindowMetrics.contentHeight(
        remindersEnabled: model.reminderSettings.isEnabled,
        showsCustomFrequency: frequencySelection == .custom,
        showsCustomPause: showsCustomPause,
        showsPausedStatus: model.reminderSettings.isPaused(at: Date())
      )
    )
  }
}

private struct MinuteAdjuster: View {
  let minutes: Int
  let decrement: () -> Void
  let increment: () -> Void

  var body: some View {
    HStack(spacing: 7) {
      adjustmentButton(
        systemName: "minus",
        accessibilityLabel: "Decrease minutes",
        disabled: minutes <= ReminderMinuteRange.minimum,
        action: decrement
      )
      Text("\(minutes) min")
        .monospacedDigit()
        .frame(minWidth: 62)
        .accessibilityLabel("\(minutes) minutes")
      adjustmentButton(
        systemName: "plus",
        accessibilityLabel: "Increase minutes",
        disabled: minutes >= ReminderMinuteRange.maximum,
        action: increment
      )
    }
  }

  private func adjustmentButton(
    systemName: String,
    accessibilityLabel: String,
    disabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 12, weight: .semibold))
        .frame(width: 28, height: 22)
        .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
    .disabled(disabled)
    .accessibilityLabel(accessibilityLabel)
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
    case .custom: "Custom…"
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
