import Testing

@testable import EasyFlow

@Suite("Reminder Settings presentation")
struct SettingsPresentationTests {
  @Test("Minute controls use bounded five-minute adjustments")
  func minuteAdjustmentBounds() {
    #expect(ReminderMinuteRange.decrementing(60) == 55)
    #expect(ReminderMinuteRange.incrementing(60) == 65)
    #expect(ReminderMinuteRange.decrementing(ReminderMinuteRange.minimum) == 5)
    #expect(ReminderMinuteRange.incrementing(ReminderMinuteRange.maximum) == 720)
    #expect(ReminderMinuteRange.clamped(1) == 5)
    #expect(ReminderMinuteRange.clamped(10_000) == 720)
    #expect(ReminderFrequency.custom(60).interval == 5 * 60)
    #expect(ReminderFrequency.custom(24 * 60 * 60).interval == 12 * 60 * 60)
  }

  @Test("Disabled reminders collapse Settings to its compact height")
  func disabledHeightIsCompact() {
    let disabled = SettingsWindowMetrics.contentHeight(
      remindersEnabled: false,
      showsCustomFrequency: true,
      showsCustomPause: true,
      showsPausedStatus: true
    )
    let enabled = SettingsWindowMetrics.contentHeight(
      remindersEnabled: true,
      showsCustomFrequency: false,
      showsCustomPause: false,
      showsPausedStatus: false
    )

    #expect(disabled == 480)
    #expect(disabled < enabled)
  }

  @Test("Only visible custom rows add window height")
  func customRowsDriveHeight() {
    let base = SettingsWindowMetrics.contentHeight(
      remindersEnabled: true,
      showsCustomFrequency: false,
      showsCustomPause: false,
      showsPausedStatus: false
    )
    let frequency = SettingsWindowMetrics.contentHeight(
      remindersEnabled: true,
      showsCustomFrequency: true,
      showsCustomPause: false,
      showsPausedStatus: false
    )
    let both = SettingsWindowMetrics.contentHeight(
      remindersEnabled: true,
      showsCustomFrequency: true,
      showsCustomPause: true,
      showsPausedStatus: false
    )

    #expect(abs(frequency - base - 42) < 0.001)
    #expect(abs(both - base - 84) < 0.001)
  }
}
