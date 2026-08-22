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
    @State private var showWebView = false
    @State private var cancellables = Set<AnyCancellable>()

    private var checkoutUrl: String {
        let isProd = initiateData.environment.lowercased() == "production"
        let baseUrl = isProd ? "https://payments.cashfree.com" : "https://payments-test.cashfree.com"
        return "\(baseUrl)/order/#/\(initiateData.paymentSessionId)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showWebView {
                    ZStack(alignment: .bottom) {
                        PaymentWebView(urlString: checkoutUrl) { _ in }
                            .ignoresSafeArea(edges: .bottom)

                        // Floating action panel inside Web Checkout
                        VStack(spacing: 12) {
                            if isVerifying {
                                ProgressView("Verifying payment status...")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: .black.opacity(0.1), radius: 10)
                            } else {
                                Button {
                                    verifyPayment()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("I Completed Payment (Verify)")
                                            .font(.system(size: 14, weight: .bold))
                                        Image(systemName: "checkmark.shield.fill")
                                            .font(.system(size: 15))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(AppTheme.brandGreen)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: AppTheme.brandGreen.opacity(0.2), radius: 6)
                                }
                                .buttonStyle(.plain)
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                } else {
                    mainMenuBody
                }
            }
            .background(Color(hex: "F8FAF8"))
            .navigationTitle(showWebView ? "Cashfree Checkout" : "Prepaid Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(showWebView ? "Back" : "Cancel") {
                        if showWebView {
                            showWebView = false
                        } else {
                            onFailure("Payment cancelled by user.")
                            dismiss()
                        }
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var mainMenuBody: some View {
        VStack(spacing: 24) {
            // Secure header
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.brandGreen)
                    Text("SECURE TEST GATEWAY")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(AppTheme.brandGreen)
                        .tracking(1.2)
                }

                Text("Cashfree payments")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)

                if !initiateData.environment.isEmpty {
                    Text(initiateData.environment.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "F59E0B"))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 24)

            // Total display
            VStack(spacing: 4) {
                Text("Amount to Pay")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("₹\(Int(initiateData.orderAmount.rounded()))")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(hex: "F4F4F5"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Info Box
            VStack(alignment: .leading, spacing: 6) {
                Text("Testing Instructions:")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Choose 'Pay via Cashfree' to complete actual sandbox transactions, or select 'Bypass & Force Success' to immediately test the success UI path.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineSpacing(3)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer()

            // Actions block
            VStack(spacing: 12) {
                if isVerifying {
                    ProgressView("Verifying payment status...")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(height: 52)
                } else {
                    // Pay via Cashfree Webview
                    Button {
                        errorMessage = nil
                        showWebView = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Pay via Cashfree (Staging Page)")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.brandGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.brandGreen.opacity(0.18), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)

                    // Bypass local success
                    Button {
                        onSuccess()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Bypass & Force Success (Local Test)")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(AppTheme.brandGreen)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.brandGreen.opacity(0.2), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)

                    // Failure Button
                    Button {
                        onFailure("Payment cancelled by user.")
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Simulate Failed/Cancelled Payment")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // PCI-DSS footer
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textMuted)
                Text("Secured by Cashfree Payments · PCI-DSS Compliant")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textMuted)
            }
            .padding(.bottom, 12)
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

// MARK: - WebView Wrapper

struct PaymentWebView: UIViewRepresentable {
    let urlString: String
    let onNavigationStateChange: (URL?) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: PaymentWebView

        init(_ parent: PaymentWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onNavigationStateChange(webView.url)
        }
    }
}
