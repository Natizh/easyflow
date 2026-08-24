import Dispatch
@preconcurrency import EventKit

enum RemindersAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case fullAccess
  case denied
  case restricted
  case unavailable
}

@MainActor
protocol RemindersAuthorizing {
  var authorizationStatus: RemindersAuthorizationStatus { get }
  func requestFullAccess() async throws -> Bool
}

@MainActor
final class EventKitRemindersAuthorization: RemindersAuthorizing {
  private let eventStore: EKEventStore

  init(eventStore: EKEventStore = EKEventStore()) {
    self.eventStore = eventStore
  }

  var authorizationStatus: RemindersAuthorizationStatus {
    Self.map(EKEventStore.authorizationStatus(for: .reminder))
  }

  func requestFullAccess() async throws -> Bool {
    try await withCheckedThrowingContinuation { continuation in
      Self.requestFullAccess(eventStore: eventStore, continuation: continuation)
    }
  }

  static func map(_ status: EKAuthorizationStatus) -> RemindersAuthorizationStatus {
    switch status {
    case .notDetermined:
      .notDetermined
    case .fullAccess, .authorized:
      .fullAccess
    case .denied:
      .denied
    case .restricted:
      .restricted
    case .writeOnly:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  nonisolated private static func requestFullAccess(
    eventStore: EKEventStore,
    continuation: CheckedContinuation<Bool, any Error>
  ) {
    eventStore.requestFullAccessToReminders { isGranted, error in
      DispatchQueue.main.async {
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: isGranted)
        }
      }
    }
  }
}
