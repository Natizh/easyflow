import SwiftUI

@MainActor
final class AppShellViewModel: ObservableObject {
  @Published var quickNoteDraft = ""
  @Published private(set) var focusRequestID = 0
  @Published var secondaryContext: SecondaryPanelContext?

  var onInteraction: (() -> Void)?
  var onSecondaryRequested: ((SecondaryPanelContext) -> Void)?
  var onSecondaryCleared: (() -> Void)?

  func requestQuickNoteFocus() {
    focusRequestID &+= 1
  }

  func registerInteraction() {
    onInteraction?()
  }

  func requestSecondary(_ context: SecondaryPanelContext) {
    onInteraction?()
    onSecondaryRequested?(context)
  }

  func clearSecondary() {
    onSecondaryCleared?()
  }
}
