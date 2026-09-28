import AppKit
import SwiftUI

final class ReminderBannerPanel: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  init() {
    super.init(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
      backing: .buffered,
      defer: true
    )
    isFloatingPanel = true
    level = .statusBar
    collectionBehavior = [
      .canJoinAllSpaces,
      .fullScreenAuxiliary,
      .stationary,
      .ignoresCycle,
    ]
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    hidesOnDeactivate = false
    isMovable = false
    isReleasedWhenClosed = false
    acceptsMouseMovedEvents = true
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
  }
}

struct ReminderBannerView: View {
  let title: String
  let appearanceMode: AppearanceMode
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "bell.badge")
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(EasyFlowBrand.indigo)
        VStack(alignment: .leading, spacing: 2) {
          Text("Remember your task")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(width: 320, height: 64)
      .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
    .easyFlowPanelSurface(appearanceMode)
  }
}
