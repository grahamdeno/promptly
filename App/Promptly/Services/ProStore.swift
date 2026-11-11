import Observation
import StoreKit

/// Pop In Pro: a one-time, non-consumable unlock bought through the App Store (StoreKit 2). Nothing about the
/// purchase passes through Pop In: Apple handles payment, receipts and restore.
@MainActor
@Observable
final class ProStore {
    static let productID = "com.grahamdeno.promptly.pro"

    private(set) var isPro: Bool
    private(set) var product: Product?
    private(set) var purchasing = false
    var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let defaults = UserDefaults(suiteName: "group.com.grahamdeno.promptly") ?? .standard
    /// Called when Pro turns off (for example after a refund), so Pro-only choices fall back to free ones.
    @ObservationIgnored var onLost: (() -> Void)?

    init() {
        isPro = defaults.bool(forKey: "isPro")
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    /// The displayed price, from the App Store, in the buyer's currency.
    var price: String { product?.displayPrice ?? "$4.99" }

    func load() async {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        setPro(owned)
    }

    func buy() async {
        if product == nil { await load() }
        guard let product else {
            message = "The App Store isn't reachable right now. Try again in a moment."
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if case .verified(let t) = result {
                    await t.finish()
                    setPro(true)
                    message = nil
                } else {
                    message = "Apple couldn't confirm the purchase."
                }
            case .pending:
                message = "Waiting for approval. Pro unlocks as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "Purchase didn't go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
        message = isPro ? "Pro restored." : "No Pro purchase found for this Apple Account."
    }

    private func setPro(_ value: Bool) {
        let lost = isPro && !value
        isPro = value
        defaults.set(value, forKey: "isPro")
        if lost { onLost?() }
    }
}
