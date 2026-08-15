//
//  HomeViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {

    @Published var isShowToastView = false
    @Published var toastMessage = ""

    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = HomeServiceManager()

    func logout() {
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.setRootView(view: LoginScreen())
    }
}
