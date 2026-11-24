//
//  PaymentResolver.swift
//  SpiceMonk
//

import Foundation
import Combine

/// Turns whatever Razorpay's sheet reported into what actually happened, by asking our server.
///
/// Shared by every screen that can take a payment so they cannot drift apart on the one rule that
/// matters: **only the server can say "paid"**, and no gateway result — success or failure — is
/// shown to the customer without the server's word on it.
///
/// Ported from Android's `PaymentResolver` so both apps resolve a payment identically.
actor PaymentResolver {

    static let shared = PaymentResolver()

    /// Gap before the first status poll; grows by `pollBackoff` each time, capped at `pollMaxDelay`.
    private let pollBaseDelay: Double = 1.5
    private let pollBackoff: Double = 1.6
    private let pollMaxDelay: Double = 6.0

    /// Extra attempts for a verify that failed in transport, and the first gap between them.
    private let verifyRetries = 2
    private let verifyRetryBaseDelay: Double = 0.8

    private let service = OrderServiceManager()

    private init() {}

    private static let pendingBank =
        "Your bank hasn't confirmed this payment yet. This usually settles within a few minutes."

    // MARK: - Entry points

    func resolve(
        orderId: Int,
        outcome: GatewayOutcome,
        onStep: @escaping (ResolutionStep) -> Void = { _ in }
    ) async -> PaymentResolution {
        switch outcome {
        case .succeeded(let proof):
            return await resolveSuccess(orderId: orderId, proof: proof, onStep: onStep)
        case .failed(let reason, let paymentId, let message):
            return await resolveFailure(
                orderId: orderId,
                reason: reason,
                paymentId: paymentId,
                message: message,
                onStep: onStep
            )
        }
    }

    /// Re-asks the server about an order whose payment hadn't settled.
    func recheck(orderId: Int, attempts: Int = 1) async -> PaymentResolution {
        guard let verification = await awaitSettled(orderId: orderId, attempts: attempts) else {
            return .pending(message: "Couldn't reach us to check. We'll keep trying.")
        }
        return resolution(
            from: verification,
            pendingMessage: Self.pendingBank,
            failedMessage: "This payment didn't go through. No money was taken."
        )
    }

    // MARK: - Success

    private func resolveSuccess(
        orderId: Int,
        proof: RazorpayPaymentResult,
        onStep: @escaping (ResolutionStep) -> Void
    ) async -> PaymentResolution {
        onStep(.verifying)

        if let verified = await verify(orderId: orderId, proof: proof) {
            switch verified {
            case .paid:
                return .paid(paymentId: proof.paymentId)
            case .failed:
                return .failed(message: "Your bank didn't approve this payment. No money was taken.")
            case .pending:
                break
            }
        }

        // Verification rejected, unreachable, or not settled yet. Razorpay did report a completed
        // payment, so the webhook is likely to reconcile it — poll for that instead of announcing
        // a failure for money that has probably moved.
        onStep(.checkingStatus)
        return await pollStatus(
            orderId: orderId,
            paymentId: proof.paymentId,
            attempts: 4,
            pendingMessage: "We've received your payment details and are confirming them with your "
                + "bank. If money was deducted, it's safe — your order will update shortly.",
            failedMessage: "Your payment couldn't be verified. If any amount was deducted, it will "
                + "be refunded automatically within 5–7 working days."
        )
    }

    // MARK: - Failure

    private func resolveFailure(
        orderId: Int,
        reason: GatewayFailure,
        paymentId: String?,
        message: String,
        onStep: @escaping (ResolutionStep) -> Void
    ) async -> PaymentResolution {
        let trimmed = message.trimmingCharacters(in: CharacterSet(charactersIn: ". "))

        // The sheet never worked; nothing can have been charged, so there is nothing to ask about.
        if reason == .setup {
            return .failed(message: "\(trimmed). No money was taken — please try again.")
        }

        onStep(.checkingStatus)

        switch reason {
        case .network:
            // Dropped connection: the payment is genuinely unknown. Poll properly.
            return await pollStatus(
                orderId: orderId,
                paymentId: paymentId,
                attempts: 5,
                pendingMessage: "Your connection dropped during payment. If money was deducted, "
                    + "we'll confirm your order as soon as your bank tells us.",
                failedMessage: "The payment didn't complete. No money was taken."
            )

        case .cancelled:
            // A cancel is almost always what it says, but a UPI app can take the money and then
            // have the customer back out of the sheet. One quick look catches that.
            if let paid = await quickCheck(orderId: orderId) { return paid }
            return .cancelled(
                message: "You closed the payment before it finished. You haven't been charged."
            )

        case .declined:
            if let paid = await quickCheck(orderId: orderId) { return paid }
            return .failed(
                message: "\(trimmed). No money was taken — try again or use another method."
            )

        case .setup:
            return .failed(message: "\(trimmed). No money was taken — please try again.")
        }
    }

    // MARK: - Server calls

    /// Retries only when the request never got an answer. A dropped packet here is common — the
    /// radio is often still re-attaching as the UPI app hands control back — and giving up on it
    /// means the signature is never delivered and a paid order sits on a pending screen.
    /// A server that *did* answer is taken at its word; only transport failures are retried.
    private func verify(orderId: Int, proof: RazorpayPaymentResult) async -> PaymentState? {
        var delay = verifyRetryBaseDelay

        for attempt in 0...verifyRetries {
            switch await fetch(service.verifyPayment(orderId: orderId, result: proof)) {
            case .success(let response):
                guard response.status == true, let data = response.data, data.orderId == orderId else {
                    return nil
                }
                return paymentStateOf(isPaid: data.isPaid, status: data.paymentStatus)

            case .failure:
                guard attempt < verifyRetries else { return nil }
                try? await Task.sleep(for: .seconds(delay))
                delay *= 2
            }
        }
        return nil
    }

    /// The status check is the order itself — the same thing Android reads, so no new endpoint.
    private func checkStatus(orderId: Int) async -> PaymentState? {
        guard let response = await firstValue(service.fetchOrderDetail(orderId: orderId)),
              let order = response.order
        else { return nil }
        return paymentStateOf(isPaid: nil, status: order.paymentStatus)
    }

    /// One status call: returns `.paid` if the server already has the money, else nil.
    private func quickCheck(orderId: Int) async -> PaymentResolution? {
        guard await checkStatus(orderId: orderId) == .paid else { return nil }
        return .paid(paymentId: nil)
    }

    private func awaitSettled(orderId: Int, attempts: Int) async -> PaymentState? {
        var gap = pollBaseDelay
        var last: PaymentState?

        for attempt in 1...max(attempts, 1) {
            last = await checkStatus(orderId: orderId)
            // Stop early on a decided payment; keep going on pending *and* on a transient network
            // error, since giving up on the first failed poll is what strands a paid order.
            if let state = last, state != .pending { return state }
            if attempt < max(attempts, 1) {
                try? await Task.sleep(for: .seconds(gap))
                gap = min(gap * pollBackoff, pollMaxDelay)
            }
        }
        return last
    }

    private func pollStatus(
        orderId: Int,
        paymentId: String?,
        attempts: Int,
        pendingMessage: String,
        failedMessage: String
    ) async -> PaymentResolution {
        guard let state = await awaitSettled(orderId: orderId, attempts: attempts) else {
            // Couldn't reach the server to ask. "Pending" is the only honest answer — the payment
            // may well have succeeded, and every pending screen lets them re-check.
            return .pending(message: pendingMessage)
        }
        return resolution(
            from: state,
            pendingMessage: pendingMessage,
            failedMessage: failedMessage,
            paymentId: paymentId
        )
    }

    private func resolution(
        from state: PaymentState,
        pendingMessage: String,
        failedMessage: String,
        paymentId: String? = nil
    ) -> PaymentResolution {
        switch state {
        case .paid: return .paid(paymentId: paymentId)
        case .failed: return .failed(message: failedMessage)
        case .pending: return .pending(message: pendingMessage)
        }
    }

    /// Bridges one Combine response into async. The subscription lives in this actor, not in a
    /// view, so a dismissed screen can no longer cancel a payment confirmation in flight.
    private func firstValue<T>(_ publisher: AnyPublisher<T, Error>) async -> T? {
        guard case .success(let value) = await fetch(publisher) else { return nil }
        return value
    }

    /// Distinguishes "the server answered" from "we never reached it" — `verify` needs that
    /// difference to know whether retrying is worth anything.
    ///
    /// The cancellable is cancelled after `sink` returns rather than inside the completion handler:
    /// an offline publisher (`Fail`) completes synchronously *during* `sink`, so the handler ran
    /// before the variable had been assigned and the cancel was a no-op that leaked the whole
    /// subscription graph on every offline attempt.
    private func fetch<T>(_ publisher: AnyPublisher<T, Error>) async -> Result<T, Error> {
        await withCheckedContinuation { continuation in
            var resumed = false
            let token = publisher.sink(
                receiveCompletion: { completion in
                    guard !resumed else { return }
                    resumed = true
                    switch completion {
                    case .failure(let error): continuation.resume(returning: .failure(error))
                    case .finished: continuation.resume(returning: .failure(URLError(.badServerResponse)))
                    }
                },
                receiveValue: { value in
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: .success(value))
                }
            )
            token.cancel()
        }
    }
}
