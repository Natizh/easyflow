import AppKit
import Testing

@testable import EasyFlow

@Suite("Quick Note AppKit editor")
@MainActor
struct QuickNoteEditorTests {
  @Test("Capture text geometry uses one native inset and no line padding")
  func editorGeometry() {
    let textView = QuickNoteCaptureTextView()
    textView.configureForEasyFlowCapture()

    #expect(textView.font == NSFont.preferredFont(forTextStyle: .body))
    #expect(textView.textContainerInset == NSSize(width: 10, height: 9))
    #expect(textView.textContainer?.lineFragmentPadding == 0)
    #expect(textView.textContainer?.widthTracksTextView == true)
    #expect(!textView.drawsBackground)
    #expect(!textView.isRichText)
    #expect(textView.isVerticallyResizable)
    #expect(!textView.isHorizontallyResizable)
  }

  @Test("Return submits instead of inserting a newline")
  func returnSubmits() {
    #expect(
      QuickNoteCaptureEditor.Coordinator.shouldCommit(
        commandSelector: #selector(NSResponder.insertNewline(_:))
      )
    )
    #expect(
      !QuickNoteCaptureEditor.Coordinator.shouldCommit(
        commandSelector: #selector(NSResponder.insertTab(_:))
      )
    )
  }
}
