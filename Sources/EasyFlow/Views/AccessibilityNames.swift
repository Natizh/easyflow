import Foundation

/// Shared names for controls whose symbols do not convey their purpose.
enum AccessibilityNames {
  static func completeTask(_ title: String) -> String { "Complete task: \(title)" }
  static func stepActions(_ title: String) -> String { "Step actions: \(title)" }
  static func stepTitle(_ title: String) -> String { "Step title: \(title)" }
  static func stepNotes(_ title: String) -> String { "Step notes: \(title)" }
  static func reminderTask(_ title: String) -> String { "Open reminded task: \(title)" }
  static func minuteAdjustment(purpose: String, increasing: Bool) -> String {
    "\(increasing ? "Increase" : "Decrease") \(purpose.lowercased())"
  }
}
