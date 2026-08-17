//
//  CategoryProductsViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class CategoryProductsViewModel: ObservableObject {

    let siblings: [CategoryItem]

    @Published var selectedId: Int
    @Published var title: String
    @Published var products: [ProductItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published private(set) var hasMore = true

    private var page = 1
    private let perPage = 10
    private var fetchCancellable: AnyCancellable?
    var serviceManagable = HomeServiceManager()

    var showsRail: Bool { siblings.count > 1 }

    init(categoryId: Int, title: String, siblings: [CategoryItem]) {
        self.selectedId = categoryId
        self.title = title
        self.siblings = siblings
    }

    func loadFirstPage() {
        guard !isLoading else { return }
        page = 1
        hasMore = true
        isLoading = true
        loadError = nil
        fetch(page: 1, appending: false)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        page = 1
        hasMore = true
        fetch(page: 1, appending: false)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore, !isRefreshing else { return }
        isLoadingMore = true
        fetch(page: page + 1, appending: true)
    }

    func select(_ category: CategoryItem) {
        guard category.id != selectedId else { return }
        fetchCancellable?.cancel()
        isLoading = false
        isLoadingMore = false
        isRefreshing = false
        selectedId = category.id
        title = category.name
        products = []
        loadFirstPage()
    }

    private func fetch(page requestedPage: Int, appending: Bool) {
        let categoryId = selectedId
        fetchCancellable = serviceManagable
            .fetchCategoryProducts(categoryId: categoryId, page: requestedPage, perPage: perPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self, self.selectedId == categoryId else { return }
                self.isLoading = false
                self.isLoadingMore = false
                self.isRefreshing = false

                guard case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                if appending {
                    self.toastMessage = message
                    self.isShowToastView = true
                } else if self.products.isEmpty {
                    self.loadError = message
                } else {
                    self.toastMessage = message
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] response in
                guard let self, self.selectedId == categoryId else { return }
                self.isLoading = false
                self.isLoadingMore = false
                self.isRefreshing = false

                if let apiTitle = response.categoryName, !apiTitle.isEmptyString {
                    self.title = apiTitle
                }

                if appending {
                    let existing = Set(self.products.map(\.id))
                    self.products.append(contentsOf: response.products.filter { !existing.contains($0.id) })
                } else {
                    self.products = response.products
                }

                self.page = response.pagination.currentPage
                self.hasMore = response.pagination.hasMore && !response.products.isEmpty
                self.loadError = nil
            }
    }
}
