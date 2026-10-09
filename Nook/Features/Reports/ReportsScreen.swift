import SwiftUI
import SwiftData
import NookKit
import NookUI

/// R-01. Warranties and Lent out (P7); the insurance report and CSV arrive in P10.
struct ReportsScreen: View {
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]

    var body: some View {
        TabRoot("Reports", tab: .reports) {
            VStack(spacing: NookSpace.s3) {   // not a Group: that would register the destination twice
                NavigationLink(value: ReportsRoute.warranties) {
                    ReportCard(symbol: "checkmark.shield", color: NookColor.warning, title: Text("Warranties"),
                               detail: warrantiesDetail)
                }
                NavigationLink(value: ReportsRoute.lentOut) {
                    ReportCard(symbol: "person", color: NookColor.info, title: Text("Lent out"), detail: lentDetail)
                }
            }
            .buttonStyle(.nookCard)
            .navigationDestination(for: ReportsRoute.self) { route in   // inside the tab's stack
                switch route {
                case .warranties: WarrantiesScreen()
                case .lentOut: LentOutScreen()
                }
            }
        }
    }

    /// "2 ending in the next 30 days" (R-01 board).
    private var warrantiesDetail: Text {
        let ends = items.compactMap { $0.primaryWarranty?.endDate }
        let ending = ends.filter { SearchFilter.status(of: $0, now: .now) == .ending }.count
        if ending > 0 { return Text("\(ending) ending in the next 30 days") }
        return ends.isEmpty ? Text("No warranties yet") : Text("\(ends.count) warranties")
    }

    /// "1 item with Jordan" (R-01 board).
    private var lentDetail: Text {
        let loans = items.compactMap(\.activeLoan)
        if loans.count == 1, let loan = loans.first, loan.item?.isPrivate == false {
            return Text("1 item with \(loan.personName)")
        }
        return loans.isEmpty ? Text("Nothing’s out right now") : Text("\(loans.count) items lent")
    }
}

/// A report on R-01: a tinted symbol, a title over a detail, and a chevron.
private struct ReportCard: View {
    let symbol: String
    let color: Color
    let title: Text
    let detail: Text

    var body: some View {
        HStack(spacing: NookSpace.s2) {
            Image(systemName: symbol)
                .font(.nookHeadline)
                .foregroundStyle(color)
                .frame(width: NookLayout.rowThumbnailSize, height: NookLayout.rowThumbnailSize)
                .background(color.opacity(0.14), in: Circle())
                .dynamicTypeSize(...DynamicTypeSize.large)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                title.font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
                detail.font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.right")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(NookSpace.s2)
        .nookCard(elevation: .flat)
        .accessibilityElement(children: .combine)
    }
}

#Preview { ReportsScreen().modelContainer(PreviewStore.seeded(.lived)).nookAccent(.terracotta) }
