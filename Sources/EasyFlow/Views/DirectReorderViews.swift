import SwiftUI

struct DirectReorderHandle: View {
  let onChanged: (CGFloat) -> Void
  let onEnded: () -> Void
  @GestureState private var isDragging = false

  var body: some View {
    Image(systemName: "line.3.horizontal")
      .font(.caption)
      .foregroundStyle(isDragging ? Color.accentColor : Color.secondary)
      .frame(width: 18, height: 24)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
          .updating($isDragging) { _, state, _ in state = true }
          .onChanged { onChanged($0.translation.height) }
          .onEnded { _ in onEnded() }
      )
      .accessibilityLabel("Reorder")
  }
}

struct ReorderInsertionBar: View {
  var body: some View {
    Capsule()
      .fill(Color.accentColor)
      .frame(height: 2)
      .padding(.horizontal, 4)
      .transition(.opacity)
  }
}
