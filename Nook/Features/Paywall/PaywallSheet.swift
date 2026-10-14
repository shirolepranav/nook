import SwiftUI
import SwiftData
import StoreKit
import NookKit
import NookUI

/// Why P-01 opened (D9, D58). It picks the success button, and `onUnlock` carries on with
/// what the user was doing.
enum PaywallReason {
    case item, items, reminder, export, backup, sync, settings

    var continueTitle: LocalizedStringKey {
        switch self {
        case .item: "Save Your Item"
        case .items: "Save Your Items"
        case .reminder: "Save Your Warranty"
        case .export: "Back to Your Report"
        case .backup: "Back Up Now"
        case .sync: "Turn On iCloud Sync"
        case .settings: "Done"
        }
    }
}

/// One showing of P-01. Each screen that can hit a limit holds one in `@State` and shows it
/// with `.paywall(_:)`, so the sheet opens over that screen, sheets included.
struct PaywallRequest: Identifiable {
    let id = UUID()
    let reason: PaywallReason
    var onUnlock: () -> Void = {}
}

extension View {
    /// P-01 as a sheet: a centered form sheet on regular width (01 §1.5, D29).
    func paywall(_ request: Binding<PaywallRequest?>) -> some View {
        sheet(item: request) { request in
            PaywallSheet(request: request).presentationSizing(.form)
        }
    }
}

/// P-01 Paywall (PRD §7): one screen, one price, one button, with the user's own numbers.
/// Opened only at a moment of value, never on launch (D58).
struct PaywallSheet: View {
    let request: PaywallRequest

    enum Phase: Equatable { case shopping, purchasing, pending, failed, success }

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<Item> { $0.deletedAt == nil }) private var items: [Item]
    @AppStorage(MoneyText.hideValuesKey) private var hideValues = false
    @State private var phase = Phase.shopping
    @State private var restoring = false
    @State private var nothingToRestore = false
    @State private var showsPrivacy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if phase == .success { success } else { offer }
                }
                .padding(.horizontal, NookSpace.s3)
                .padding(.bottom, NookSpace.s2)
                .frame(maxWidth: NookLayout.readableWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(NookColor.canvas)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .nookAnimation(.settle, value: phase)
        .nookHaptic(.saved, trigger: phase == .success)
        .nookHaptic(.failed, trigger: phase == .failed)
        // An Ask to Buy approval or a purchase on another device lands here too.
        .onChange(of: entitlements.isPro) { _, isPro in if isPro { phase = .success } }
        .sheet(isPresented: $showsPrivacy) { NavigationStack { PrivacyScreen(showsDone: true) } }
    }

    // MARK: Offer

    private var offer: some View {
        VStack(alignment: .leading, spacing: NookSpace.s2) {
            IllustrationView(.shelfFull)
                .frame(maxWidth: .infinity)
                .frame(height: NookLayout.illustrationHeight)
                .accessibilityHidden(true)
            if !items.isEmpty { numbers }
            VStack(alignment: .leading, spacing: NookSpace.s2) {
                benefit("square.stack.3d.up", "Unlimited items and warranty reminders")
                benefit("doc.richtext", "Insurance report and CSV export")
                benefit("icloud", "iCloud sync and backup")
            }
            purchase
            switch phase {
            case .pending:
                notice("hourglass", "Waiting for approval. Pro unlocks as soon as it’s approved.", tint: NookColor.info)
            case .failed:
                notice("exclamationmark.circle", "The purchase didn’t go through, and you haven’t been charged. You can try again.",
                       tint: NookColor.textSecondary)
            default:
                EmptyView()
            }
            Text("Pay once. No subscription. Family Sharing included.")
                .font(.nookFootnote)
                .foregroundStyle(NookColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
            links
        }
    }

    /// "You've documented 25 items worth $4,380" (PRD §7). The worth is the home currency's
    /// total (D20) and stays out when values are hidden or nothing has a price.
    private var numbers: some View {
        let code = HomeCurrency.code
        let total = items.compactMap(\.value).filter { $0.currencyCode == code }.reduce(Decimal(0)) { $0 + $1.amount }
        return VStack(alignment: .leading, spacing: 0) {
            Text("You’ve documented")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
            Group {
                if hideValues || total == 0 {
                    Text("\(items.count) items")
                } else {
                    Text("\(items.count) items worth \(total.formatted(.currency(code: code).precision(.fractionLength(0))))")
                }
            }
            .font(.nookTotal)
            .foregroundStyle(NookColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func benefit(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: NookSpace.s2) {
            BenefitIcon(symbol: symbol)
            Text(text)
                .font(.nookBody)
                .foregroundStyle(NookColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func notice(_ symbol: String, _ text: LocalizedStringKey, tint: Color) -> some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
            .font(.nookMeta)
            .foregroundStyle(NookColor.textPrimary)
            .padding(NookSpace.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nookCard(radius: NookRadius.medium, elevation: .flat)
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// The native `ProductView` (PRD §7), drawn as the board's card and button.
    @ViewBuilder
    private var purchase: some View {
        #if DEBUG
        if let fake = Self.fakePurchase {
            PurchaseCard(price: Text(verbatim: "$14.99"), phase: phase) {
                switch fake {
                case "pending": phase = .pending
                case "failed": phase = .failed
                default: entitlements.unlockForTesting()
                }
            }
        } else {
            storeProduct
        }
        #else
        storeProduct
        #endif
    }

    private var storeProduct: some View {
        ProductView(id: EntitlementStore.productID)
            .productViewStyle(NookProductViewStyle(phase: phase))
            .onInAppPurchaseStart { _ in phase = .purchasing }
            .onInAppPurchaseCompletion { _, result in
                switch result {
                case .success(.success(.verified(let transaction))):
                    await entitlements.didPurchase(transaction)
                    phase = .success
                case .success(.pending):
                    phase = .pending
                case .success(.userCancelled):
                    phase = .shopping   // no blame, no message (01 P-01)
                default:
                    phase = .failed
                }
            }
    }

    #if DEBUG
    /// UI tests: `-uiTestingPurchase success|pending|failed` stands in for the App Store sheet.
    private static let fakePurchase: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-uiTestingPurchase"), flag + 1 < arguments.count else { return nil }
        return arguments[flag + 1]
    }()
    #endif

    private var links: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: NookSpace.s2) { linkButtons }
            VStack(spacing: 0) { linkButtons }
        }
        .font(.nookFootnote.weight(.semibold))
        .frame(maxWidth: .infinity)
        .alert("No purchase found", isPresented: $nothingToRestore) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Nook Pro isn’t on this Apple Account. If you bought it with another one, sign in with it in the App Store.")
        }
    }

    @ViewBuilder
    private var linkButtons: some View {
        Button {
            restoring = true
            Task {
                if await entitlements.restore() { phase = .success } else { nothingToRestore = true }
                restoring = false
            }
        } label: {
            Text(restoring ? "Restoring…" : "Restore Purchases")
        }
        .disabled(restoring)
        .frame(minHeight: NookLayout.minTapTarget)
        Link("Terms", destination: Legal.terms)
            .frame(minHeight: NookLayout.minTapTarget)
        Button("Privacy") { showsPrivacy = true }
            .frame(minHeight: NookLayout.minTapTarget)
    }

    // MARK: Success

    private var success: some View {
        VStack(spacing: NookSpace.s2) {
            Image(systemName: "checkmark")
                .font(.nookDisplay)
                .foregroundStyle(NookColor.success)
                .frame(width: NookLayout.stateIconSize, height: NookLayout.stateIconSize)
                .background(NookColor.success.opacity(0.14), in: .circle)
                .accessibilityHidden(true)
            Text("Nook Pro is yours.")
                .font(.nookDisplay)
                .foregroundStyle(NookColor.textPrimary)
            Text("Thank you. Everything is unlocked, on every iPhone in your family.")
                .font(.nookMeta)
                .foregroundStyle(NookColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                dismiss()
                request.onUnlock()
            } label: {
                Text(request.reason.continueTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.nookPrimary)
            .padding(.top, NookSpace.s1)
        }
        .multilineTextAlignment(.center)
        .padding(.top, NookSpace.s6)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .onAppear { AccessibilityNotification.Announcement(String(localized: "Nook Pro is yours.")).post() }
    }
}

/// The accent-tinted circle behind each benefit's symbol (the P-01 board).
private struct BenefitIcon: View {
    let symbol: String
    @Environment(\.nookAccent) private var accent

    var body: some View {
        Image(systemName: symbol)
            .font(.nookMeta.weight(.semibold))
            .foregroundStyle(accent.color)
            .frame(width: NookLayout.placeIconSize, height: NookLayout.placeIconSize)
            .background(accent.suggested, in: .circle)
            .accessibilityHidden(true)
    }
}

/// `ProductView`'s look: the board's card, then the one button.
private struct NookProductViewStyle: ProductViewStyle {
    let phase: PaywallSheet.Phase

    func makeBody(configuration: Configuration) -> some View {
        switch configuration.state {
        case .success(let product):
            PurchaseCard(price: Text(product.displayPrice), phase: phase) { configuration.purchase() }
        case .loading:
            PurchaseCard(price: nil, phase: phase) {}
        default:
            // No App Store connection: say so calmly; nothing is lost (01 §1.3).
            VStack(alignment: .leading, spacing: NookSpace.s1) {
                PurchaseCard(price: nil, phase: phase, available: false) {}
                Text("Nook Pro isn’t available right now. Check your connection and try again.")
                    .font(.nookFootnote)
                    .foregroundStyle(NookColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// "Nook Pro · One-time purchase · $14.99" and "Unlock Nook Pro" (one price, D58).
private struct PurchaseCard: View {
    let price: Text?
    let phase: PaywallSheet.Phase
    var available = true
    let buy: () -> Void
    @Environment(\.nookAccent) private var accent
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: NookSpace.s2) {
            card
            if phase == .purchasing {
                ProgressView()
                    .tint(accent.onAccent)
                    .frame(maxWidth: .infinity, minHeight: NookLayout.buttonHeight)
                    .background(accent.color, in: .capsule)
                    .accessibilityLabel(Text("Purchasing"))
            } else if phase != .pending {
                Button(action: buy) { Text("Unlock Nook Pro").frame(maxWidth: .infinity) }
                    .buttonStyle(.nookPrimary)
                    .disabled(price == nil || !available)
            }
        }
    }

    private var card: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NookSpace.s1))
            : AnyLayout(HStackLayout(spacing: NookSpace.s2))
        return layout {
            Image(systemName: "shippingbox.fill")
                .font(.nookSection)
                .foregroundStyle(accent.onAccent)
                .frame(width: NookLayout.swatchSize, height: NookLayout.swatchSize)
                .background(accent.color, in: .rect(cornerRadius: NookRadius.medium))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Nook Pro").font(.nookHeadline).foregroundStyle(NookColor.textPrimary)
                Text("One-time purchase").font(.nookMeta).foregroundStyle(NookColor.textSecondary)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            if let price {
                price.font(.nookHeadline).monospacedDigit().foregroundStyle(NookColor.textPrimary)
            } else if available {
                RoundedRectangle(cornerRadius: NookRadius.medium)
                    .fill(NookColor.surfaceSunken)
                    .frame(width: NookSpace.s6 + NookSpace.s2, height: NookSpace.s3)
                    .accessibilityLabel(Text("Loading price"))
            }
        }
        .padding(NookSpace.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nookCard()
        .accessibilityElement(children: .combine)
    }
}

/// P-01's links (D58): Apple's standard licence, since Nook has no website.
enum Legal {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
