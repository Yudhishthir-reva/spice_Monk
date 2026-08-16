//
//  HomeViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class HomeViewModel: ObservableObject {

    @Published var widgets: [HomeWidget] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    /// Only set when there is nothing to show. A failed refresh over existing content surfaces as a
    /// toast instead, so a flaky network never wipes a feed the user is already reading.
    @Published var loadError: String?
    @Published var isShowToastView = false
    @Published var toastMessage = ""

    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = HomeServiceManager()

    var hasContent: Bool { !widgets.isEmpty }

    func loadHome() {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        fetch()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        fetch()
    }

    private func fetch() {
        serviceManagable.fetchHome()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false

                guard case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription

                if self.hasContent {
                    self.toastMessage = message
                    self.isShowToastView = true
                } else {
                    self.loadError = message
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                self.widgets = response.widgets
                self.loadError = self.hasContent ? nil : (response.message ?? "Nothing to show right now.")
            }
            .store(in: &cancellables)
    }

    func logout() {
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.setRootView(view: LoginScreen())
    }
}
