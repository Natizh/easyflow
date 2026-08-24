import Foundation
import Testing

@testable import EasyFlow

@Suite("Appearance modes")
struct AppearanceModeTests {
  @Test("macOS baseline always offers Standard and Frosted")
  func baselineModes() {
    #expect(AppearanceMode.available.contains(.standard))
    #expect(AppearanceMode.available.contains(.frosted))
  }

  @Test("Liquid Glass is exposed only where the API exists")
  func liquidGlassAvailability() {
    if #available(macOS 26, *) {
      #expect(AppearanceMode.available.contains(.liquidGlass))
    } else {
      #expect(!AppearanceMode.available.contains(.liquidGlass))
    }
  }

  @Test("Main Task density exposes compact and comfortable layout values")
  func mainTaskDensityValues() {
    #expect(MainTaskDensity.compact.label == "Compact")
    #expect(MainTaskDensity.comfortable.label == "Comfortable")
    #expect(MainTaskDensity.comfortable.taskRowSpacing > MainTaskDensity.compact.taskRowSpacing)
    #expect(
      MainTaskDensity.comfortable.taskRowVerticalPadding
        > MainTaskDensity.compact.taskRowVerticalPadding
    )
  }
}
