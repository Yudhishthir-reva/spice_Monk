//
//  CartServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

enum CartCouponQuery: Equatable {
    /// No `coupon_id` query param.
    case `default`
    /// `GET customer/cart?coupon_id=` — clears coupon on server.
    case cleared
    /// `GET customer/cart?coupon_id={id}` — cart totals with coupon applied.
    case couponId(Int)
}

class CartServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchCart(couponQuery: CartCouponQuery = .default) -> AnyPublisher<CartResponse, Error> {
        var params: [String: Any] = [:]
        switch couponQuery {
        case .default:
            break
        case .cleared:
            params["coupon_id"] = ""
        case .couponId(let id):
            params["coupon_id"] = id
        }
        return networkService.request(
            APIRouter.cart,
            params: params,
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

    /// Guest GET `customer/guest/cart` — same priced payload as logged-in cart (`data`/`summary`/`grand_total`).
    func fetchGuestCart() -> AnyPublisher<CartResponse, Error> {
        networkService.request(
            APIRouter.guestCart,
            params: guestTokenParams(),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    /// Guest POST `customer/guest/cart/add` — slim `{ cart: [...] }` ack, then refresh via `fetchGuestCart()`.
    func addGuestCart(productId: Int, variantId: Int, qty: Int) -> AnyPublisher<GuestCartAddResponse, Error> {
        var params = guestTokenParams()
        params["product_id"] = productId
        params["variant_id"] = variantId
        params["qty"] = qty
        return networkService.request(
            APIRouter.guestCartAdd,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    /// Guest POST `customer/guest/cart/update` — `{ status, message }` only (then refresh cart).
    func updateGuestCart(productId: Int, variantId: Int, qty: Int) -> AnyPublisher<StatusResponse, Error> {
        var params = guestTokenParams()
        params["product_id"] = productId
        params["variant_id"] = variantId
        params["qty"] = qty
        return networkService.request(
            APIRouter.guestCartUpdate,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    /// Guest POST `customer/guest/cart/remove` — `{ status, message }`.
    func removeGuestCart(productId: Int, variantId: Int) -> AnyPublisher<StatusResponse, Error> {
        var params = guestTokenParams()
        params["product_id"] = productId
        params["variant_id"] = variantId
        return networkService.request(
            APIRouter.guestCartRemove,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    /// Guest POST `customer/guest/cart/clear` — clears entire guest cart.
    func clearGuestCart() -> AnyPublisher<StatusResponse, Error> {
        networkService.request(
            APIRouter.guestCartClear,
            params: guestTokenParams(),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    private func guestTokenParams() -> [String: Any] {
        let token = UserDefaultManager.shared.guestToken
        return token.isEmptyString ? [:] : ["guest_token": token]
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

    func applyCoupon(code: String) -> AnyPublisher<ApplyCouponResponse, Error> {
        networkService.request(
            APIRouter.couponApply,
            params: ["code": code],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func validateCoupon(couponId: Int) -> AnyPublisher<CouponValidateResponse, Error> {
        networkService.request(
            APIRouter.couponValidate,
            params: ["coupon_id": couponId],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
