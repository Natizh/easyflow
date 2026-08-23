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
}
