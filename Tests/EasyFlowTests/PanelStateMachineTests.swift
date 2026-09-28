import Foundation
import Testing

@testable import EasyFlow

@Suite("Panel interaction state machine")
struct PanelStateMachineTests {
  private let timing = PanelTiming(
    activationDwell: 0.300,
    secondaryDismissalGrace: 0.250,
    mainDismissalGrace: 0.180
  )

  @Test("Leaving the hot zone cancels activation before dwell completes")
  func activationCancellation() {
    var machine = PanelStateMachine(timing: timing)

    #expect(
      machine.handle(.pointerChanged(.activationEdge)) == [
        .schedule(timer: .activationDwell, after: 0.300)
      ])
    #expect(machine.state == .dwelling)
    #expect(
      machine.handle(.pointerChanged(.outside)) == [
        .cancel(timer: .activationDwell)
      ])
    #expect(machine.state == .hidden)
    #expect(machine.handle(.activationDwellElapsed).isEmpty)
  }

  @Test("Completed dwell reveals Main and requests immediate Quick Note focus")
  func intentionalActivation() {
    var machine = activatedMachine()

    #expect(machine.state == .mainVisible(isEngaged: false))
    #expect(machine.handle(.userInteracted).isEmpty)
    #expect(machine.state == .mainVisible(isEngaged: true))
  }

  @Test("Newly opened accidental panel dismisses without grace")
  func immediateAccidentalDismissal() {
    var machine = activatedMachine()

    #expect(
      machine.handle(.pointerChanged(.outside)) == [
        .hideMain(restoreFocus: true)
      ])
    #expect(machine.state == .hidden)
  }

  @Test("Engaged Main receives a cancellable short dismissal grace")
  func engagedMainGrace() {
    var machine = activatedMachine()
    _ = machine.handle(.pointerChanged(.main))

    #expect(
      machine.handle(.pointerChanged(.outside)) == [
        .schedule(timer: .mainDismissal, after: 0.180)
      ])
    #expect(machine.state == .closingMain(previousContext: nil))
    #expect(
      machine.handle(.pointerChanged(.main)) == [
        .cancel(timer: .mainDismissal),
        .showMain,
      ])
    #expect(machine.state == .mainVisible(isEngaged: true))
    #expect(machine.handle(.mainDismissalElapsed).isEmpty)
  }

  @Test("Secondary closes before Main after a real interaction")
  func stagedSecondaryDismissal() {
    var machine = activatedMachine()

    #expect(
      machine.handle(.requestSecondary(.quickNotes)) == [
        .showSecondary(.quickNotes)
      ])
    #expect(
      machine.handle(.pointerChanged(.outside)) == [
        .schedule(timer: .secondaryDismissal, after: 0.250)
      ])
    #expect(
      machine.handle(.secondaryDismissalElapsed) == [
        .hideSecondary,
        .schedule(timer: .mainDismissal, after: 0.180),
      ])
    #expect(machine.state == .closingMain(previousContext: .quickNotes))
    #expect(
      machine.handle(.mainDismissalElapsed) == [
        .hideMain(restoreFocus: true)
      ])
    #expect(machine.state == .hidden)
  }

  @Test("Panel traversal cancels staged dismissal")
  func traversalCancelsDismissal() {
    var machine = activatedMachine()
    _ = machine.handle(.requestSecondary(.quickNotes))
    _ = machine.handle(.pointerChanged(.outside))

    #expect(
      machine.handle(.pointerChanged(.bridge)) == [
        .cancel(timer: .secondaryDismissal)
      ])
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
  }

  @Test("Secondary context updates in place")
  func secondaryContextSwitching() {
    var machine = activatedMachine()
    let taskID = UUID()

    _ = machine.handle(.requestSecondary(.quickNotes))
    #expect(
      machine.handle(.requestSecondary(.task(id: taskID))) == [
        .showSecondary(.task(id: taskID))
      ])
    #expect(machine.state == .secondaryVisible(context: .task(id: taskID)))
  }

  @Test("Quick Notes request shows Secondary and leaving a row for Main does not dismiss it")
  func quickNotesSecondaryPath() {
    var machine = activatedMachine()
    #expect(
      machine.handle(.requestSecondary(.quickNotes)) == [
        .showSecondary(.quickNotes)
      ])
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
    #expect(machine.handle(.pointerChanged(.main)).isEmpty)
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
  }

  @Test("Explicit collapse intent hides only Secondary")
  func explicitCollapseHidesSecondaryOnly() {
    var machine = activatedMachine()
    _ = machine.handle(.requestSecondary(.quickNotes))

    #expect(machine.handle(.clearSecondary) == [.hideSecondary])
    #expect(machine.state == .mainVisible(isEngaged: true))
    #expect(machine.state.isMainPresented)
    #expect(!machine.state.isSecondaryPresented)
  }

  @Test("Secondary pointer entry cancels a pending dismissal")
  func secondaryPointerCancelsPendingDismissal() {
    var machine = activatedMachine()
    _ = machine.handle(.requestSecondary(.quickNotes))
    _ = machine.handle(.pointerChanged(.outside))

    #expect(
      machine.handle(.pointerChanged(.secondary)) == [
        .cancel(timer: .secondaryDismissal)
      ])
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
    #expect(machine.handle(.secondaryDismissalElapsed).isEmpty)
  }

  @Test("Bridge to Secondary traversal remains stable")
  func bridgeToSecondaryTraversalIsStable() {
    var machine = activatedMachine()
    _ = machine.handle(.requestSecondary(.quickNotes))

    #expect(machine.handle(.pointerChanged(.bridge)).isEmpty)
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
    #expect(machine.handle(.pointerChanged(.secondary)).isEmpty)
    #expect(machine.state == .secondaryVisible(context: .quickNotes))
  }

  @Test("Stale Main collapse cannot win after pointer reaches Secondary or bridge")
  func latestPointerLocationGatesStaleCollapse() {
    #expect(!AppShellCoordinator.shouldApplySecondaryClear(latestPointerRegion: .secondary))
    #expect(!AppShellCoordinator.shouldApplySecondaryClear(latestPointerRegion: .bridge))
    #expect(AppShellCoordinator.shouldApplySecondaryClear(latestPointerRegion: .main))
    #expect(AppShellCoordinator.shouldApplySecondaryClear(latestPointerRegion: .outside))
  }

  @Test("Context replacement does not change presented state")
  func contextReplacementDoesNotReopenState() {
    var machine = activatedMachine()
    let first = UUID()
    let second = UUID()

    _ = machine.handle(.requestSecondary(.task(id: first)))
    #expect(
      machine.handle(.requestSecondary(.task(id: second))) == [
        .showSecondary(.task(id: second))
      ])
    #expect(machine.state == .secondaryVisible(context: .task(id: second)))
  }

  @Test("Reminder click opens Main and target task idempotently")
  func reminderClickOpensTargetTask() {
    var machine = PanelStateMachine(timing: timing)
    let taskID = UUID()

    #expect(
      machine.handle(.openFromReminder(.task(id: taskID))) == [
        .cancel(timer: .activationDwell),
        .cancel(timer: .secondaryDismissal),
        .cancel(timer: .mainDismissal),
        .showMain,
        .showSecondary(.task(id: taskID)),
      ])
    #expect(machine.state == .secondaryVisible(context: .task(id: taskID)))
    #expect(machine.handle(.mainDismissalElapsed).isEmpty)
    #expect(machine.handle(.secondaryDismissalElapsed).isEmpty)
  }

  @Test("Reminder click supersedes a pending Main dismissal")
  func reminderClickSupersedesPendingMainDismissal() {
    var machine = activatedMachine()
    let taskID = UUID()

    _ = machine.handle(.pointerChanged(.main))
    _ = machine.handle(.pointerChanged(.outside))
    #expect(machine.state == .closingMain(previousContext: nil))
    #expect(
      machine.handle(.openFromReminder(.task(id: taskID))) == [
        .cancel(timer: .activationDwell),
        .cancel(timer: .secondaryDismissal),
        .cancel(timer: .mainDismissal),
        .showMain,
        .showSecondary(.task(id: taskID)),
      ])
    #expect(machine.state == .secondaryVisible(context: .task(id: taskID)))
    #expect(machine.handle(.mainDismissalElapsed).isEmpty)
  }

  @Test("Reminder scheduler keeps active timer across unrelated workspace edits")
  func reminderSchedulerKeepsTimerForUnrelatedEdits() {
    let now = Date(timeIntervalSince1970: 1_000)
    let previous = ReminderScheduleState(
      settings: .defaults,
      activeTasks: [makeTask(title: "Original")]
    )
    let edited = ReminderScheduleState(
      settings: .defaults,
      activeTasks: [makeTask(title: "Edited title")]
    )

    #expect(
      ReminderSchedulePolicy.action(
        previous: previous,
        current: edited,
        timerIsActive: true,
        now: now
      ) == .keep
    )
  }

  @Test("Reminder scheduler reschedules only for settings and eligibility changes")
  func reminderSchedulerRescheduleBoundaries() {
    let now = Date(timeIntervalSince1970: 1_000)
    let active = ReminderScheduleState(
      settings: .defaults,
      activeTasks: [makeTask()]
    )
    var disabledSettings = ReminderSettings.defaults
    disabledSettings.isEnabled = false
    let disabled = ReminderScheduleState(
      settings: disabledSettings,
      activeTasks: [makeTask()]
    )
    let noEligible = ReminderScheduleState(
      settings: .defaults,
      activeTasks: [makeTask(excluded: true)]
    )
    let changedFrequency = ReminderScheduleState(
      settings: ReminderSettings(
        isEnabled: true,
        frequency: .minutes30,
        customInterval: ReminderSettings.defaultCustomInterval,
        pausedUntil: nil
      ),
      activeTasks: [makeTask()]
    )

    #expect(ReminderSchedulePolicy.action(previous: nil, current: active, timerIsActive: false, now: now) == .schedule(after: 3600))
    #expect(ReminderSchedulePolicy.action(previous: active, current: disabled, timerIsActive: true, now: now) == .cancel)
    #expect(ReminderSchedulePolicy.action(previous: active, current: changedFrequency, timerIsActive: true, now: now) == .schedule(after: 1800))
    #expect(ReminderSchedulePolicy.action(previous: noEligible, current: active, timerIsActive: false, now: now) == .schedule(after: 3600))
    #expect(ReminderSchedulePolicy.action(previous: active, current: noEligible, timerIsActive: true, now: now) == .cancel)
  }

  private func activatedMachine() -> PanelStateMachine {
    var machine = PanelStateMachine(timing: timing)
    _ = machine.handle(.pointerChanged(.activationEdge))
    #expect(
      machine.handle(.activationDwellElapsed) == [
        .showMain,
        .focusQuickNote,
      ])
    return machine
  }

  private func makeTask(
    title: String = "Task",
    excluded: Bool = false
  ) -> MainTask {
    MainTask(
      id: UUID(),
      reminderIdentifier: nil,
      title: title,
      effort: .one,
      sortIndex: 0,
      taskDescription: "",
      textColor: nil,
      highlightColor: nil,
      isUnderlined: false,
      remindersExcluded: excluded,
      taskDescriptionAttributes: nil,
      createdAt: Date(timeIntervalSince1970: 0),
      updatedAt: Date(timeIntervalSince1970: 0),
      completedAt: nil,
      deletedAt: nil
    )
  }
}
