//
//  PaymentSimulationSheet.swift
//  SpiceMonk
//

import SwiftUI
import Combine
import WebKit

struct PaymentSimulationSheet: View {

    let initiateData: PaymentInitiateData
    let onSuccess: () -> Void
    let onFailure: (String) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isVerifying = false
    @State private var didFinish = false
    @State private var paymentResult: RazorpayPaymentResult?
    @State private var errorMessage: String? = nil
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let error = errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.appFont(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red)
                }

                RazorpayCheckoutWebView(
                    initiateData: initiateData,
                    onSuccess: { result in
                        guard !didFinish, paymentResult == nil else { return }
                        paymentResult = result
                        verifyPayment()
                    },
                    onFailure: { message in
                        guard !didFinish, paymentResult == nil else { return }
                        didFinish = true
                        onFailure(message)
                        dismiss()
                    },
                    onError: { errorMessage = $0 },
                    onCancel: {
                        guard !didFinish, !isVerifying, paymentResult == nil else { return }
                        didFinish = true
                        onCancel()
                        dismiss()
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .background(Color(hex: "F8FAF8"))
            .navigationTitle("Secure Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        guard !didFinish, !isVerifying, paymentResult == nil else { return }
                        didFinish = true
                        onCancel()
                        dismiss()
                    }
                    .disabled(isVerifying || paymentResult != nil)
                    .foregroundStyle(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isVerifying {
                        ProgressView()
                    } else {
                        Button("Verify") {
                            verifyPayment()
                        }
                        .disabled(paymentResult == nil)
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func verifyPayment() {
        guard !isVerifying, let paymentResult else { return }
        isVerifying = true
        errorMessage = nil

        OrderServiceManager().verifyPayment(orderId: initiateData.orderId, result: paymentResult)
            .receive(on: RunLoop.main)
            .sink { completion in
                isVerifying = false
                if case .failure(let error) = completion {
                    errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { response in
                isVerifying = false
                if response.status == true && response.data?.isPaid == true && response.data?.orderId == initiateData.orderId {
                    guard !didFinish else { return }
                    didFinish = true
                    onSuccess()
                    dismiss()
                } else {
                    errorMessage = response.message ?? "Payment is still pending on Razorpay gateway."
                }
            }
            .store(in: &cancellables)
    }
}

// Cashfree checkout is disabled; retained below for reference.
#if false
// MARK: - Cashfree JS SDK WebView

/// Loads a local HTML page that includes the Cashfree JavaScript SDK and
/// triggers `cashfree.checkout()` with the given `paymentSessionId`.
/// This is the correct integration path when the native Cashfree iOS SDK
/// is not available — the JS SDK handles all payment UI rendering.
struct CashfreeCheckoutWebView: UIViewRepresentable {
    let paymentSessionId: String
    let environment: String
    let onPaymentRedirect: (URL) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        let isProd = environment.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "production"
        let mode = isProd ? "production" : "sandbox"

        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>Payment</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    background: #F8FAF8;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    min-height: 100vh;
                    color: #333;
                }
                .loader {
                    text-align: center;
                    padding: 40px 20px;
                }
                .spinner {
                    width: 36px; height: 36px;
                    border: 3px solid #e0e0e0;
                    border-top-color: #2E7D32;
                    border-radius: 50%;
                    animation: spin 0.8s linear infinite;
                    margin: 0 auto 16px;
                }
                @keyframes spin { to { transform: rotate(360deg); } }
                .loader p { font-size: 14px; color: #666; }
                .error { color: #c62828; font-size: 14px; text-align: center; padding: 40px 20px; }
            </style>
        </head>
        <body>
            <div class="loader" id="loader">
                <div class="spinner"></div>
                <p>Loading payment gateway...</p>
            </div>
            <div class="error" id="error" style="display:none;"></div>

            <script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>
            <script>
                (function() {
                    try {
                        const cashfree = Cashfree({ mode: "\(mode)" });
                        cashfree.checkout({
                            paymentSessionId: "\(paymentSessionId)",
                            redirectTarget: "_self"
                        }).then(function(result) {
                            if (result.error) {
                                document.getElementById("loader").style.display = "none";
                                document.getElementById("error").style.display = "block";
                                document.getElementById("error").innerText = result.error.message || "Payment could not be completed.";
                            }
                            if (result.paymentDetails) {
                                document.getElementById("loader").innerHTML = "<p>Payment processing...</p>";
                            }
                        });
                    } catch(e) {
                        document.getElementById("loader").style.display = "none";
                        document.getElementById("error").style.display = "block";
                        document.getElementById("error").innerText = "Failed to initialize payment: " + e.message;
                    }
                })();
            </script>
        </body>
        </html>
        """

        print("--- PAYMENT DEBUG INFO ---")
        print("Environment from Server: '\(environment)'")
        print("Cashfree SDK Mode: '\(mode)'")
        print("Payment Session ID: '\(paymentSessionId)'")
        print("--------------------------")

        webView.loadHTMLString(html, baseURL: URL(string: "https://sdk.cashfree.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CashfreeCheckoutWebView

        init(_ parent: CashfreeCheckoutWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("[CashfreeWebView] Navigation to: \(url.absoluteString)")
                parent.onPaymentRedirect(url)
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                print("[CashfreeWebView] Finished loading: \(url.absoluteString)")
                parent.onPaymentRedirect(url)
            }
        }
    }
}

#endif

// MARK: - Razorpay Checkout

struct RazorpayCheckoutWebView: UIViewRepresentable {
    let initiateData: PaymentInitiateData
    let onSuccess: (RazorpayPaymentResult) -> Void
    let onFailure: (String) -> Void
    let onError: (String) -> Void
    let onCancel: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "payment")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        let options: [String: Any] = [
            "key": initiateData.razorpayKeyId,
            "order_id": initiateData.razorpayOrderId,
            "amount": initiateData.amount,
            "currency": initiateData.currency,
            "name": "SpiceMonk",
            "retry": ["enabled": false],
            "prefill": [
                "name": initiateData.customerName ?? "",
                "email": initiateData.customerEmail ?? "",
                "contact": initiateData.customerMobile ?? ""
            ]
        ]
        // Base64 avoids inserting server-provided strings into executable HTML.
        guard let json = try? JSONSerialization.data(withJSONObject: options) else { return webView }
        let encoded = json.base64EncodedString()
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        </head><body><p>Loading secure payment…</p>
        <script>
        function send(type, data) {
            window.webkit.messageHandlers.payment.postMessage({type: type, data: data || {}});
        }
        </script>
        <script src="https://checkout.razorpay.com/v1/checkout.js"
                onerror="send('error', {message: 'Unable to load Razorpay. Check your connection.'})"></script>
        <script>
        try {
            const options = JSON.parse(atob("\(encoded)"));
            let completed = false;
            options.handler = function(response) {
                completed = true;
                send('success', response);
            };
            options.modal = {ondismiss: function() { if (!completed) send('cancel'); }};
            const checkout = new Razorpay(options);
            checkout.on('payment.failed', function(response) {
                if (completed) return;
                completed = true;
                send('failure', {message: response.error.description || 'Payment failed. Please try again.'});
            });
            checkout.open();
        } catch (error) { send('error', {message: 'Unable to open Razorpay. Please try again.'}); }
        </script></body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://spicemonk.in"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "payment")
        uiView.navigationDelegate = nil
        uiView.stopLoading()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let parent: RazorpayCheckoutWebView
        init(_ parent: RazorpayCheckoutWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            let data = body["data"] as? [String: String] ?? [:]
            switch type {
            case "success":
                guard let result = RazorpayPaymentResult(data: data),
                      result.orderId == parent.initiateData.razorpayOrderId else {
                    parent.onError("Invalid payment response. Please verify payment status.")
                    return
                }
                parent.onSuccess(result)
            case "failure": parent.onFailure(data["message"] ?? "Payment could not be completed.")
            case "cancel": parent.onCancel()
            case "error": parent.onError(data["message"] ?? "Payment could not be completed.")
            default: break
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onError("Unable to load payment. Check your connection and try again.")
        }
    }
}
