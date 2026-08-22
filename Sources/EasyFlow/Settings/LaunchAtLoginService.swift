import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
struct LaunchAtLoginService {
  private let service: SMAppService

  init(service: SMAppService = .mainApp) {
    self.service = service
  }

  var status: LaunchAtLoginStatus {
    Self.map(service.status)
  }

  func setEnabled(_ isEnabled: Bool) throws {
    if isEnabled {
      try service.register()
    } else {
      try service.unregister()
    }
  }

  static func map(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
    switch status {
    case .notRegistered:
      .disabled
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }
}
