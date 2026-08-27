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

    @Environment(\.dismiss) private var dismiss
    @State private var isVerifying = false
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

                CashfreeCheckoutWebView(
                    paymentSessionId: initiateData.paymentSessionId,
                    environment: initiateData.environment,
                    onPaymentRedirect: { url in
                        let urlString = url.absoluteString.lowercased()
                        if urlString.contains("spicemonk.revateam.com") {
                            verifyPayment()
                        }
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
                        onFailure("Payment cancelled by user.")
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if isVerifying {
                        ProgressView()
                    } else {
                        Button("Verify") {
                            verifyPayment()
                        }
                        .font(.appFont(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.brandGreen)
                    }
                }
            }
        }
    }

    private func verifyPayment() {
        guard !isVerifying else { return }
        isVerifying = true
        errorMessage = nil

        OrderServiceManager().verifyPayment(orderId: initiateData.orderId)
            .receive(on: RunLoop.main)
            .sink { completion in
                isVerifying = false
                if case .failure(let error) = completion {
                    errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { response in
                isVerifying = false
                if response.status == true && response.data?.isPaid == true {
                    onSuccess()
                    dismiss()
                } else {
                    errorMessage = response.message ?? "Payment is still pending on Cashfree gateway."
                }
            }
            .store(in: &cancellables)
    }
}

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
