//
//  WidgetProductsViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

/// Widget "View all", brand chips, banner slides, and free-text search share one paged grid.
/// Category chips use a different screen because they also carry a sibling rail.
enum PagedCatalogSource {
    case widget(id: Int)
    case brand(id: Int)
    case banner(id: Int)
    case search(query: String, categoryId: Int, brandId: Int, productId: Int)
}

class WidgetProductsViewModel: ObservableObject {

    let source: PagedCatalogSource

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
    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = HomeServiceManager()

    init(source: PagedCatalogSource, title: String) {
        self.source = source
        self.title = title
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

    private func fetch(page requestedPage: Int, appending: Bool) {
        pagePublisher(page: requestedPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
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
            } receiveValue: { [weak self] page in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                self.isRefreshing = false

                if let apiTitle = page.title, !apiTitle.isEmptyString {
                    self.title = apiTitle
                }

                if appending {
                    let existing = Set(self.products.map(\.id))
                    self.products.append(contentsOf: page.products.filter { !existing.contains($0.id) })
                } else {
                    self.products = page.products
                }

                self.page = page.pagination.currentPage
                self.hasMore = page.pagination.hasMore && !page.products.isEmpty
                self.loadError = nil
            }
            .store(in: &cancellables)
    }

    private func pagePublisher(page: Int) -> AnyPublisher<(title: String?, products: [ProductItem], pagination: PageInfo), Error> {
        switch source {
        case .widget(let id):
            return serviceManagable.fetchWidgetProducts(widgetId: id, page: page, perPage: perPage)
                .map { ($0.widgetTitle, $0.products, $0.pagination) }
                .eraseToAnyPublisher()
        case .brand(let id):
            return serviceManagable.fetchBrandProducts(brandId: id, page: page, perPage: perPage)
                .map { ($0.brandName, $0.products, $0.pagination) }
                .eraseToAnyPublisher()
        case .banner(let id):
            return serviceManagable.fetchBannerProducts(bannerId: id, page: page, perPage: perPage)
                .map { (nil, $0.products, $0.pagination) }
                .eraseToAnyPublisher()
        case .search(let query, let categoryId, let brandId, let productId):
            return serviceManagable.fetchSearchProducts(
                query: query,
                categoryId: categoryId,
                brandId: brandId,
                productId: productId,
                page: page,
                perPage: perPage
            )
            .map { (nil, $0.products, $0.pagination) }
            .eraseToAnyPublisher()
        }
    }
}
