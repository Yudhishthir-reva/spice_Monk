//
//  SearchViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class SearchViewModel: ObservableObject {

    static let minQueryLength = 3

    @Published var query = ""
    @Published var suggestions: [SearchSuggestion] = []
    @Published var isSuggesting = false
    @Published var suggestionError: String?
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published var resultsDestination: SearchResultsDestination?

    private var fetchCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = HomeServiceManager()

    var trimmedQuery: String { query.trim }

    init() {
        $query
            .map(\.trim)
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: RunLoop.main)
            .sink { [weak self] trimmed in
                self?.fetchIfNeeded(trimmed)
            }
            .store(in: &cancellables)
    }

    /// Letters, digits and spaces only — same filter Android applies before the request.
    func updateQuery(_ raw: String, immediate: Bool = false) {
        let sanitized = String(raw.filter { $0.isLetter || $0.isNumber || $0.isWhitespace })
        if sanitized != query {
            query = sanitized
        }
        let length = sanitized.trim.count
        if length < Self.minQueryLength {
            fetchCancellable?.cancel()
            suggestions = []
            isSuggesting = false
            suggestionError = nil
        } else {
            isSuggesting = true
            suggestionError = nil
            if immediate {
                fetchIfNeeded(sanitized.trim)
            }
        }
    }

    func clear() {
        fetchCancellable?.cancel()
        query = ""
        suggestions = []
        isSuggesting = false
        suggestionError = nil
    }

    func submit() {
        openResults(query: trimmedQuery)
    }

    func openResults(query: String) {
        let q = query.trim
        guard !q.isEmpty else {
            toastMessage = "Please type or speak something to search"
            isShowToastView = true
            return
        }
        resultsDestination = SearchResultsDestination(
            query: q,
            title: "Results for “\(q)”"
        )
    }

    private func fetchIfNeeded(_ trimmed: String) {
        guard trimmed.count >= Self.minQueryLength else { return }
        fetchCancellable?.cancel()
        isSuggesting = true
        suggestionError = nil

        fetchCancellable = serviceManagable.fetchProductSuggestions(query: trimmed)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSuggesting = false
                if case .failure(let error) = completion {
                    guard self.trimmedQuery == trimmed else { return }
                    self.suggestions = []
                    self.suggestionError = (error as? RequestError)?.errorString
                        ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self, self.trimmedQuery == trimmed else { return }
                self.isSuggesting = false
                self.suggestions = response.suggestions.filter { $0.entityId > 0 && !$0.name.isEmptyString }
                self.suggestionError = nil
            }
    }
}

struct SearchResultsDestination: Hashable, Identifiable {
    let query: String
    var categoryId: Int = 0
    var brandId: Int = 0
    var productId: Int = 0
    let title: String

    var id: String { "\(query)|\(categoryId)|\(brandId)|\(productId)" }
}
