import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Accessed by WorkspaceRepository's serial actor. Files are immutable and UUID-named.
struct AttachmentFileStore: Sendable {
  let directory: URL

  func url(for filename: String) throws -> URL {
    guard filename == (filename as NSString).lastPathComponent,
      !filename.isEmpty, !filename.hasPrefix(".")
    else { throw AttachmentError.invalidPath }
    return directory.appendingPathComponent(filename)
  }

  func write(_ data: Data, order: Int, now: Date) throws -> NoteAttachment {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let type = CGImageSourceGetType(source) as String?
    else { throw AttachmentError.invalidImage }
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    let orientation = properties?[kCGImagePropertyOrientation] as? Int ?? 1
    var output = data
    var outputType = type
    var suffix = type == UTType.jpeg.identifier ? "jpg" : "png"
    if type != UTType.png.identifier && type != UTType.jpeg.identifier {
      let buffer = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(
        buffer, UTType.png.identifier as CFString, 1, nil
      ) else { throw AttachmentError.invalidImage }
      CGImageDestinationAddImage(destination, image,
        [kCGImagePropertyOrientation: orientation] as CFDictionary)
      guard CGImageDestinationFinalize(destination) else { throw AttachmentError.invalidImage }
      output = buffer as Data
      outputType = UTType.png.identifier
      suffix = "png"
    }
    let id = UUID()
    let filename = "\(id.uuidString).\(suffix)"
    let fm = FileManager.default
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    let staging = directory.appendingPathComponent(".\(id.uuidString).staging")
    defer { try? fm.removeItem(at: staging) }
    try output.write(to: staging, options: .atomic)
    try fm.moveItem(at: staging, to: url(for: filename))
    let rotated = (5...8).contains(orientation)
    return NoteAttachment(
      id: id, noteID: nil, draftID: nil, filename: filename, contentType: outputType,
      pixelWidth: rotated ? image.height : image.width,
      pixelHeight: rotated ? image.width : image.height,
      byteCount: output.count, sortIndex: order, createdAt: now
    )
  }

  func remove(_ filename: String) throws {
    let file = try url(for: filename)
    if FileManager.default.fileExists(atPath: file.path) {
      try FileManager.default.removeItem(at: file)
    }
  }

  func removeUnreferenced(keeping filenames: Set<String>) throws {
    guard FileManager.default.fileExists(atPath: directory.path) else { return }
    for file in try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey]
    ) {
      guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
        continue
      }
      if !filenames.contains(file.lastPathComponent) {
        try FileManager.default.removeItem(at: file)
      }
    }
  }
}
