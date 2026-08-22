import SwiftUI
import UniformTypeIdentifiers

extension View {
  func workspaceDrag(_ payload: String) -> some View {
    onDrag { NSItemProvider(object: payload as NSString) }
  }

  func workspaceDrop(
    isTargeted: Binding<Bool>,
    perform: @escaping @MainActor (String) -> Bool
  ) -> some View {
    onDrop(of: [UTType.plainText], isTargeted: isTargeted) { providers in
      guard let provider = providers.first else { return false }
      provider.loadObject(ofClass: NSString.self) { object, _ in
        guard let payload = object as? String else { return }
        Task { @MainActor in _ = perform(payload) }
      }
      return true
    }
  }
}
