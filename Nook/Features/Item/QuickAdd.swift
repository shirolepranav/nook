import SwiftUI
import NookKit
import NookUI

extension View {
    /// C-05 Quick add (D37): Nook's camera first, then the editor with the photo in place, so
    /// shutter and Save are the 2 taps (F2). The camera also offers Choose from Photos and
    /// Skip photo. With the camera off or missing, the editor opens straight away and offers
    /// Photos.
    /// `name` pre-fills the editor (Find's "Add “x” as an Item", F-02).
    func quickAdd(isPresented: Binding<Bool>, at location: Location? = nil, name: String = "") -> some View {
        modifier(QuickAdd(isPresented: isPresented, location: location, name: name))
    }
}

private struct QuickAdd: ViewModifier {
    @Binding var isPresented: Bool
    let location: Location?
    let name: String

    @State private var showsCamera = false
    @State private var editor: EditorStart?
    @State private var photo: ItemDraft.DraftPhoto?
    @State private var chose = false
    @State private var toast: ToastMessage?

    private struct EditorStart: Identifiable {
        let id = UUID()
        let draft: ItemDraft
        let cameraOff: Bool
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, start in
                guard start else { return }
                isPresented = false
                photo = nil
                chose = false
                if Camera.isUsable { showsCamera = true } else { openEditor(cameraOff: true) }
            }
            .fullScreenCover(isPresented: $showsCamera, onDismiss: { if chose { openEditor(cameraOff: false) } }) {
                SinglePhotoCamera { data in
                    if let data, let saved = try? BlobStore.shared.savePhoto(data) {
                        photo = .init(fileName: saved.fileName, width: saved.width, height: saved.height)
                    }
                    chose = true   // a photo, or Skip photo
                    showsCamera = false
                } cancel: {
                    showsCamera = false
                }
            }
            .sheet(item: $editor) { start in
                ItemEditor(draft: start.draft, cameraOff: start.cameraOff) { item in
                    toast = item.room.map { ToastMessage("Saved to \($0.name).") } ?? ToastMessage("Saved.")
                }
            }
            .toast($toast)
    }

    private func openEditor(cameraOff: Bool) {
        var draft = ItemDraft(currencyCode: HomeCurrency.code, location: location)
        draft.photos = photo.map { [$0] } ?? []
        draft.name = name
        editor = EditorStart(draft: draft, cameraOff: cameraOff)
    }
}
