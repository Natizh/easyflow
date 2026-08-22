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
        .cancel(timer: .mainDismissal)
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
}
