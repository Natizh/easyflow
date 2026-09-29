import Testing

@testable import EasyFlow

@Suite("Previous application focus restoration")
struct FocusRestorationTests {
  @Test("Same-Space dismissal restores the previous application")
  func sameSpaceRestoration() {
    var session = FocusRestorationSession()

    session.begin()
    let shouldRestore = session.end(restoreRequested: true)

    #expect(shouldRestore)
    #expect(session.state == .idle)
  }

  @Test("Space change suppresses restoration for the presentation session")
  func changedSpaceSuppressesRestoration() {
    var session = FocusRestorationSession()
    session.begin()

    session.activeSpaceChanged()
    #expect(session.state == .invalidatedBySpaceChange)
    let shouldRestore = session.end(restoreRequested: true)
    #expect(!shouldRestore)
    #expect(session.state == .idle)
  }

  @Test("A later presentation starts a fresh eligible session")
  func laterPresentationCanRestore() {
    var session = FocusRestorationSession()
    session.begin()
    session.activeSpaceChanged()
    let firstShouldRestore = session.end(restoreRequested: true)
    #expect(!firstShouldRestore)

    session.begin()
    let secondShouldRestore = session.end(restoreRequested: true)

    #expect(secondShouldRestore)
  }

  @Test("Non-restoring dismissal consumes the session")
  func dismissalWithoutRestorationConsumesSession() {
    var session = FocusRestorationSession()
    session.begin()
    let shouldRestore = session.end(restoreRequested: false)

    #expect(!shouldRestore)
    #expect(session.state == .idle)
  }
}
