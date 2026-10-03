import AppKit

@MainActor
enum ApplicationMenu {
  static func install(on application: NSApplication = .shared) {
    let menu = NSMenu()
    let appMenu = NSMenu(title: "EasyFlow")
    appMenu.addItem(withTitle: "Open Workspace", action: #selector(EasyFlowAppDelegate.openWorkspace(_:)), keyEquivalent: "o")
    appMenu.addItem(withTitle: "Quit EasyFlow", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    menu.addItem(appItem)
    let edit = NSMenu(title: "Edit")
    for (title, action, key) in [
      ("Undo", Selector(("undo:")), "z"),
      ("Redo", Selector(("redo:")), "Z"),
      ("Cut", #selector(NSText.cut(_:)), "x"),
      ("Copy", #selector(NSText.copy(_:)), "c"),
      ("Paste", #selector(NSText.paste(_:)), "v"),
      ("Select All", #selector(NSText.selectAll(_:)), "a"),
      ("Bold", NoteImageTextView.toggleBoldSelector, "b"),
      ("Italic", NoteImageTextView.toggleItalicSelector, "i"),
      ("Underline", NoteImageTextView.toggleUnderlineSelector, "u"),
    ] {
      edit.addItem(withTitle: title, action: action, keyEquivalent: key)
    }
    let highlight = edit.addItem(
      withTitle: "Highlight",
      action: NoteImageTextView.toggleHighlightSelector,
      keyEquivalent: "h"
    )
    highlight.keyEquivalentModifierMask = [.command, .control]
    let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
    editItem.submenu = edit
    menu.addItem(editItem)
    let window = NSMenu(title: "Window")
    window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
    windowItem.submenu = window
    menu.addItem(windowItem)
    application.mainMenu = menu
  }
}
