//
//  RazorpayCheckout.swift
//  SpiceMonk
//

import SwiftUI
import Razorpay

/// Razorpay's native checkout, replacing the web checkout that used to run in a `WKWebView`.
///
/// The webview could not hand off to a UPI app: those flows need a `upi://` style app switch and a
/// callback on the way back, neither of which a webview gives you — so Razorpay's web checkout
/// simply hid Google Pay, PhonePe and Paytm. Android has always used its native SDK; this is the
/// iOS half of that.
///
/// Mirrors Android's `RazorpayPaymentBridge`, including how it maps SDK errors onto
/// `GatewayFailure`, so both apps classify the same failure the same way.
@MainActor
final class RazorpayCheckoutController: NSObject {

    /// One instance process-wide, because the SDK is too: `RazorpayCheckout.initWithKey` returns a
    /// shared object and stores its delegate *weakly*, last-writer-wins. A second controller would
    /// silently steal the callback, and the first checkout's completion handler would never run —
    /// leaving whichever screen started it stuck under a progress overlay with no way out.
    static let shared = RazorpayCheckoutController()

    private var razorpay: RazorpayCheckout?
    private var activeRazorpayOrderId: String?
    private var onOutcome: ((GatewayOutcome) -> Void)?

    private override init() { super.init() }

    /// True while a checkout is on screen. Callers must not start a second one.
    var isPresenting: Bool { onOutcome != nil }

    /// Opens checkout over `presenter`. Returns false if a checkout is already running, so the
    /// caller knows not to show a progress overlay it would never be able to clear.
    @discardableResult
    func open(
        initiateData: PaymentInitiateData,
        description: String,
        from presenter: UIViewController,
        onOutcome: @escaping (GatewayOutcome) -> Void
    ) -> Bool {
        guard !isPresenting else { return false }

        self.onOutcome = onOutcome
        activeRazorpayOrderId = initiateData.razorpayOrderId

        let checkout = RazorpayCheckout.initWithKey(initiateData.razorpayKeyId, andDelegateWithData: self)
        razorpay = checkout
        checkout.open(options(for: initiateData, description: description), displayController: presenter)
        return true
    }

    private func options(for data: PaymentInitiateData, description: String) -> [String: Any] {
        var prefill: [String: Any] = [:]
        if let name = data.customerName, !name.isEmptyString { prefill["name"] = name }
        if let email = data.customerEmail, !email.isEmptyString { prefill["email"] = email }
        if let mobile = data.customerMobile, !mobile.isEmptyString { prefill["contact"] = mobile }

        return [
            "name": "SpiceMonk",
            "description": description,
            "order_id": data.razorpayOrderId,
            "amount": data.amount,
            "currency": data.currency,
            "timeout": 900,
            "theme": ["color": "#167444"],
            "retry": ["enabled": true, "max_count": 3],
            "modal": ["confirm_close": true],
            "prefill": prefill
        ]
    }

    private func finish(_ outcome: GatewayOutcome) {
        activeRazorpayOrderId = nil
        let handler = onOutcome
        onOutcome = nil
        handler?(outcome)
    }
}

extension RazorpayCheckoutController: RazorpayPaymentCompletionProtocolWithData {

    nonisolated func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable: Any]?) {
        MainActor.assumeIsolated { handleSuccess(payment_id, response) }
    }

    private func handleSuccess(_ payment_id: String, _ response: [AnyHashable: Any]?) {
        let orderId = (response?["razorpay_order_id"] as? String) ?? activeRazorpayOrderId
        let paymentId = (response?["razorpay_payment_id"] as? String) ?? payment_id
        let signature = response?["razorpay_signature"] as? String

        guard let orderId, !orderId.isEmpty,
              !paymentId.isEmpty,
              let signature, !signature.isEmpty,
              let proof = RazorpayPaymentResult(data: [
                  "razorpay_order_id": orderId,
                  "razorpay_payment_id": paymentId,
                  "razorpay_signature": signature
              ])
        else {
            // A success with no signature can't be verified — let the server status decide, which
            // is exactly what a network failure does.
            finish(.failed(
                reason: .network,
                paymentId: paymentId.isEmpty ? nil : paymentId,
                message: "We couldn't confirm the payment on this device."
            ))
            return
        }
        finish(.succeeded(proof: proof))
    }

    nonisolated func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable: Any]?) {
        MainActor.assumeIsolated { handleError(code, str, response) }
    }

    private func handleError(_ code: Int32, _ str: String, _ response: [AnyHashable: Any]?) {
        let reason = Self.failure(forCode: code, response: response)
        let message = str.isEmptyString ? Self.defaultMessage(for: reason) : str
        finish(.failed(
            reason: reason,
            paymentId: Self.paymentId(in: response),
            message: message
        ))
    }

    /// The SDK hands back a bare `Int32` and exports no constants for them. Only the two codes
    /// whose meaning is unambiguous on iOS are named; everything else is deliberately unclassified.
    private enum ErrorCode {
        static let network: Int32 = 0
        static let paymentCancelled: Int32 = 2
    }

    /// Classifies a checkout failure, biased so that an unrecognised code still asks the server.
    ///
    /// `.setup` is the one verdict `PaymentResolver` acts on without a status check — it means
    /// "nothing can have been charged". Mapping a code to it on a guess is how a real payment gets
    /// announced as "no money was taken", so nothing reaches `.setup` from here: anything that is
    /// not clearly a cancel or a dropped connection falls to `.declined`, which checks first.
    private static func failure(forCode code: Int32, response: [AnyHashable: Any]?) -> GatewayFailure {
        switch code {
        case ErrorCode.paymentCancelled where reason(in: response) != "payment_failed":
            return .cancelled
        case ErrorCode.network:
            return .network
        default:
            return .declined
        }
    }

    /// iOS nests the gateway's detail under `error`, unlike the flat payload Android reads — so a
    /// top-level lookup silently never matched, and a decline arriving as a cancel code stayed
    /// mis-classified as a user cancellation.
    private static func reason(in response: [AnyHashable: Any]?) -> String {
        if let nested = response?["error"] as? [AnyHashable: Any],
           let reason = nested["reason"] as? String {
            return reason
        }
        return (response?["reason"] as? String) ?? ""
    }

    private static func paymentId(in response: [AnyHashable: Any]?) -> String? {
        if let nested = response?["error"] as? [AnyHashable: Any],
           let id = nested["metadata"] as? [AnyHashable: Any],
           let paymentId = id["payment_id"] as? String, !paymentId.isEmpty {
            return paymentId
        }
        return (response?["razorpay_payment_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func defaultMessage(for reason: GatewayFailure) -> String {
        switch reason {
        case .cancelled: return "You closed the payment before it finished."
        case .network: return "The connection dropped during payment."
        case .declined: return "The payment was declined."
        case .setup: return "The payment screen couldn't load."
        }
    }
}
