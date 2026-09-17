import AppKit

/// Native text remains plain text. Images are separate note-owned attachments.
class NoteImageTextView: NSTextView {
  var onPasteImages: (([Data]) -> Void)?

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
}
