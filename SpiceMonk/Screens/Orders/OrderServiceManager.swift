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

    func placeOrder(addressId: Int, paymentType: String, notes: String, couponId: Int? = nil) -> AnyPublisher<OrderPlaceResponse, Error> {
        var params: [String: Any] = [
            "address_id": addressId,
            "payment_type": paymentType
        ]
        if !notes.isEmpty {
            params["notes"] = notes
        }
        if let couponId, couponId > 0 {
            params["coupon_id"] = couponId
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

    func verifyPayment(orderId: Int, result: RazorpayPaymentResult) -> AnyPublisher<PaymentVerifyResponse, Error> {
        var params: [String: Any] = ["order_id": orderId]
        params["razorpay_order_id"] = result.orderId
        params["razorpay_payment_id"] = result.paymentId
        params["razorpay_signature"] = result.signature
        return networkService.request(
            APIRouter.paymentVerify,
            params: params,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
