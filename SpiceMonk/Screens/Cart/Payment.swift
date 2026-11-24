//
//  Payment.swift
//  SpiceMonk
//

import Foundation

/// What the server says about an order's money, independent of what the gateway's sheet reported.
enum PaymentState {
    case paid
    case pending
    case failed
}

/// Reads a server payment status without ever guessing upward.
///
/// `paid` and `failed` are claimed only on an explicit match; anything unrecognised is `pending`.
/// That asymmetry is deliberate — a wrong `pending` costs one extra poll, while a wrong `paid`
/// ships an unpaid order and a wrong `failed` strands a paid one.
func paymentStateOf(isPaid: Bool?, status: String?) -> PaymentState {
    if isPaid == true { return .paid }

    let normalized = (status ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()

    // Exact matches only. Substring matching looks tolerant but is actively dangerous here:
    // "unpaid" contains "paid", so a loose check would ship an unpaid order as paid. Anything not
    // on these lists falls through to `.pending`, which only ever costs an extra status poll.
    //
    // Production sends lowercase "paid" / "pending"; the rest are defensive synonyms.
    let paidWords: Set<String> = ["paid", "success", "successful", "captured", "completed", "settled"]
    let failedWords: Set<String> = [
        "failed", "failure", "declined", "rejected", "cancelled", "canceled", "refunded", "void"
    ]

    if paidWords.contains(normalized) { return .paid }
    if failedWords.contains(normalized) { return .failed }
    return .pending
}

/// What the gateway's sheet reported. Never shown to the customer on its own — the server decides.
enum GatewayOutcome {
    case succeeded(proof: RazorpayPaymentResult)
    case failed(reason: GatewayFailure, paymentId: String?, message: String)
}

enum GatewayFailure {
    /// Checkout never opened, so nothing can have been charged.
    case setup
    /// The connection dropped mid-payment — the true state is genuinely unknown.
    case network
    /// The customer closed checkout.
    case cancelled
    /// The bank or gateway refused it.
    case declined
}

/// What actually happened, after the server has had its say.
enum PaymentResolution {
    case paid(paymentId: String?)
    /// Money may be moving. The order stands; re-checking can resolve it.
    case pending(message: String)
    /// The customer closed checkout. Nothing was charged.
    case cancelled(message: String)
    /// Declined, errored, or could not start. Nothing was charged; a new attempt is safe.
    case failed(message: String)
}

/// What the resolver is doing right now, so a waiting screen can say so.
enum ResolutionStep {
    case verifying
    case checkingStatus
}

/// The steps between tapping "Place Order" (or "Retry payment") and knowing how it went. Each has
/// a caption because a spinner with no explanation, while the screen is frozen and money is
/// involved, reads as a hang.
enum CheckoutStage {
    case placingOrder
    case startingPayment
    case atGateway
    case verifying
    case checkingStatus

    var caption: String {
        switch self {
        case .placingOrder: return "Placing your order…"
        case .startingPayment: return "Opening secure checkout…"
        case .atGateway: return "Complete the payment to continue"
        case .verifying: return "Confirming your payment…"
        case .checkingStatus: return "Checking with your bank…"
        }
    }

    var hint: String {
        switch self {
        case .placingOrder: return "Locking in your prices and delivery slot"
        case .startingPayment: return "Connecting to Razorpay"
        case .atGateway: return "Approve the request in your UPI app or bank page"
        case .verifying: return "Verifying with Razorpay — this takes a few seconds"
        case .checkingStatus: return "Some banks take a moment to confirm. Please stay on this screen."
        }
    }

    /// Position on the order → pay → confirm tracker.
    var step: Int {
        switch self {
        case .placingOrder: return 0
        case .startingPayment, .atGateway: return 1
        case .verifying, .checkingStatus: return 2
        }
    }

    static func from(_ step: ResolutionStep) -> CheckoutStage {
        switch step {
        case .verifying: return .verifying
        case .checkingStatus: return .checkingStatus
        }
    }
}
