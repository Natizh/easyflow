import EventKit
import ServiceManagement
import Testing

@testable import EasyFlow

@Suite("Prepared platform boundaries")
struct InfrastructureBoundaryTests {
  @Test(
    "EventKit authorization states map without requesting access",
    arguments: [
      (EKAuthorizationStatus.notDetermined, RemindersAuthorizationStatus.notDetermined),
      (.fullAccess, .fullAccess),
      (.denied, .denied),
      (.restricted, .restricted),
      (.writeOnly, .unavailable),
    ])
  @MainActor
  func reminderAuthorizationMapping(
    input: EKAuthorizationStatus,
    expected: RemindersAuthorizationStatus
  ) {
    #expect(EventKitRemindersAuthorization.map(input) == expected)
  }

  @Test(
    "ServiceManagement statuses map to product-facing states",
    arguments: [
      (SMAppService.Status.notRegistered, LaunchAtLoginStatus.disabled),
      (.enabled, .enabled),
      (.requiresApproval, .requiresApproval),
      (.notFound, .unavailable),
    ])
  @MainActor
  func launchAtLoginMapping(
    input: SMAppService.Status,
    expected: LaunchAtLoginStatus
  ) {
    #expect(LaunchAtLoginService.map(input) == expected)
  }
}
