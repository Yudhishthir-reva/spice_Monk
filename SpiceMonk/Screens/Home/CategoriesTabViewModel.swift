//
//  CategoriesTabViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

final class CategoriesTabViewModel: ObservableObject {

    @Published var categories: [CategoryItem] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isRefreshing = false
    @Published var loadError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published private(set) var hasMore = true

    private var page = 1
    private let perPage = 15
    private var activeSearch = ""
    private var fetchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var serviceManagable = HomeServiceManager()

    init() {
        $searchText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .removeDuplicates()
            .dropFirst()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] query in
                self?.searchChanged(query)
            }
            .store(in: &cancellables)
    }

    func loadIfNeeded() {
        guard categories.isEmpty, !isLoading else { return }
        loadFirstPage()
    }

    func loadFirstPage() {
        guard !isLoading else { return }
        page = 1
        hasMore = true
        isLoading = true
        loadError = nil
        fetch(page: 1, search: activeSearch, appending: false)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        page = 1
        hasMore = true
        fetch(page: 1, search: activeSearch, appending: false)
    }

    func loadMore() {
        guard hasMore, !isLoading, !isLoadingMore, !isRefreshing else { return }
        isLoadingMore = true
        fetch(page: page + 1, search: activeSearch, appending: true)
    }

    private func searchChanged(_ query: String) {
        activeSearch = query
        fetchCancellable?.cancel()
        isLoadingMore = false
        isRefreshing = false
        page = 1
        hasMore = true
        isLoading = true
        loadError = nil
        fetch(page: 1, search: query, appending: false)
    }

    private func fetch(page requestedPage: Int, search: String, appending: Bool) {
        fetchCancellable = serviceManagable
            .fetchAllCategories(page: requestedPage, perPage: perPage, search: search)
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
                } else if self.categories.isEmpty {
                    self.loadError = message
                } else {
                    self.toastMessage = message
                    self.isShowToastView = true
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                self.isLoadingMore = false
                self.isRefreshing = false

                var added = response.categories.count
                if appending {
                    let existing = Set(self.categories.map(\.id))
                    let fresh = response.categories.filter { !existing.contains($0.id) }
                    added = fresh.count
                    self.categories.append(contentsOf: fresh)
                } else {
                    self.categories = response.categories
                }

                // The cursor is ours, not the server's echo: a response without `current_page`
                // decodes as 1 and would pin every further request to page 2 forever.
                self.page = requestedPage
                self.hasMore = response.pagination.hasMore
                    && !response.categories.isEmpty
                    && (!appending || added > 0)
                self.loadError = nil
            }
    }
}
