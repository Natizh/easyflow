import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@preconcurrency import GRDB
import Testing
@testable import EasyFlow

func fixtureImage(type: CFString = UTType.png.identifier as CFString) throws -> Data {
  let context = try #require(CGContext(data: nil, width: 48, height: 24, bitsPerComponent: 8,
    bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
  context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 48, height: 24))
  let image = try #require(context.makeImage())
  let data = NSMutableData()
  let destination = try #require(CGImageDestinationCreateWithData(data, type, 1, nil))
  CGImageDestinationAddImage(destination, image, nil)
  #expect(CGImageDestinationFinalize(destination))
  return data as Data
}

@Suite("Local image attachments")
struct AttachmentTests {
  @Test("Image-only and mixed notes survive commit, move, and reopen", arguments: ["", "Text and images"])
  func lifecycle(body: String) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("workspace.sqlite").path
    let db = try AppDatabase(path: path)
    let repository = WorkspaceRepository(database: db)
    let data = try fixtureImage()
    let revision = UUID()
    try await repository.addImages([data, data], to: .draft(revision: revision, body: body))
    #expect(try await repository.snapshot().draftAttachments.count == 2)
    let note = try #require(try await repository.commitDraft(body: body, revision: revision))
    let initial = try await repository.snapshot().attachmentsByNote[note.id] ?? []
    #expect(initial.map(\.sortIndex) == [0, 1])
    #expect(initial.allSatisfy { $0.noteID == note.id && $0.draftID == nil })
    let task = try await repository.createMainTask(title: "Target", effort: .two)
    try await repository.moveQuickNote(id: note.id, to: task.id)
    let reopened = WorkspaceRepository(database: try AppDatabase(path: path))
    let snapshot = try await reopened.snapshot()
    #expect(snapshot.quickNotes.isEmpty)
    #expect(snapshot.attachedNotesByTask[task.id]?.first?.id == note.id)
    #expect(snapshot.attachedNotesByTask[task.id]?.first?.body == body)
    #expect(snapshot.attachmentsByNote[note.id] == initial)
    for attachment in initial {
      #expect(try Data(contentsOf: reopened.attachmentDirectory.appendingPathComponent(attachment.filename)) == data)
    }
    try await reopened.addImages([data], to: .note(note.id))
    #expect(try await reopened.snapshot().attachmentsByNote[note.id]?.count == 3)
    try await reopened.softDeleteNote(id: note.id)
    try await reopened.maintainAttachmentFiles()
    #expect(try await db.queue.read { try NoteAttachment.fetchCount($0) } == 3)
    #expect(FileManager.default.fileExists(atPath: reopened.attachmentDirectory.appendingPathComponent(initial[0].filename).path))
  }

  @Test("Removal and parent purge queue and remove owned files, retaining soft-deleted context")
  func deletion() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let task = try await repository.createMainTask(title: "Parent", effort: .one)
    let note = try #require(try await repository.commitDraft(body: "Owned", revision: UUID()))
    try await repository.moveQuickNote(id: note.id, to: task.id)
    try await repository.addImages([fixtureImage(), fixtureImage()], to: .note(note.id))
    let images = try await repository.snapshot().attachmentsByNote[note.id] ?? []
    try await repository.removeAttachment(id: images[0].id)
    #expect(!FileManager.default.fileExists(atPath: db.attachmentDirectory.appendingPathComponent(images[0].filename).path))
    try await repository.softDeleteMainTask(id: task.id)
    #expect(try await db.queue.read { try NoteAttachment.fetchCount($0) } == 1)
    try await db.queue.write { db in _ = try MainTask.deleteOne(db, key: task.id) }
    #expect(try await db.queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM attachmentFileDeletion") } == 1)
    try await repository.maintainAttachmentFiles()
    #expect(!FileManager.default.fileExists(atPath: db.attachmentDirectory.appendingPathComponent(images[1].filename).path))
    #expect(try await db.queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM attachmentFileDeletion") } == 0)
  }

  @Test("Failed image batch leaves note unchanged and no committed files")
  func invalidImport() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let note = try #require(try await repository.commitDraft(body: "Keep", revision: UUID()))
    await #expect(throws: (any Error).self) {
      try await repository.addImages([fixtureImage(), Data("invalid".utf8)], to: .note(note.id))
    }
    #expect(try await repository.snapshot().quickNotes.first?.body == "Keep")
    #expect(try await db.queue.read { try NoteAttachment.fetchCount($0) } == 0)
    #expect(try FileManager.default.contentsOfDirectory(atPath: db.attachmentDirectory.path).isEmpty)
    await #expect(throws: (any Error).self) {
      try await repository.addImages([fixtureImage()], to: .note(UUID()))
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: db.attachmentDirectory.path).isEmpty)
  }

  @Test("TIFF normalizes losslessly and orphan staging is reclaimed")
  func normalizationAndRecovery() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let revision = UUID()
    try await repository.addImages([fixtureImage(type: UTType.tiff.identifier as CFString)], to: .draft(revision: revision, body: ""))
    let image = try #require(try await repository.snapshot().draftAttachments.first)
    #expect(image.contentType == UTType.png.identifier)
    #expect(image.pixelWidth == 48 && image.pixelHeight == 24)
    let orphan = db.attachmentDirectory.appendingPathComponent(".abandoned.staging")
    try Data([1]).write(to: orphan)
    try await repository.maintainAttachmentFiles()
    #expect(!FileManager.default.fileExists(atPath: orphan.path))
    #expect(FileManager.default.fileExists(atPath: db.attachmentDirectory.appendingPathComponent(image.filename).path))
    try await repository.clearDraft(revision: UUID())
    #expect(try await repository.snapshot().draftAttachments.count == 1)
    try await repository.clearDraft(revision: revision)
    #expect(try await repository.snapshot().draftAttachments.isEmpty)
  }

  @Test("Late duplicate commit cannot clear a newer draft or its images")
  func lateCommit() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let old = UUID(), new = UUID()
    let note = try await repository.commitDraft(body: "Old", revision: old)
    try await repository.addImages([fixtureImage()], to: .draft(revision: new, body: "New"))
    #expect(try await repository.commitDraft(body: "Old", revision: old)?.id == note?.id)
    try await repository.saveDraft(body: "Late", revision: old)
    #expect(try await repository.snapshot().draft?.revision == new)
    #expect(try await repository.snapshot().draftAttachments.count == 1)
  }

  @Test("Missing files do not corrupt note metadata and cleanup retries failed deletions")
  func missingFilesAndRetry() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let note = try #require(try await repository.commitDraft(body: "Keep text", revision: UUID()))
    try await repository.addImages([fixtureImage()], to: .note(note.id))
    let image = try #require(try await repository.snapshot().attachmentsByNote[note.id]?.first)
    try FileManager.default.removeItem(at: db.attachmentDirectory.appendingPathComponent(image.filename))
    try await repository.maintainAttachmentFiles()
    #expect(try await repository.snapshot().quickNotes.first?.body == "Keep text")
    #expect(try await repository.snapshot().attachmentsByNote[note.id]?.count == 1)
    try await repository.removeAttachment(id: image.id)
    #expect(try await db.queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM attachmentFileDeletion") } == 0)
    // Invalid queued paths are retained for retry and cannot escape storage.
    try await db.queue.write { try $0.execute(sql: "INSERT INTO attachmentFileDeletion VALUES ('../outside')") }
    try await repository.maintainAttachmentFiles()
    #expect(try await db.queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM attachmentFileDeletion") } == 1)
  }

  @Test("Populated pre-attachment database upgrades without changing any existing records")
  func migration() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("migration.sqlite").path
    let queue = try DatabaseQueue(path: path)
    try AppDatabase.migrator.migrate(queue, upTo: "v3-deleted-task-retention")
    let tables = ["mainTask", "taskStep", "workspaceNote", "quickNoteDraft", "appSetting", "reminderSync"]
    try queue.write { db in
      try db.execute(sql: """
        INSERT INTO mainTask (id, reminderIdentifier, title, effort, sortIndex, taskDescription, createdAt, updatedAt, completedAt)
        VALUES ('task', 'reminder', 'Existing', 3, 0, 'Description', 1, 2, 3);
        INSERT INTO taskStep (id, mainTaskID, title, sortIndex, isCompleted, notes, createdAt, updatedAt)
        VALUES ('step', 'task', 'Step', 0, 1, 'Notes', 1, 2);
        INSERT INTO workspaceNote (id, body, mainTaskID, sortIndex, createdAt, updatedAt)
        VALUES ('attached', 'Body', 'task', 0, 1, 2), ('inbox', 'Quick', NULL, 0, 1, 2);
        INSERT INTO quickNoteDraft (id, revision, body, updatedAt) VALUES ('quick-note', 'revision', 'Draft', 2);
        INSERT INTO appSetting (key, value, updatedAt) VALUES ('remindersListIdentifier', 'list', 2);
        INSERT INTO reminderSync (taskID, calendarItemIdentifier, origin, localCoreUpdatedAt)
        VALUES ('task', 'reminder', 'local', 2);
        """)
    }
    let before = try queue.read { db in try tables.map { try Row.fetchAll(db, sql: "SELECT * FROM \($0)") } }
    let upgraded = try AppDatabase(path: path)
    let after = try upgraded.queue.read { db in try tables.map { try Row.fetchAll(db, sql: "SELECT * FROM \($0)") } }
    #expect(before == after)
    #expect(try upgraded.queue.read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations") }.last == "v4-note-image-attachments")
    #expect(try upgraded.queue.read { try Row.fetchAll($0, sql: "PRAGMA foreign_key_check") }.isEmpty)
  }
}
