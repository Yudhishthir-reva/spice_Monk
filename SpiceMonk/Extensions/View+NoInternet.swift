//
//  View+NoInternet.swift
//  SpiceMonk
//

import SwiftUI

struct NoInternetBanner: View {

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.slash")
            Text("No internet connection")
                .font(.appFont(size: 15, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(hex: "C62828"))
    }
}

struct NoInternetModifier: ViewModifier {

    @ObservedObject private var monitor = NetworkMonitor.shared

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !monitor.isConnected {
                NoInternetBanner()
            }
            content
        }
        .animation(.easeInOut(duration: 0.25), value: monitor.isConnected)
    }
}

extension View {
    func handleNoInternet() -> some View {
        modifier(NoInternetModifier())
    }
}
