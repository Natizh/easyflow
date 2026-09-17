import Foundation
@preconcurrency import GRDB

struct NoteAttachment: Codable, Equatable, Identifiable, Sendable,
  FetchableRecord, MutablePersistableRecord
{
  static let databaseTableName = "noteAttachment"
  var id: UUID
  var noteID: UUID?
  var draftID: String?
  var filename: String
  var contentType: String
  var pixelWidth: Int
  var pixelHeight: Int
  var byteCount: Int
  var sortIndex: Int
  var createdAt: Date
}

enum AttachmentOwner: Sendable {
  case note(UUID)
  case draft(revision: UUID, body: String)
}

enum AttachmentError: LocalizedError {
  case invalidImage, unavailable, invalidPath

  var errorDescription: String? {
    switch self {
    case .invalidImage: "This clipboard image could not be read."
    case .unavailable: "The image is unavailable. Your note text is still saved."
    case .invalidPath: "The image could not be stored safely."
    }
  }
}
