//
//  ProductDetailViewModel.swift
//  SpiceMonk
//

import SwiftUI
import Combine

class ProductDetailViewModel: ObservableObject {

    let productId: Int
    let seedName: String
    let seedImageUrl: String?

    @Published var product: ProductDetail?
    @Published var selectedVariantIndex = 0
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var notFound = false
    @Published var toastMessage = ""
    @Published var isShowToastView = false
    @Published var related: [ProductItem] = []
    @Published var isLoadingMoreRelated = false

    private var relatedPage = 1
    private var relatedHasMore = true
    private var isLoadingRelated = false
    private let relatedPerPage = 10
    private var cancellables = Set<AnyCancellable>()
    var serviceManagable = HomeServiceManager()

    var selectedVariant: ProductDetailVariant? {
        product?.variants[safe: selectedVariantIndex]
    }

    var heroImages: [String] {
        if let images = product?.images, !images.isEmpty { return images }
        if let seed = seedImageUrl, !seed.isEmptyString { return [seed] }
        return []
    }

    var displayName: String {
        if let name = product?.name, !name.isEmptyString { return name }
        return seedName
    }

    init(productId: Int, seedName: String, seedImageUrl: String?) {
        self.productId = productId
        self.seedName = seedName
        self.seedImageUrl = seedImageUrl
    }

    func load() {
        guard !isLoading else { return }
        guard productId > 0 else {
            notFound = true
            isLoading = false
            return
        }
        isLoading = true
        loadError = nil
        notFound = false

        serviceManagable.fetchProductDetail(productId: productId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                if message.localizedCaseInsensitiveContains("not found") {
                    self.notFound = true
                } else {
                    self.loadError = message
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                guard let detail = response.product, detail.id > 0 else {
                    self.notFound = true
                    return
                }
                self.product = detail
                self.selectedVariantIndex = detail.defaultVariantIndex
                self.loadError = nil
                self.notFound = false
                self.loadRelated(reset: true)
            }
            .store(in: &cancellables)
    }

    func selectVariant(at index: Int) {
        guard let count = product?.variants.count, (0..<count).contains(index) else { return }
        selectedVariantIndex = index
    }

    func addToCart() {
        guard let variant = selectedVariant, variant.id > 0 else {
            toastMessage = "Unable to add this product."
            isShowToastView = true
            return
        }
        let inCart = CartStore.shared.quantity(productId: productId, variantId: variant.id) > 0
        guard variant.inStock || inCart else {
            toastMessage = "Product is out of stock."
            isShowToastView = true
            return
        }

        CartStore.shared.incrementOrAdd(
            productId: productId,
            variantId: variant.id,
            availableQty: variant.availableQty,
            maxOrderQty: CartStore.shared.line(productId: productId, variantId: variant.id)?.maxOrderQty
        )
    }

    func decrementCart() {
        guard let variant = selectedVariant, variant.id > 0 else { return }
        CartStore.shared.decrement(productId: productId, variantId: variant.id)
    }

    func loadMoreRelated() {
        guard relatedHasMore, !isLoadingRelated, !isLoadingMoreRelated else { return }
        isLoadingMoreRelated = true
        loadRelated(reset: false)
    }

    private func loadRelated(reset: Bool) {
        if reset {
            relatedPage = 1
            relatedHasMore = true
            isLoadingRelated = true
        }
        let page = reset ? 1 : relatedPage + 1
        serviceManagable.fetchRelatedProducts(productId: productId, page: page, perPage: relatedPerPage)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingRelated = false
                self.isLoadingMoreRelated = false
                if case .failure = completion, reset, self.related.isEmpty {
                    self.relatedHasMore = false
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingRelated = false
                self.isLoadingMoreRelated = false
                let incoming = response.products.filter { $0.id != self.productId && $0.id > 0 }
                if reset {
                    self.related = incoming
                } else {
                    let existing = Set(self.related.map(\.id))
                    self.related.append(contentsOf: incoming.filter { !existing.contains($0.id) })
                }
                self.relatedPage = response.pagination.currentPage
                self.relatedHasMore = response.pagination.hasMore && !incoming.isEmpty
            }
            .store(in: &cancellables)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
