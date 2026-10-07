import SwiftUI
import PhotosUI
import NookAI
import NookKit
import NookUI

/// C-08 Serial sticker reader, Classic (01 C-08): photograph the sticker, then every
/// recognized line is listed, labeled serials first. Tapping a line fills Serial; each row's
/// menu can use it as the model number instead. Full screen (01 §1.5).
struct SerialScanScreen: View {
    enum Pick: Equatable {
        case serial(String), model(String), typeIt
    }

    /// The choice, or nil when cancelled.
    let finish: (Pick?) -> Void

    @State private var photo: UIImage?
    @State private var reading: SerialReading?
    @State private var picksPhoto = false
    @State private var picked: PhotosPickerItem?
    @State private var chose = 0

    var body: some View {
        Group {
            if let photo {
                lines(for: photo)
            } else if Camera.isUsable {
                SinglePhotoCamera(askTitle: "Photograph the sticker", hint: "Fill the frame with the sticker.",
                                  offersSkip: false, fixture: CaptureFixtures.sticker) { data in
                    if let data { read(data) }
                } cancel: {
                    finish(nil)
                }
            } else {
                // No camera: Photos first, then the same list.
                NookColor.canvas.ignoresSafeArea()
                    .onAppear { picksPhoto = true }
                    .photosPicker(isPresented: $picksPhoto, selection: $picked, matching: .images)
                    .onChange(of: picksPhoto) { _, shows in if !shows && picked == nil { finish(nil) } }
                    .onChange(of: picked) { _, item in
                        guard let item else { return }
                        Task { if let data = try? await item.loadTransferable(type: Data.self) { read(data) } }
                    }
            }
        }
        .nookHaptic(.selected, trigger: chose)
    }

    private func read(_ data: Data) {
        guard let input = PhotoInput(data: data) else { return }
        photo = UIImage(cgImage: input.image)
        Task {
            // D48: the one place stickers are read; P8 asks the router instead.
            reading = (try? await NookAI.classic.readSerial(from: input)) ?? SerialReading(lines: [])
        }
    }

    private func lines(for photo: UIImage) -> some View {
        NavigationStack {
            List {
                Section {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: NookLayout.heroPhotoHeight)
                        .clipShape(RoundedRectangle(cornerRadius: NookRadius.medium, style: .continuous))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("Sticker photo"))
                }
                Section {
                    if let reading {
                        ForEach(Array(reading.lines.enumerated()), id: \.offset) { _, line in
                            row(line)
                        }
                        if reading.lines.isEmpty {
                            Text("No text found on this photo.")
                                .foregroundStyle(NookColor.textSecondary)
                        }
                    } else {
                        Label("Reading the sticker…", systemImage: "text.viewfinder")
                            .foregroundStyle(NookColor.textSecondary)
                    }
                    Button { pick(.typeIt) } label: {
                        Label("Enter it myself", systemImage: "keyboard")
                    }
                } header: {
                    VStack(alignment: .leading, spacing: NookSpace.half) {
                        Text("Which line is the serial?").font(.nookSection).foregroundStyle(NookColor.textPrimary)
                        Text("Tap it to fill the Serial field.").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                    }
                    .textCase(nil)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
            .scrollContentBackground(.hidden)
            .background(NookColor.canvas)
            .navigationTitle("Serial Number")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { finish(nil) }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Retake", systemImage: "camera") { self.photo = nil; reading = nil }
                        .disabled(!Camera.isUsable)
                }
            }
        }
    }

    private func row(_ line: SerialReading.Line) -> some View {
        HStack {
            Button { pick(.serial(line.value)) } label: {
                VStack(alignment: .leading, spacing: NookSpace.half) {
                    Text(verbatim: line.text)
                        .font(.nookBody.monospaced())
                        .foregroundStyle(NookColor.textPrimary)
                    if let kind = label(line.kind) {
                        Text(kind).font(.nookCaption).foregroundStyle(NookColor.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: NookLayout.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAction(named: Text("Use as Model Number")) { pick(.model(line.value)) }
            Menu {
                Button("Use as Serial Number", systemImage: "number") { pick(.serial(line.value)) }
                Button("Use as Model Number", systemImage: "tag") { pick(.model(line.value)) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(NookColor.textSecondary)
                    .frame(minWidth: NookLayout.minTapTarget, minHeight: NookLayout.minTapTarget)
            }
            .accessibilityLabel(Text("More for \(line.text)"))
        }
    }

    /// The label printed on the sticker, said back so the right line is easy to spot.
    private func label(_ kind: SerialReading.Line.Kind) -> LocalizedStringResource? {
        switch kind {
        case .serial: "Labeled as the serial"
        case .model: "Labeled as the model"
        case .code, .other: nil
        }
    }

    private func pick(_ choice: Pick) {
        chose += 1
        finish(choice)
    }
}
