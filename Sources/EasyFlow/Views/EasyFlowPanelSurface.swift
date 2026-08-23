import SwiftUI

struct EasyFlowPanelSurface: ViewModifier {
  let mode: AppearanceMode
  @Environment(\.colorSchemeContrast) private var contrast
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    if #available(macOS 26, *), mode == .liquidGlass, !reduceTransparency {
      content
        .glassEffect(
          .regular.tint(EasyFlowBrand.indigo.opacity(0.08)),
          in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(border)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 6)
    } else {
      content
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(border)
        .shadow(color: .black.opacity(mode == .standard ? 0.16 : 0.12), radius: 16, y: 5)
    }
  }

  @ViewBuilder
  private var backgroundStyle: some View {
    if reduceTransparency || mode == .standard {
      Color(nsColor: .windowBackgroundColor).opacity(0.97)
    } else {
      Rectangle().fill(.ultraThinMaterial)
    }
  }

  private var border: some View {
    RoundedRectangle(cornerRadius: 22, style: .continuous)
      .strokeBorder(
        contrast == .increased
          ? Color.primary.opacity(0.34) : Color.white.opacity(0.12),
        lineWidth: contrast == .increased ? 1.5 : 1
      )
  }
}

extension View {
  func easyFlowPanelSurface(_ mode: AppearanceMode) -> some View {
    modifier(EasyFlowPanelSurface(mode: mode))
  }
}

struct EasyFlowMark: View {
  var body: some View {
    HStack(spacing: -3) {
      RoundedRectangle(cornerRadius: 2.5)
        .fill(EasyFlowBrand.lavender)
        .frame(width: 8, height: 14)
      RoundedRectangle(cornerRadius: 3)
        .fill(EasyFlowBrand.indigo)
        .frame(width: 10, height: 17)
    }
    .accessibilityLabel("EasyFlow")
  }
}
