import SwiftUI
import SwiftData
import NookKit
import NookUI

/// I-03 Photo viewer: swipe between photos, pinch or double-tap to zoom, swipe down to
/// close. Set as Cover, Share and Delete Photo sit in the bottom bar.
struct PhotoViewer: View {
    let item: Item
    @State private var index: Int
    @State private var toast: ToastMessage?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.undoManager) private var undoManager

    init(item: Item, start: Int) {
        self.item = item
        _index = State(initialValue: start)
    }

    private var photos: [Photo] { item.orderedPhotos }

    var body: some View {
        NavigationStack {
            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { offset, photo in
                    ZoomablePhoto(fileName: photo.fileName, onDismiss: { dismiss() })
                        .tag(offset)
                        .accessibilityLabel(Text("Photo \(offset + 1) of \(photos.count): \(item.name)"))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(NookColor.canvas)
            .ignoresSafeArea(edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(min(index, photos.count - 1) + 1) of \(photos.count)")
                        .font(.nookMeta.monospacedDigit())
                        .foregroundStyle(NookColor.textPrimary)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Set as Cover", systemImage: "star") { setCover() }
                        .disabled(index == 0)
                    Spacer()
                    if let photo = current {
                        ShareLink(item: BlobStore.shared.url(for: photo.fileName, in: .photos))
                    }
                    Spacer()
                    Button("Delete Photo", systemImage: "trash", role: .destructive) { deletePhoto() }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toast($toast)
        }
        .onChange(of: photos.count) { _, count in if count == 0 { dismiss() } }
    }

    private var current: Photo? { photos.indices.contains(index) ? photos[index] : nil }

    private func setCover() {
        guard let photo = current else { return }
        ItemService(context: context).setCover(photo)
        try? context.save()
        index = 0
        toast = ToastMessage(symbol: "star.fill", "Set as cover.")
    }

    private func deletePhoto() {
        guard let photo = current else { return }
        ItemService(context: context).removePhoto(photo)
        try? context.save()
        index = max(0, min(index, photos.count - 1))
        toast = ToastMessage(symbol: "trash", "Photo deleted.") { [undoManager, context] in
            undoManager?.undo()
            try? context.save()
        }
    }
}

/// One photo that zooms with a pinch or a double tap, and closes with a swipe down at 1×.
private struct ZoomablePhoto: View {
    let fileName: String
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var drag: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        StoredImage(fileName: fileName, maxPixels: 2400) { image in
            ZStack {
                if let image {
                    image.resizable().scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .scaleEffect(scale * pinch)
        .offset(y: drag.height)
        .accessibilityIgnoresInvertColors()
        .gesture(MagnifyGesture()
            .onChanged { pinch = $0.magnification }
            .onEnded { _ in
                scale = min(max(scale * pinch, 1), 4)
                pinch = 1
            })
        .simultaneousGesture(DragGesture()
            .onChanged { if scale == 1, $0.translation.height > 0 { drag = $0.translation } }
            .onEnded { value in
                if scale == 1, value.translation.height > 120 { onDismiss() }
                drag = .zero
            })
        .onTapGesture(count: 2) { scale = scale > 1 ? 1 : 2.5 }
        .nookAnimation(.snappy, value: scale)
        .accessibilityAction(named: Text("Zoom")) { scale = scale > 1 ? 1 : 2.5 }
    }
}

/// A spot's photo, full screen (H-03 → I-03). Spot photos arrive with room scans (P6).
struct SpotPhotoViewer: View {
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZoomablePhoto(fileName: fileName, onDismiss: { dismiss() })
                .background(NookColor.canvas)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
        }
    }
}
