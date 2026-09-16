import AppKit
import UniformTypeIdentifiers

@MainActor
enum ClipboardImageReader {
  static let types: [NSPasteboard.PasteboardType] = [
    .png, .tiff, .init(UTType.jpeg.identifier), .init(UTType.heic.identifier)
  ]

  static func images(from pasteboard: NSPasteboard) -> [Data] {
    (pasteboard.pasteboardItems ?? []).compactMap { item in
      for type in types {
        if let data = item.data(forType: type) { return data }
      }
      return nil
    }
  }

  static func hasImages(_ pasteboard: NSPasteboard) -> Bool {
    pasteboard.availableType(from: types) != nil
  }
}
