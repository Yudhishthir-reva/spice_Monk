//
//  OrderServiceManager.swift
//  SpiceMonk
//

import Foundation
import Combine

class OrderServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func fetchOrders(page: Int, status: String) -> AnyPublisher<OrdersResponse, Error> {
        var params: [String: Any] = [
            "page": page,
            "per_page": 10
        ]
        if !status.isEmpty {
            params["status"] = status
        }
        return networkService.request(
            APIRouter.orders,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchOrderDetail(orderId: Int) -> AnyPublisher<OrderDetailResponse, Error> {
        return networkService.request(
            APIRouter.orderDetail(id: orderId),
            params: [String: Any](),
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func cancelOrder(orderId: Int, reason: String) -> AnyPublisher<StatusResponse, Error> {
        let params: [String: Any] = [
            "order_id": orderId,
            "reason": reason
        ]
        return networkService.request(
            APIRouter.orderCancel,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func placeOrder(addressId: Int, paymentType: String, notes: String, couponCode: String? = nil) -> AnyPublisher<OrderPlaceResponse, Error> {
        var params: [String: Any] = [
            "address_id": addressId,
            "payment_type": paymentType
        ]
        if !notes.isEmpty {
            params["notes"] = notes
        }
        if let couponCode, !couponCode.isEmpty {
            params["coupon_code"] = couponCode
        }
        return networkService.request(
            APIRouter.orderPlace,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func initiatePayment(orderId: Int) -> AnyPublisher<PaymentInitiateResponse, Error> {
        let params: [String: Any] = ["order_id": orderId]
        return networkService.request(
            APIRouter.paymentInitiate,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func verifyPayment(orderId: Int) -> AnyPublisher<PaymentVerifyResponse, Error> {
        let params: [String: Any] = ["order_id": orderId]
        return networkService.request(
            APIRouter.paymentVerify,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
