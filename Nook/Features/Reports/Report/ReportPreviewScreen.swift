import SwiftUI
import NookKit
import NookUI
import QuickLook

/// R-02's preview and generating states. Pro makes the PDF (progress, Cancel) and opens it in
/// Quick Look, which pages through it and offers Share and Print (D42, D56). Free sees the
/// first page marked PREVIEW (PRD §7).
struct ReportPreviewScreen: View {
    let renderer: ReportRenderer
    @Environment(EntitlementStore.self) private var entitlements
    @AppStorage(MoneyText.hideValuesKey) private var hideValues = false
    @State private var thumbnails: [String: CGImage] = [:]
    @State private var drawn: (done: Int, total: Int)?
    @State private var work: Task<Void, Never>?
    @State private var pdf: URL?
    @State private var failed = false
    @State private var made = 0

    private static let scale: CGFloat = 0.5

    private var isProofPack: Bool {
        if case .item = renderer.options.scope { true } else { false }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: NookSpace.s2) {
                if failed {
                    ErrorStateView(title: Text("The report couldn’t be made"),
                                   message: Text("Your items are safe on this iPhone. Try again in a moment.")) { make() }
                } else if let drawn {
                    generating(drawn)
                } else {
                    page
                    summary
                }
            }
            .padding(NookSpace.s2)
            .frame(maxWidth: NookLayout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(NookColor.canvas)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .navigationTitle(isProofPack ? "Proof pack" : "Insurance report")
        .toolbarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(drawn != nil)   // Cancel is the way out while it renders
        .quickLookPreview($pdf)
        .nookHaptic(.saved, trigger: made)
        .task { thumbnails = await renderer.loadThumbnails(limit: ReportPaper.firstPageRows) }
        .onDisappear { work?.cancel() }
    }

    /// The first page, half size, as on the board.
    private var page: some View {
        let size = renderer.size
        return renderer.previewPage(thumbnails: thumbnails, watermarked: !entitlements.canExport)
            .scaleEffect(Self.scale, anchor: .topLeading)
            .frame(width: size.width * Self.scale, height: size.height * Self.scale, alignment: .topLeading)
            .clipShape(.rect(cornerRadius: NookRadius.small))
            .warmShadow(.lifted)
            .blur(radius: hideValues ? NookSpace.s1 : 0)   // Hide values covers the page too (F11)
            // One element: the page's own text is paper at a fixed size, not app UI.
            .accessibilityRepresentation {
                Color.clear.accessibilityLabel(Text("Report page 1 of \(renderer.pageCount)")).accessibilityAddTraits(.isImage)
            }
    }

    /// "18 pages · 126 items · $24,380".
    private var summary: some View {
        HStack(spacing: NookSpace.half) {
            Text("\(renderer.pageCount) pages · \(renderer.report.itemCount) items")
            ForEach(renderer.report.totals, id: \.currencyCode) { total in
                Text(verbatim: "·")
                MoneyText(total.amount, currencyCode: total.currencyCode, font: .nookMeta)
            }
        }
        .font(.nookMeta)
        .foregroundStyle(NookColor.textSecondary)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func generating(_ drawn: (done: Int, total: Int)) -> some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            Text("Making your report").font(.nookSection).foregroundStyle(NookColor.textPrimary)
            ProgressView(value: Double(drawn.done), total: Double(max(drawn.total, 1)))
                .tint(.accentColor)
                .accessibilityHidden(true)
            Text("Rendering \(drawn.done) of \(drawn.total) items")
                .font(.nookMeta.monospacedDigit())
                .foregroundStyle(NookColor.textPrimary)
            Text("Everything is made on this iPhone. It takes about 20 seconds.")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NookSpace.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var bottomBar: some View {
        Group {
            if drawn != nil {
                Button { work?.cancel() } label: { Text("Cancel").frame(maxWidth: .infinity) }
                    .buttonStyle(.nookSecondary)
            } else if entitlements.canExport {
                Button(action: make) {
                    Label("Create Report", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookPrimary)
            } else {
                // P11: opens the paywall (P-01). Until then only UI tests reach the Free state (D56).
                Button {} label: {
                    Label("Unlock Pro to Export", systemImage: "lock.open").frame(maxWidth: .infinity)
                }
                .buttonStyle(.nookPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(NookSpace.s2)
        .frame(maxWidth: NookLayout.readableWidth)
        .frame(maxWidth: .infinity)
        .background(NookColor.canvas)
    }

    private func make() {
        failed = false
        drawn = (0, renderer.report.itemCount)
        let name = renderer.cover.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appending(path: "\(name).pdf")
        work = Task {
            do {
                try await renderer.render(to: url) { done, total in drawn = (done, total) }
                drawn = nil
                made += 1
                pdf = url
            } catch is CancellationError {
                drawn = nil
            } catch {
                drawn = nil
                failed = true
            }
        }
    }
}

extension ReportPaper {
    /// Rows that can sit on the first page, so the preview loads only their thumbnails.
    static let firstPageRows = 12
}
