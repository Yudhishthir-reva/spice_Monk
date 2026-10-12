# Razorpay backend contract

The app follows the supplied `postman_razorpay.json` contract on the existing authenticated payment endpoints. Backend implementation is outside this repository. Cashfree checkout is compiled out in PaymentSimulationSheet.swift.

`POST customer/payment/initiate` accepts the internal numeric `order_id`. Create a Razorpay order server-side using the authoritative order total. Return:

```json
{"status":true,"data":{"order_id":42,"razorpay_order_id":"order_example","key_id":"rzp_test_example","amount":12900,"currency":"INR"}}
```

`amount` must be an integer in paise, not rupees. The public key must belong to the same Razorpay account/environment as the created order. Never include the secret key in the app or response.

`POST customer/payment/verify` accepts `order_id` and after checkout success `razorpay_order_id`, `razorpay_payment_id`, `razorpay_signature`. Verify the signature using the server-stored Razorpay order ID and secret, check ownership, amount and currency, and confirm captured payment server-side before returning `is_paid: true`. Do not trust the supplied gateway order ID as the source of truth. All three checkout fields are required; Verify stays disabled until a success callback is available. Keep verification idempotent and reconcile late captures through webhooks.

```json
{"status":true,"data":{"order_id":42,"payment_status":"paid","is_paid":true,"order_amount":129.00}}
```

On verification/network errors after checkout success the app retains the result for Verify retries and prevents cancellation of a potentially paid order. Cancellation before success uses the existing unpaid-order/cart restoration flow; the backend must reject cancellation of paid orders and reconcile payment/cancel races.

Reference: https://razorpay.com/docs/server-integration/python/test-app/

Validation: `python3 Tests/check_razorpay_models.py`. Before release, exercise Razorpay test-mode success, failure/retry, dismissal, verification timeout/retry, and supported payment methods on a real iPhone. This integration uses the existing WKWebView checkout architecture; native app-switch payment methods need device validation.
