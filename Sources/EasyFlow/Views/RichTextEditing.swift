import AppKit

extension NSAttributedString.Key {
  static let easyFlowHighlight = NSAttributedString.Key("EasyFlowHighlight")
}

enum EasyFlowRichText {
  static let highlightColor: StyleColor = .yellow

  static func presentationAttributes(
    text: String,
    attributes: RichTextAttributes,
    legacyHighlight: StyleColor?
  ) -> RichTextAttributes {
    guard let legacyHighlight else { return attributes }
    let length = (text as NSString).length
    guard length > 0 else { return attributes }
    var runs = attributes.runs
    runs.append(
      RichTextAttributes.Run(
        location: 0,
        length: length,
        bold: false,
        italic: false,
        underline: false,
        highlightColor: legacyHighlight
      )
    )
    return RichTextAttributes(runs: runs)
  }

  static func storageAttributes(
    _ attributes: RichTextAttributes,
    text: String,
    removingLegacyHighlight legacyHighlight: StyleColor?
  ) -> RichTextAttributes {
    guard let legacyHighlight else { return attributes }
    let fullLength = (text as NSString).length
    return RichTextAttributes(
      runs: attributes.runs.compactMap { run in
        guard run.highlightColor == legacyHighlight,
          run.location == 0,
          run.length == fullLength
        else { return run }
        var stripped = run
        stripped.highlightColor = nil
        return stripped.isEmpty ? nil : stripped
      }
    )
  }

  static func textStorage() -> NSTextStorage {
    let storage = NSTextStorage()
    let manager = MarkerHighlightLayoutManager()
    let container = NSTextContainer()
    container.widthTracksTextView = true
    container.heightTracksTextView = false
    container.lineFragmentPadding = 0
    container.containerSize = NSSize(
      width: 0,
      height: CGFloat.greatestFiniteMagnitude
    )
    storage.addLayoutManager(manager)
    manager.addTextContainer(container)
    return storage
  }

  static func attributedString(
    text: String,
    attributes: RichTextAttributes,
    baseFont: NSFont = NSFont.preferredFont(forTextStyle: .body)
  ) -> NSAttributedString {
    let fullRange = NSRange(location: 0, length: (text as NSString).length)
    let result = NSMutableAttributedString(
      string: text,
      attributes: [
        .font: baseFont,
        .foregroundColor: NSColor.labelColor,
      ]
    )
    for run in attributes.runs {
      let range = NSRange(location: run.location, length: run.length)
      guard NSMaxRange(range) <= fullRange.length else { continue }
      if run.bold || run.italic {
        var font = baseFont
        if run.bold {
          font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if run.italic {
          font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        result.addAttribute(.font, value: font, range: range)
      }
      if run.underline {
        result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
      }
      if let highlightColor = run.highlightColor {
        result.addAttribute(.easyFlowHighlight, value: highlightColor.rawValue, range: range)
      }
    }
    return result
  }

  static func sidecar(from attributedString: NSAttributedString) -> RichTextAttributes {
    let fullRange = NSRange(location: 0, length: attributedString.length)
    var runs: [RichTextAttributes.Run] = []
    attributedString.enumerateAttributes(in: fullRange) { attributes, range, _ in
      let font = attributes[.font] as? NSFont
      let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
      let underlineStyle = attributes[.underlineStyle] as? Int ?? 0
      let highlightRaw = attributes[.easyFlowHighlight] as? String
      let run = RichTextAttributes.Run(
        location: range.location,
        length: range.length,
        bold: traits.contains(.boldFontMask),
        italic: traits.contains(.italicFontMask),
        underline: underlineStyle != 0,
        highlightColor: highlightRaw.flatMap(StyleColor.init(rawValue:))
      )
      if !run.isEmpty { runs.append(run) }
    }
    return RichTextAttributes(runs: merge(runs))
  }

  private static func merge(_ runs: [RichTextAttributes.Run]) -> [RichTextAttributes.Run] {
    var merged: [RichTextAttributes.Run] = []
    for run in runs {
      if var last = merged.last,
        last.location + last.length == run.location,
        last.bold == run.bold,
        last.italic == run.italic,
        last.underline == run.underline,
        last.highlightColor == run.highlightColor
      {
        last.length += run.length
        merged[merged.count - 1] = last
      } else {
        merged.append(run)
      }
    }
    return merged
  }
}

final class MarkerHighlightLayoutManager: NSLayoutManager {
  override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
    guard let textStorage else {
      super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
      return
    }
    let characterRange = characterRange(
      forGlyphRange: glyphsToShow,
      actualGlyphRange: nil
    )
    textStorage.enumerateAttribute(
      .easyFlowHighlight,
      in: characterRange
    ) { value, range, _ in
      guard let rawValue = value as? String,
        let color = StyleColor(rawValue: rawValue)
      else { return }
      let glyphRange = self.glyphRange(
        forCharacterRange: range,
        actualCharacterRange: nil
      )
      self.drawMarkerHighlight(
        color: color.nsColor.withAlphaComponent(0.28),
        glyphRange: glyphRange,
        origin: origin
      )
    }
    super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
  }

  private func drawMarkerHighlight(
    color: NSColor,
    glyphRange: NSRange,
    origin: NSPoint
  ) {
    guard let textContainer = textContainers.first else { return }
    enumerateEnclosingRects(
      forGlyphRange: glyphRange,
      withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
      in: textContainer
    ) { rect, _ in
      let adjusted = rect
        .insetBy(dx: -2.5, dy: 1.5)
        .offsetBy(dx: origin.x, dy: origin.y)
      color.setFill()
      NSBezierPath(roundedRect: adjusted, xRadius: 3, yRadius: 3).fill()
    }
  }
}

extension StyleColor {
  var nsColor: NSColor {
    switch self {
    case .red: .systemRed
    case .orange: .systemOrange
    case .yellow: .systemYellow
    case .green: .systemGreen
    case .blue: .systemBlue
    case .purple: .systemPurple
    }
  }
}
