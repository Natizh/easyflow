import AppKit

/// Native text editing stays AppKit-owned. Images are separate note-owned attachments.
class NoteImageTextView: NSTextView {
  var onPasteImages: (([Data]) -> Void)?
  static let toggleBoldSelector = #selector(toggleBoldface(_:))
  static let toggleItalicSelector = #selector(toggleItalics(_:))
  static let toggleUnderlineSelector = #selector(toggleUnderline(_:))
  static let toggleHighlightSelector = #selector(toggleEasyFlowHighlight(_:))

  override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
    onPasteImages == nil ? super.readablePasteboardTypes
      : ClipboardImageReader.types + super.readablePasteboardTypes
  }

  override func readSelection(from pboard: NSPasteboard) -> Bool {
    if let onPasteImages {
      let images = ClipboardImageReader.images(from: pboard)
      if !images.isEmpty {
        onPasteImages(images)
        return true
      }
    }
    return super.readSelection(from: pboard)
  }

  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(paste(_:)), isEditable,
      onPasteImages != nil, ClipboardImageReader.hasImages(.general)
    { return true }
    return super.validateMenuItem(menuItem)
  }

  override func insertTab(_ sender: Any?) { window?.selectNextKeyView(sender) }
  override func insertBacktab(_ sender: Any?) { window?.selectPreviousKeyView(sender) }

  override func keyDown(with event: NSEvent) {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let key = event.charactersIgnoringModifiers?.lowercased()
    if modifiers == [.command], key == "b" {
      toggleBoldface(nil)
      return
    }
    if modifiers == [.command], key == "i" {
      toggleItalics(nil)
      return
    }
    if modifiers == [.command], key == "u" {
      toggleUnderline(nil)
      return
    }
    if modifiers == [.command, .control], key == "h" {
      toggleEasyFlowHighlight(nil)
      return
    }
    super.keyDown(with: event)
  }

  @objc func toggleBoldface(_ sender: Any?) {
    toggleFontTrait(.boldFontMask)
  }

  @objc func toggleItalics(_ sender: Any?) {
    toggleFontTrait(.italicFontMask)
  }

  @objc func toggleUnderline(_ sender: Any?) {
    toggleAttribute(
      key: .underlineStyle,
      enabledValue: NSUnderlineStyle.single.rawValue
    )
  }

  @objc func toggleEasyFlowHighlight(_ sender: Any?) {
    toggleAttribute(
      key: .easyFlowHighlight,
      enabledValue: EasyFlowRichText.highlightColor.rawValue
    )
  }

  private func toggleFontTrait(_ trait: NSFontTraitMask) {
    let range = selectedRange()
    if range.length == 0 {
      var attributes = typingAttributes
      let currentFont = attributes[.font] as? NSFont ?? font ?? .preferredFont(forTextStyle: .body)
      attributes[.font] = toggledFont(currentFont, trait: trait)
      typingAttributes = attributes
      return
    }
    guard let storage = textStorage else { return }
    storage.beginEditing()
    storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
      let currentFont = value as? NSFont ?? self.font ?? .preferredFont(forTextStyle: .body)
      storage.addAttribute(.font, value: self.toggledFont(currentFont, trait: trait), range: subrange)
    }
    storage.endEditing()
    didChangeText()
  }

  private func toggledFont(_ font: NSFont, trait: NSFontTraitMask) -> NSFont {
    let manager = NSFontManager.shared
    let traits = manager.traits(of: font)
    return traits.contains(trait)
      ? manager.convert(font, toNotHaveTrait: trait)
      : manager.convert(font, toHaveTrait: trait)
  }

  private func toggleAttribute(key: NSAttributedString.Key, enabledValue: Any) {
    let range = selectedRange()
    if range.length == 0 {
      var attributes = typingAttributes
      if attributes[key] == nil {
        attributes[key] = enabledValue
      } else {
        attributes.removeValue(forKey: key)
      }
      typingAttributes = attributes
      return
    }
    guard let storage = textStorage else { return }
    let shouldRemove = rangeHasAttribute(key, in: range)
    storage.beginEditing()
    if shouldRemove {
      storage.removeAttribute(key, range: range)
    } else {
      storage.addAttribute(key, value: enabledValue, range: range)
    }
    storage.endEditing()
    didChangeText()
  }

  private func rangeHasAttribute(
    _ key: NSAttributedString.Key,
    in range: NSRange
  ) -> Bool {
    guard let storage = textStorage else { return false }
    var hasAttribute = false
    storage.enumerateAttribute(key, in: range) { value, _, stop in
      if value != nil {
        hasAttribute = true
        stop.pointee = true
      }
    }
    return hasAttribute
  }
}
