//
//  CartServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class CartServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchCart() -> AnyPublisher<CartResponse, Error> {
        networkService.request(
            APIRouter.cart,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func addToCart(productId: Int, variantId: Int, qty: Int = 1) -> AnyPublisher<CartAddResponse, Error> {
        networkService.request(
            APIRouter.cartAdd,
            params: [
                "product_id": productId,
                "variant_id": variantId,
                "qty": qty
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func removeFromCart(cartId: Int) -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.cartRemove,
            params: ["cart_id": cartId],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func clearCart() -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.cartClear,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func updateCart(cartId: Int, qty: Int) -> AnyPublisher<CartAddResponse, Error> {
        networkService.request(
            APIRouter.cartUpdate,
            params: [
                "cart_id": cartId,
                "qty": qty
            ],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchCoupons() -> AnyPublisher<CouponsResponse, Error> {
        networkService.request(
            APIRouter.coupons,
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
