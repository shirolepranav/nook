import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NookKit
import NookUI

extension UTType {
    /// `.nookbackup` (D12): declared by Nook, conforming only to data, so Files keeps it whole
    /// instead of offering to unzip it (D56).
    static let nookBackup = UTType(exportedAs: "pranav.nook.backup", conformingTo: .data)
}

/// S-04 Backup & Restore: one `.nookbackup` file with every item, photo and receipt (F9), and
/// restoring one by Merge or Replace (D56).
struct BackupScreen: View {
    @Environment(\.modelContext) private var context
    @AppStorage(PreferenceKey.reportHomeName) private var homeName = ""
    @AppStorage(PreferenceKey.lastBackup) private var lastBackup: Double = 0
    @State private var size: Int64?
    @State private var progress: Double?
    @State private var work: Task<Void, Never>?
    @State private var made: URL?
    @State private var saving = false
    @State private var choosing = false
    @State private var restoring: URL?
    @State private var toast: ToastMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NookSpace.s3) {
                backupCard
                VStack(alignment: .leading, spacing: NookSpace.s1) {
                    Button { choosing = true } label: {
                        HStack(spacing: NookSpace.s2) {
                            Image(systemName: "clock.arrow.circlepath").foregroundStyle(.tint).accessibilityHidden(true)
                            Text("Restore from a Backup").font(.nookBody).foregroundStyle(NookColor.textPrimary)
                            Spacer(minLength: NookSpace.s1)
                            Image(systemName: "chevron.right").font(.nookFootnote).foregroundStyle(NookColor.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, NookSpace.s2)
                        .frame(minHeight: NookLayout.rowHeight)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .nookCard(radius: NookRadius.medium, elevation: .flat)
                    .hoverEffect(.highlight)
                    Text("Choose a .nookbackup file. You’ll pick Merge or Replace before anything changes.")
                        .font(.nookFootnote)
                        .foregroundStyle(NookColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, NookSpace.s2)
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .navigationTitle("Backup & Restore")
        .toolbarTitleDisplayMode(.large)
        .fileImporter(isPresented: $choosing, allowedContentTypes: [.nookBackup]) { result in
            if case .success(let url) = result { restoring = url }
        }
        .restoreBackup($restoring, toast: $toast)
        .toast($toast)
        .task { size = try? BackupService(context: context).estimatedSize() }
        .onDisappear { work?.cancel() }
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Text("A backup is one **.nookbackup** file with every item, photo and receipt. Keep it in Files, iCloud Drive or on a computer.")
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let progress {
                VStack(alignment: .leading, spacing: NookSpace.s1) {
                    ProgressView(value: progress).tint(.accentColor)
                    Text("Making your backup…").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
                    Button("Cancel") { work?.cancel() }.buttonStyle(.nookSecondary)
                }
                .accessibilityElement(children: .contain)
            } else if let made {
                ShareLink(item: made) {
                    Label("Share Backup", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookPrimary)
                Button { saving = true } label: {
                    Label("Save to Files", systemImage: "folder").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookSecondary)
                .fileMover(isPresented: $saving, file: made) { result in
                    if case .success = result {
                        self.made = nil
                        toast = ToastMessage(symbol: "folder", "Saved to Files.")
                    }
                }
            } else {
                // Free too (D65): a backup is the user's own data leaving with them.
                Button(action: create) {
                    Label("Create Backup", systemImage: "externaldrive.badge.plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookPrimary)
            }
            if let detail { detail.font(.nookFootnote).foregroundStyle(NookColor.textSecondary) }
        }
        .padding(NookSpace.s3)
        .nookCard()
    }

    /// "About 1.2 GB · Last backup Oct 1, 2026".
    private var detail: Text? {
        let about = size.map { Text("About \($0.formatted(.byteCount(style: .file)))") }
        let last = lastBackup > 0
            ? Text("Last backup \(Date(timeIntervalSince1970: lastBackup).formatted(date: .abbreviated, time: .omitted))") : nil
        switch (about, last) {
        case let (about?, last?): return Text("\(about) · \(last)")
        case let (about?, nil): return about
        case let (nil, last?): return last
        default: return nil
        }
    }

    private func create() {
        let date = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appending(path: "Nook \(date).\(BackupService.fileExtension)")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        progress = 0
        work = Task {
            do {
                try await BackupService(context: context).export(to: url, appVersion: version, homeName: homeName) { value in
                    Task { @MainActor in progress = value }
                }
                lastBackup = Date.now.timeIntervalSince1970
                made = url
            } catch is CancellationError {
            } catch BackupService.Failure.notEnoughSpace {
                toast = ToastMessage(symbol: "exclamationmark.triangle", "There isn’t enough space for the backup. Free some up and try again.")
            } catch {
                toast = ToastMessage(symbol: "exclamationmark.triangle", "The backup couldn’t be made. Your items are safe. Try again in a moment.")
            }
            progress = nil
        }
    }
}

extension View {
    /// S-04's restore question for `url`, from the file importer or a `.nookbackup` opened in
    /// Files: Merge or Replace, then a toast (D56).
    func restoreBackup(_ url: Binding<URL?>, toast: Binding<ToastMessage?>) -> some View {
        modifier(RestoreFlow(url: url, toast: toast))
    }
}

private struct RestoreFlow: ViewModifier {
    @Binding var url: URL?
    @Binding var toast: ToastMessage?
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @State private var manifest: BackupManifest?
    @State private var asking = false
    @State private var working = false

    func body(content: Content) -> some View {
        content
            .onChange(of: url) { _, url in if url != nil { open() } }
            .onAppear { if url != nil { open() } }
            .confirmationDialog(title, isPresented: $asking, titleVisibility: .visible) {
                Button("Merge") { restore(.merge) }
                Button("Replace", role: .destructive) { restore(.replace) }
                Button("Cancel", role: .cancel) { url = nil }
            } message: {
                Text(items.isEmpty ? "Nothing on this iPhone changes until you choose."
                                   : "This iPhone already has \(items.count) items. Merge keeps what’s here and adds what’s missing. Replace moves what’s here to Recently Deleted first.")
            }
            .overlay {
                if working {
                    ProgressView("Restoring…")
                        .font(.nookMeta)
                        .padding(NookSpace.s3)
                        .background(NookColor.surfaceRaised, in: .rect(cornerRadius: NookRadius.card))
                        .warmShadow(.floating)
                }
            }
    }

    /// "Restore “Maple Street, Oct 1”?"
    private var title: Text {
        guard let manifest else { return Text("Restore this backup?") }
        let date = manifest.createdAt.formatted(.dateTime.month(.abbreviated).day())
        let name = manifest.homeName.isEmpty ? date : "\(manifest.homeName), \(date)"
        return Text("Restore “\(name)”?")
    }

    private func open() {
        guard let url else { return }
        do {
            manifest = try BackupService.manifest(of: url)
            asking = true
        } catch {
            self.url = nil
            fail(error)
        }
    }

    private func restore(_ mode: BackupService.Mode) {
        guard let url else { return }
        working = true
        Task {
            do {
                let count = try await BackupService(context: context).restore(from: url, mode: mode)
                toast = ToastMessage("Restored \(count) items.", haptic: .saved)
            } catch {
                fail(error)
            }
            working = false
            self.url = nil
        }
    }

    private func fail(_ error: Error) {
        let message: LocalizedStringResource = switch error as? BackupService.Failure {
        case .newerVersion: "This backup is from a newer Nook. Update Nook, then try again."
        case .notEnoughSpace: "There isn’t enough space to restore it. Free some up and try again."
        case .notABackup: "This file isn’t a Nook backup."
        default: "The backup couldn’t be restored. Nothing on this iPhone changed."
        }
        toast = ToastMessage(symbol: "exclamationmark.triangle", message)
    }
}
