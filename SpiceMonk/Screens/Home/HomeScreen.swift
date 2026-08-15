//
//  HomeScreen.swift
//  SpiceMonk
//

import SwiftUI

struct HomeScreen: View {

    @StateObject var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Welcome")
                    .font(.system(size: 24, weight: .semibold))
                Text(UserDefaultManager.shared.getUserDefaultsString(key: .userName).isEmptyString
                     ? "SpiceMonk"
                     : UserDefaultManager.shared.getUserDefaultsString(key: .userName))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.gray)

                Button("Logout") {
                    viewModel.logout()
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 150, height: 44)
                .background(Color(hex: "7B0513"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .navigationTitle("Home")
        }
        .toast(isPresenting: $viewModel.isShowToastView, duration: 1.5, offsetY: 10, alert: {
            AlertToast(displayMode: .banner(.pop), type: .regular, title: viewModel.toastMessage)
        }, onTap: nil, completion: nil)
    }
}

#Preview {
    HomeScreen()
}
