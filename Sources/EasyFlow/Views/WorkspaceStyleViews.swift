import SwiftUI

struct StyledLabel: View {
  let text: String
  let style: ItemStyle

  init(_ text: String, style: ItemStyle) {
    self.text = text
    self.style = style
  }

  var body: some View {
    Text(text)
      .foregroundStyle(style.textColor?.color ?? .primary)
      .underline(style.isUnderlined)
      .padding(.horizontal, style.highlightColor == nil ? 0 : 3)
      .background(style.highlightColor?.color.opacity(0.25))
  }
}

struct AppearanceMenu: View {
  let style: ItemStyle
  let onChange: (ItemStyle) -> Void

  var body: some View {
    Menu("Text Color") {
      Button("Default") { change(textColor: nil) }
      ForEach(StyleColor.allCases, id: \.rawValue) { color in
        Button(color.label) { change(textColor: color) }
      }
    }
    Menu("Highlight") {
      Button("None") { change(highlightColor: nil) }
      ForEach(StyleColor.allCases, id: \.rawValue) { color in
        Button(color.label) { change(highlightColor: color) }
      }
    }
    Button(style.isUnderlined ? "Remove Underline" : "Underline") {
      var changed = style
      changed.isUnderlined.toggle()
      onChange(changed)
    }
  }

  private func change(textColor: StyleColor?) {
    var changed = style
    changed.textColor = textColor
    onChange(changed)
  }

  private func change(highlightColor: StyleColor?) {
    var changed = style
    changed.highlightColor = highlightColor
    onChange(changed)
  }
}

extension StyleColor {
  var label: String { rawValue.capitalized }

  var color: Color {
    switch self {
    case .red: .red
    case .orange: .orange
    case .yellow: .yellow
    case .green: .green
    case .blue: .blue
    case .purple: .purple
    }
  }
}
