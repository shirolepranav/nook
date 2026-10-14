import Foundation
import StoreKit
import StoreKitTest
import Testing
import NookKit
@testable import Nook

/// P11: Nook Pro's entitlement against `Nook.storekit` (PRD §7, D58): a one-time $14.99
/// purchase, Family Sharing on, Ask to Buy, failures, refunds and restore.
@MainActor @Suite(.serialized)
struct StoreKitTests {
    let session: SKTestSession

    init() throws {
        session = try SKTestSession(configurationFileNamed: "Nook")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
    }

    /// Refunds and Ask to Buy approvals reach StoreKit a moment later; the app hears them
    /// through `Transaction.updates`. Wait up to 5 s for the store to settle.
    private func settle(_ store: EntitlementStore, pro: Bool) async throws {
        for _ in 0..<50 where store.isPro != pro {
            try await Task.sleep(for: .milliseconds(100))
            await store.refresh()
        }
    }

    private func product() async throws -> Product {
        try #require(try await Product.products(for: [EntitlementStore.productID]).first)
    }

    @Test func proIsOneFamilySharedPrice() async throws {
        let pro = try await product()
        #expect(pro.type == .nonConsumable)
        #expect(pro.price == Decimal(string: "14.99"))
        #expect(pro.isFamilyShareable)
    }

    @Test func buyingUnlocksAndIsCachedForOfflineUse() async throws {
        let store = EntitlementStore()
        await store.refresh()
        #expect(!store.isPro)
        let transaction = try await session.buyProduct(identifier: EntitlementStore.productID)
        await store.didPurchase(transaction)
        #expect(store.isPro)
        #expect(EntitlementCache.isPro)
        guard case .purchased = store.ownership else { Issue.record("expected a purchase"); return }
    }

    @Test func aRefundTakesProAway() async throws {
        let store = EntitlementStore()
        let transaction = try await session.buyProduct(identifier: EntitlementStore.productID)
        await store.didPurchase(transaction)
        try session.refundTransaction(identifier: UInt(transaction.id))
        try await settle(store, pro: false)
        #expect(!store.isPro)
        #expect(!EntitlementCache.isPro)
    }

    @Test func askToBuyWaitsThenUnlocksWhenApproved() async throws {
        session.askToBuyEnabled = true
        let store = EntitlementStore()
        let result = try await product().purchase()
        guard case .pending = result else { Issue.record("expected pending, got \(result)"); return }
        await store.refresh()
        #expect(!store.isPro)
        let pending = try #require(session.allTransactions().first { $0.productIdentifier == EntitlementStore.productID })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await settle(store, pro: true)
        #expect(store.isPro)
    }

    @Test func aFailedPurchaseStaysFree() async throws {
        try await session.setSimulatedError(.generic(.unknown), forAPI: .purchase)
        let store = EntitlementStore()
        await #expect(throws: (any Error).self) { _ = try await product().purchase() }
        await store.refresh()
        #expect(!store.isPro)
        try await session.setSimulatedError(nil, forAPI: .purchase)
    }

    @Test func restoreFindsAnEarlierPurchase() async throws {
        _ = try await session.buyProduct(identifier: EntitlementStore.productID)
        let store = EntitlementStore()
        #expect(await store.restore())
    }
}
