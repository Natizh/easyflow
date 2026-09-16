import AppKit
import Testing
@testable import EasyFlow

@Suite("Native editing and image paste", .serialized)
@MainActor
struct NativeEditingTests {
  @Test("Native text selection copy, cut, paste, and select-all use responder actions")
  func responderActions() throws {
    let app = NSApplication.shared
    let previousMenu = app.mainMenu
    ApplicationMenu.install(on: app)
    defer { app.mainMenu = previousMenu }
    let board = NSPasteboard.general
    let saved = (board.pasteboardItems ?? []).map { item in
      item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
    }
    defer {
      board.clearContents()
      board.writeObjects(saved.map { entries in
        let item = NSPasteboardItem()
        entries.forEach { item.setData($0.1, forType: $0.0) }
        return item
      })
    }
    let editor = NoteImageTextView()
    editor.isRichText = false
    editor.string = "alpha beta"
    editor.setSelectedRange(NSRange(location: 6, length: 4))
    let edit = try #require(app.mainMenu?.items.first(where: { $0.title == "Edit" })?.submenu)
    func send(_ title: String) throws {
      let action = try #require(edit.items.first(where: { $0.title == title })?.action)
      #expect(app.sendAction(action, to: editor, from: nil))
    }
    try send("Copy")
    #expect(board.string(forType: .string) == "beta")
    try send("Cut")
    #expect(editor.string == "alpha ")
    try send("Paste")
    #expect(editor.string == "alpha beta")
    try send("Select All")
    #expect(editor.selectedRange() == NSRange(location: 0, length: 10))
  }

  @Test("Image paste chooses one representation per item and keeps text plain")
  func imagePaste() throws {
    let board = NSPasteboard(name: .init(UUID().uuidString))
    defer { board.releaseGlobally() }
    let png = try fixtureImage()
    let first = NSPasteboardItem()
    first.setData(png, forType: .png)
    first.setData(png, forType: .tiff)
    let second = NSPasteboardItem()
    second.setData(png, forType: .png)
    board.writeObjects([first, second])
    let editor = NoteImageTextView()
    editor.isRichText = false
    editor.string = "Keep this text"
    var received: [Data] = []
    editor.onPasteImages = { received = $0 }
    #expect(editor.readSelection(from: board))
    #expect(received == [png, png])
    #expect(editor.string == "Keep this text")
    board.clearContents()
    board.setString("replacement", forType: .string)
    editor.setSelectedRange(NSRange(location: 0, length: editor.string.utf16.count))
    #expect(editor.readSelection(from: board))
    #expect(editor.string == "replacement")
  }

  @Test("Measured native text wraps long paragraphs and unbroken titles")
  func wrapping() throws {
    let editor = MeasuredNoteTextView(frame: CGRect(x: 0, y: 0, width: 180, height: 30))
    editor.isRichText = false
    editor.isHorizontallyResizable = false
    editor.isVerticallyResizable = true
    editor.font = .preferredFont(forTextStyle: .body)
    let container = try #require(editor.textContainer)
    container.widthTracksTextView = false
    container.containerSize = CGSize(width: 180, height: CGFloat.greatestFiniteMagnitude)
    func measured(_ text: String) throws -> CGFloat {
      editor.string = text
      let manager = try #require(editor.layoutManager)
      manager.ensureLayout(for: container)
      #expect(manager.numberOfGlyphs == text.utf16.count)
      return manager.usedRect(for: container).height
    }
    let short = try measured("Short")
    let long = try measured(String(repeating: "A long Step note that must wrap. ", count: 30))
    #expect(long > 156)
    #expect(try measured(String(repeating: "x", count: 400)) > short * 4)
    #expect(try measured("Short") == short)
  }

  @Test("Return during image import commits once; focus-loss does not request focus")
  func captureRace() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let repository = WorkspaceRepository(database: db)
    let model = AppShellViewModel(repository: repository)
    model.pasteCaptureImages([try fixtureImage(), try fixtureImage()])
    model.commitQuickNoteIfNeeded()
    model.commitQuickNoteOnFocusLoss()
    #expect(await model.flushPendingWrites())
    let snapshot = try await repository.snapshot()
    #expect(snapshot.quickNotes.count == 1)
    #expect(snapshot.attachmentsByNote[snapshot.quickNotes[0].id]?.count == 2)
    #expect(model.focusRequestID == 1)
    model.setQuickNoteDraft("Focus loss")
    model.commitQuickNoteOnFocusLoss()
    #expect(await model.flushPendingWrites())
    #expect(model.focusRequestID == 1)
    #expect(try await repository.snapshot().quickNotes.count == 2)
  }

  @Test("Failed capture import retains text and bytes and prevents unsafe quit")
  func failedCapture() async throws {
    let db = try AppDatabase(inMemoryNamed: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: db.attachmentDirectory.deletingLastPathComponent()) }
    let model = AppShellViewModel(repository: WorkspaceRepository(database: db))
    model.setQuickNoteDraft("Retain this")
    model.pasteCaptureImages([Data([0, 1, 2])])
    model.commitQuickNoteIfNeeded()
    #expect(!(await model.flushPendingWrites()))
    #expect(model.quickNoteDraft == "Retain this")
    #expect(model.pendingCaptureImageCount == 1)
    #expect(model.errorMessage != nil)
  }
}
