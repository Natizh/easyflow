import Foundation

enum SecondaryPanelContext: Equatable, Sendable {
  case quickNotes
  case task(id: UUID)
}

enum PointerRegion: Equatable, Sendable {
  case activationEdge
  case main
  case secondary
  case bridge
  case outside

  var isInsideEasyFlow: Bool {
    self != .outside
  }
}

enum PanelTimer: Equatable, Hashable, Sendable {
  case activationDwell
  case secondaryDismissal
  case mainDismissal
}

struct PanelTiming: Equatable, Sendable {
  var activationDwell: TimeInterval = 0.300
  var secondaryDismissalGrace: TimeInterval = 0.250
  var mainDismissalGrace: TimeInterval = 0.180
}

enum PanelInteractionState: Equatable, Sendable {
  case hidden
  case dwelling
  case mainVisible(isEngaged: Bool)
  case secondaryVisible(context: SecondaryPanelContext)
  case closingSecondary(context: SecondaryPanelContext)
  case closingMain(previousContext: SecondaryPanelContext?)

  var isMainPresented: Bool {
    self != .hidden && self != .dwelling
  }

  var isSecondaryPresented: Bool {
    switch self {
    case .secondaryVisible, .closingSecondary:
      true
    case .hidden, .dwelling, .mainVisible, .closingMain:
      false
    }
  }
}

enum PanelEvent: Equatable, Sendable {
  case pointerChanged(PointerRegion)
  case activationDwellElapsed
  case userInteracted
  case requestSecondary(SecondaryPanelContext)
  case clearSecondary
  case secondaryDismissalElapsed
  case mainDismissalElapsed
}

enum PanelCommand: Equatable, Sendable {
  case schedule(timer: PanelTimer, after: TimeInterval)
  case cancel(timer: PanelTimer)
  case showMain
  case focusQuickNote
  case hideMain(restoreFocus: Bool)
  case showSecondary(SecondaryPanelContext)
  case hideSecondary
}

struct PanelStateMachine: Equatable, Sendable {
  private(set) var state: PanelInteractionState = .hidden
  let timing: PanelTiming

  init(timing: PanelTiming = PanelTiming()) {
    self.timing = timing
  }

  mutating func handle(_ event: PanelEvent) -> [PanelCommand] {
    switch (state, event) {
    case (.hidden, .pointerChanged(.activationEdge)):
      state = .dwelling
      return [.schedule(timer: .activationDwell, after: timing.activationDwell)]

    case (.hidden, _):
      return []

    case (.dwelling, .pointerChanged(.activationEdge)):
      return []

    case (.dwelling, .pointerChanged):
      state = .hidden
      return [.cancel(timer: .activationDwell)]

    case (.dwelling, .activationDwellElapsed):
      state = .mainVisible(isEngaged: false)
      return [.showMain, .focusQuickNote]

    case (.dwelling, _):
      return []

    case (.mainVisible(let isEngaged), .pointerChanged(let region)):
      return handleMainPointer(region, isEngaged: isEngaged)

    case (.mainVisible, .userInteracted):
      state = .mainVisible(isEngaged: true)
      return []

    case (.mainVisible, let .requestSecondary(context)):
      state = .secondaryVisible(context: context)
      return [.showSecondary(context)]

    case (.mainVisible, _):
      return []

    case (.secondaryVisible(let currentContext), .requestSecondary(let newContext)):
      guard currentContext != newContext else { return [] }
      state = .secondaryVisible(context: newContext)
      return [.showSecondary(newContext)]

    case (.secondaryVisible, .clearSecondary):
      state = .mainVisible(isEngaged: true)
      return [.hideSecondary]

    case (.secondaryVisible(let context), .pointerChanged(.outside)):
      state = .closingSecondary(context: context)
      return [
        .schedule(
          timer: .secondaryDismissal,
          after: timing.secondaryDismissalGrace
        )
      ]

    case (.secondaryVisible, .pointerChanged),
      (.secondaryVisible, .userInteracted):
      return []

    case (.secondaryVisible, _):
      return []

    case (.closingSecondary(let context), .pointerChanged(let region))
    where region.isInsideEasyFlow:
      state = .secondaryVisible(context: context)
      return [.cancel(timer: .secondaryDismissal)]

    case (.closingSecondary, .requestSecondary(let context)):
      state = .secondaryVisible(context: context)
      return [
        .cancel(timer: .secondaryDismissal),
        .showSecondary(context),
      ]

    case (.closingSecondary, .clearSecondary):
      state = .mainVisible(isEngaged: true)
      return [
        .cancel(timer: .secondaryDismissal),
        .hideSecondary,
      ]

    case (.closingSecondary(let context), .secondaryDismissalElapsed):
      state = .closingMain(previousContext: context)
      return [
        .hideSecondary,
        .schedule(timer: .mainDismissal, after: timing.mainDismissalGrace),
      ]

    case (.closingSecondary, _):
      return []

    case (.closingMain(let previousContext), .pointerChanged(let region))
    where region.isInsideEasyFlow:
      return resumeFromClosingMain(
        region: region,
        previousContext: previousContext
      )

    case (.closingMain, .requestSecondary(let context)):
      state = .secondaryVisible(context: context)
      return [
        .cancel(timer: .mainDismissal),
        .showSecondary(context),
      ]

    case (.closingMain, .mainDismissalElapsed):
      state = .hidden
      return [.hideMain(restoreFocus: true)]

    case (.closingMain, _):
      return []
    }
  }

  private mutating func handleMainPointer(
    _ region: PointerRegion,
    isEngaged: Bool
  ) -> [PanelCommand] {
    switch region {
    case .main, .secondary:
      state = .mainVisible(isEngaged: true)
      return []
    case .outside where !isEngaged:
      state = .hidden
      return [.hideMain(restoreFocus: true)]
    case .outside:
      state = .closingMain(previousContext: nil)
      return [
        .schedule(timer: .mainDismissal, after: timing.mainDismissalGrace)
      ]
    case .activationEdge, .bridge:
      return []
    }
  }

  private mutating func resumeFromClosingMain(
    region: PointerRegion,
    previousContext: SecondaryPanelContext?
  ) -> [PanelCommand] {
    if let previousContext,
      region == .secondary || region == .bridge
    {
      state = .secondaryVisible(context: previousContext)
      return [
        .cancel(timer: .mainDismissal),
        .showSecondary(previousContext),
      ]
    }

    state = .mainVisible(isEngaged: true)
    return [.cancel(timer: .mainDismissal)]
  }
}
