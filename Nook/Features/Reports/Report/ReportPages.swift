import SwiftUI
import NookKit
import NookUI

/// What the report's cover says (D28): the home, the policy and the day it was made.
struct ReportCover {
    var title: String
    var insurer: String
    var policyNumber: String
    var date: Date
}

/// US Letter where the region measures in inches, A4 elsewhere (PDF points).
enum ReportPaper {
    static var size: CGSize {
        Locale.current.measurementSystem == .us ? CGSize(width: 612, height: 792) : CGSize(width: 595, height: 842)
    }

    static let margin: CGFloat = NookSpace.s5
    static let footerHeight: CGFloat = NookSpace.s3

    static func contentHeight(_ size: CGSize) -> CGFloat { size.height - 2 * margin - footerHeight }
}

/// One piece of a page. Every block has a fixed height, so pages are laid out without
/// rendering anything: the builder can say "18 pages" before Preview (R-02).
enum ReportBlock {
    case cover
    case room(ReportSnapshot.Section, summary: String?, continued: Bool)
    case line(ReportSnapshot.Line)

    // Heights at the report's fixed text size (`.large`): title 28, headline 22, meta 20 and
    // footnote 18 pt lines.
    func height(width: CGFloat, totals: Int) -> CGFloat {
        switch self {
        case .cover: return 28 + NookSpace.half + 20 + NookSpace.s1 + 20 * CGFloat(max(totals, 1)) + NookSpace.s3
        case .room(_, let summary, let continued):
            let header = NookSpace.s2 + 22 + NookSpace.s1
            guard let summary, !summary.isEmpty, !continued else { return header }
            // ~6.5 pt a footnote character; one line spare so wrapping never clips.
            let lines = (CGFloat(summary.count) * 6.5 / width).rounded(.up) + 1
            return header + lines * 18 + NookSpace.s1
        case .line: return Self.rowHeight
        }
    }

    static let rowHeight: CGFloat = NookLayout.rowThumbnailSize + NookSpace.s1
}

/// Splits the report into pages: the cover on the first, each room's header before its
/// items, and a "continued" header when a room runs onto a new page.
enum ReportLayout {
    static func pages(_ report: ReportSnapshot, summaries: [UUID: String], size: CGSize = ReportPaper.size) -> [[ReportBlock]] {
        let width = size.width - 2 * ReportPaper.margin
        let available = ReportPaper.contentHeight(size)
        let totals = report.totals.count
        var pages: [[ReportBlock]] = [[.cover]]
        var used = ReportBlock.cover.height(width: width, totals: totals)

        func place(_ block: ReportBlock) {
            let height = block.height(width: width, totals: totals)
            if used + height > available, !(pages.last?.isEmpty ?? true) {
                pages.append([])
                used = 0
            }
            pages[pages.count - 1].append(block)
            used += height
        }

        for section in report.sections {
            let summary = section.id.flatMap { summaries[$0] }
            // Keep a header with at least its first item.
            let header = ReportBlock.room(section, summary: summary, continued: false)
            if used + header.height(width: width, totals: totals) + ReportBlock.rowHeight > available {
                pages.append([])
                used = 0
            }
            place(header)
            for line in section.lines {
                if used + ReportBlock.rowHeight > available {
                    pages.append([.room(section, summary: nil, continued: true)])
                    used = ReportBlock.room(section, summary: nil, continued: true).height(width: width, totals: totals)
                }
                place(.line(line))
            }
        }
        return pages
    }
}

/// A page of the insurance report on paper: always the light paper colors, whatever the
/// app's appearance (03 §2, "paper is a physical object"), and a fixed text size.
struct ReportPage: View {
    let blocks: [ReportBlock]
    let report: ReportSnapshot
    let cover: ReportCover
    let number: Int
    let count: Int
    var options = ReportOptions()
    var thumbnails: [String: CGImage] = [:]
    var watermarked = false
    var size = ReportPaper.size

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
                    .frame(height: block.height(width: size.width - 2 * ReportPaper.margin, totals: report.totals.count),
                           alignment: .topLeading)
                    .clipped()
            }
            Spacer(minLength: 0)
            Text("Page \(number) of \(count)")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .frame(height: ReportPaper.footerHeight, alignment: .bottomLeading)
        }
        .padding(ReportPaper.margin)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(NookColor.surfaceRaised)
        .overlay {
            if watermarked {
                Text("PREVIEW")
                    .font(.nookDisplay)
                    .tracking(NookSpace.half)
                    .foregroundStyle(NookColor.textTertiary.opacity(0.35))
                    .scaleEffect(2)
                    .rotationEffect(.degrees(-30))
                    .accessibilityHidden(true)
            }
        }
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }

    @ViewBuilder
    private func view(for block: ReportBlock) -> some View {
        switch block {
        case .cover:
            VStack(alignment: .leading, spacing: NookSpace.half) {
                Text(cover.title).font(.nookTitle).foregroundStyle(NookColor.textPrimary).lineLimit(1)
                Text(coverLine).font(.nookMeta).foregroundStyle(NookColor.textSecondary).lineLimit(1)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(report.itemCount) items").font(.nookMeta)
                    ForEach(report.totals, id: \.currencyCode) { total in
                        Text(total.amount, format: .currency(code: total.currencyCode)).font(.nookMeta.monospacedDigit())
                    }
                }
                .foregroundStyle(NookColor.textPrimary)
                .padding(.top, NookSpace.s1)
            }
        case .room(let section, let summary, let continued):
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                Text(roomHeader(section, continued: continued))
                    .font(.nookHeadline)
                    .foregroundStyle(NookColor.textPrimary)
                    .lineLimit(1)
                if let summary, !summary.isEmpty, !continued {
                    Text(summary).font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
                }
            }
            .padding(.top, NookSpace.s2)
        case .line(let line):
            HStack(spacing: NookSpace.s2) {
                if options.photos {
                    Group {
                        if let file = line.photoFile, let image = thumbnails[file] {
                            Image(decorative: image, scale: 1).resizable().scaledToFill()
                        } else {
                            NookColor.surfaceSunken
                        }
                    }
                    .frame(width: NookLayout.rowThumbnailSize, height: NookLayout.rowThumbnailSize)
                    .clipShape(.rect(cornerRadius: NookRadius.small))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(line.quantity > 1 ? "\(line.name) ×\(line.quantity)" : line.name)
                        .font(.nookMeta).foregroundStyle(NookColor.textPrimary)
                    Text(detail(line)).font(.nookFootnote).foregroundStyle(NookColor.textSecondary)
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                if let value = line.value {
                    Text(value.amount, format: .currency(code: value.currencyCode))
                        .font(.nookMeta.monospacedDigit())
                        .foregroundStyle(NookColor.textPrimary)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    /// "Harbor Mutual · Policy HM-22-4471 · Oct 4, 2026".
    private var coverLine: String {
        var parts = [cover.insurer.trimmingCharacters(in: .whitespaces)].filter { !$0.isEmpty }
        let policy = cover.policyNumber.trimmingCharacters(in: .whitespaces)
        if !policy.isEmpty { parts.append(String(localized: "Policy \(policy)")) }
        parts.append(cover.date.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }

    /// "Kitchen · 48 items · $6,240", or "Kitchen, continued".
    private func roomHeader(_ section: ReportSnapshot.Section, continued: Bool) -> String {
        let name = section.id == nil ? String(localized: "No room") : section.name
        if continued { return String(localized: "\(name), continued") }
        let totals = section.totals.map { $0.amount.formatted(.currency(code: $0.currencyCode)) }
        return ([name, String(localized: "\(section.lines.count) items")] + (totals.isEmpty ? [] : [totals.joined(separator: " + ")]))
            .joined(separator: " · ")
    }

    /// "Counter · Breville · BES870 · Serial SN-4471 · Receipt attached".
    private func detail(_ line: ReportSnapshot.Line) -> String {
        var parts = [line.place, line.detail].filter { !$0.isEmpty }
        if options.serials, !line.serial.isEmpty { parts.append(String(localized: "Serial \(line.serial)")) }
        if options.receipts, line.receiptCount > 0 { parts.append(String(localized: "Receipt attached")) }
        return parts.joined(separator: " · ")
    }
}
