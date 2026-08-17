//
//  HomeServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class HomeServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchHome() -> AnyPublisher<HomeResponse, Error> {
        networkService.request(
            APIRouter.home,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchWidgetProducts(widgetId: Int, page: Int, perPage: Int = 10) -> AnyPublisher<WidgetProductsResponse, Error> {
        networkService.request(
            APIRouter.widgetProducts,
            params: [
                "widget_id": widgetId,
                "page": page,
                "per_page": perPage
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchCategoryProducts(categoryId: Int, page: Int, perPage: Int = 10) -> AnyPublisher<CategoryProductsResponse, Error> {
        networkService.request(
            APIRouter.categoryProducts,
            params: [
                "category_id": categoryId,
                "page": page,
                "per_page": perPage
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchBrandProducts(brandId: Int, page: Int, perPage: Int = 10) -> AnyPublisher<BrandProductsResponse, Error> {
        networkService.request(
            APIRouter.brandProducts,
            params: [
                "brand_id": brandId,
                "page": page,
                "per_page": perPage
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchBannerProducts(bannerId: Int, page: Int, perPage: Int = 10) -> AnyPublisher<BannerProductsResponse, Error> {
        networkService.request(
            APIRouter.bannerProducts,
            params: [
                "banner_id": bannerId,
                "page": page,
                "per_page": perPage
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchProductDetail(productId: Int) -> AnyPublisher<ProductDetailResponse, Error> {
        networkService.request(
            APIRouter.productDetail,
            params: ["product_id": productId],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchRelatedProducts(productId: Int, page: Int, perPage: Int = 10) -> AnyPublisher<RelatedProductsResponse, Error> {
        networkService.request(
            APIRouter.relatedProducts,
            params: [
                "product_id": productId,
                "page": page,
                "per_page": perPage
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchProductSuggestions(query: String) -> AnyPublisher<SearchSuggestionsResponse, Error> {
        networkService.request(
            APIRouter.productSuggestions,
            params: ["query": query],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchSearchProducts(
        query: String = "",
        categoryId: Int = 0,
        brandId: Int = 0,
        productId: Int = 0,
        page: Int,
        perPage: Int = 10
    ) -> AnyPublisher<SearchProductsResponse, Error> {
        var params: [String: Any] = [
            "page": page,
            "per_page": perPage
        ]
        if !query.trim.isEmpty {
            params["query"] = query.trim
        }
        if categoryId > 0 {
            params["category_id"] = categoryId
        }
        if brandId > 0 {
            params["brand_id"] = brandId
        }
        if productId > 0 {
            params["product_id"] = productId
        }
        return networkService.request(
            APIRouter.productSearch,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
