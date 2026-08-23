import Foundation

struct ReminderCore: Equatable, Sendable {
  var title: String
  var isCompleted: Bool
}

enum ReminderReconciliationDecision: Equatable, Sendable {
  case noChange(ReminderCore)
  case apply(ReminderCore, pushExternal: Bool, pullLocal: Bool)
  case conflict
}

enum ReminderReconciler {
  static func decide(
    local: ReminderCore,
    baseline: ReminderCore,
    external: ReminderCore,
    localChangedAt: Date,
    externalChangedAt: Date?
  ) -> ReminderReconciliationDecision {
    var push = false
    var pull = false

    guard
      let title = resolve(
        local: local.title,
        baseline: baseline.title,
        external: external.title,
        localChangedAt: localChangedAt,
        externalChangedAt: externalChangedAt,
        push: &push,
        pull: &pull
      ),
      let completed = resolve(
        local: local.isCompleted,
        baseline: baseline.isCompleted,
        external: external.isCompleted,
        localChangedAt: localChangedAt,
        externalChangedAt: externalChangedAt,
        push: &push,
        pull: &pull
      )
    else {
      return .conflict
    }
    let resolved = ReminderCore(title: title, isCompleted: completed)
    if !push && !pull { return .noChange(resolved) }
    return .apply(resolved, pushExternal: push, pullLocal: pull)
  }

  private static func resolve<Value: Equatable>(
    local: Value,
    baseline: Value,
    external: Value,
    localChangedAt: Date,
    externalChangedAt: Date?,
    push: inout Bool,
    pull: inout Bool
  ) -> Value? {
    let localChanged = local != baseline
    let externalChanged = external != baseline
    if !localChanged && !externalChanged { return baseline }
    if localChanged && !externalChanged {
      push = true
      return local
    }
    if !localChanged && externalChanged {
      pull = true
      return external
    }
    if local == external { return local }
    guard let externalChangedAt else { return nil }
    if localChangedAt > externalChangedAt {
      push = true
      return local
    }
    if externalChangedAt > localChangedAt {
      pull = true
      return external
    }
    return nil
  }
}
