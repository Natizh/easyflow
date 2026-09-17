import AppKit
import ImageIO
import SwiftUI

@MainActor
final class AttachmentThumbnailCache {
  static let shared = AttachmentThumbnailCache()
  private let cache = NSCache<NSURL, NSImage>()

  init() { cache.totalCostLimit = 32 * 1024 * 1024 }

  func image(at url: URL) -> NSImage? {
    if let image = cache.object(forKey: url as NSURL) { return image }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 512,
      ] as CFDictionary)
    else { return nil }
    let result = NSImage(cgImage: image, size: .zero)
    cache.setObject(result, forKey: url as NSURL, cost: image.bytesPerRow * image.height)
    return result
  }
}

struct NoteAttachmentsView: View {
  let attachments: [NoteAttachment]
  @ObservedObject var model: AppShellViewModel
  var height: CGFloat = 92
  var allowsRemoval = true

  var body: some View {
    if !attachments.isEmpty {
      ScrollView(.horizontal) {
        HStack(spacing: 8) {
          ForEach(attachments) { attachment in
            AttachmentThumbnail(attachment: attachment, directory: model.attachmentDirectory,
              height: height, open: { model.previewImage(attachment) })
              .contextMenu {
                Button("Open Image") { model.previewImage(attachment) }
                if allowsRemoval {
                  Button("Remove Image", role: .destructive) { model.removeAttachment(attachment.id) }
                }
              }
          }
        }
      }
      .scrollIndicators(.hidden)
      .frame(height: height)
    }
  }
}

private struct AttachmentThumbnail: View {
  let attachment: NoteAttachment
  let directory: URL
  let height: CGFloat
  let open: () -> Void
  @State private var image: NSImage?

  var body: some View {
    Button(action: open) {
      Group {
        if let image {
          Image(nsImage: image).resizable().scaledToFit()
        } else {
          Image(systemName: "photo").foregroundStyle(.secondary)
        }
      }
      .frame(width: min(160, max(40, height * CGFloat(attachment.pixelWidth) / CGFloat(attachment.pixelHeight))), height: height)
      .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open image preview")
    .task(id: attachment.id) {
      image = AttachmentThumbnailCache.shared.image(at: directory.appendingPathComponent(attachment.filename))
    }
  }
}
