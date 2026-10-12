"""Run with python3 Tests/check_razorpay_models.py (requires Swift)."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
models = (root / 'SpiceMonk/Screens/Orders/OrderModels.swift').read_text()
models = models[models.index('struct PaymentInitiateData:'):models.index('struct PaymentInitiateResponse:')]
helpers = (root / 'SpiceMonk/Core/Network/LenientDecoding.swift').read_text()
checks = r'''
let valid = #"{"order_id":42,"razorpay_order_id":"order_test","key_id":"rzp_test_public","amount":12900,"currency":"INR"}"#
func decode(_ value: String) throws -> PaymentInitiateData {
    try JSONDecoder().decode(PaymentInitiateData.self, from: Data(value.utf8))
}
let payment = try decode(valid)
assert(payment.orderId == 42 && payment.amount == 12900 && payment.razorpayKeyId == "rzp_test_public")
for invalid in [valid.replacingOccurrences(of: "12900", with: "0"),
                valid.replacingOccurrences(of: "12900", with: "12.5"),
                valid.replacingOccurrences(of: "order_test", with: ""),
                valid.replacingOccurrences(of: "INR", with: ""),
                #"{"order_id":42,"payment_session_id":"cashfree_session"}"#] {
    assert((try? decode(invalid)) == nil)
}
assert(RazorpayPaymentResult(data: [:]) == nil)
assert(RazorpayPaymentResult(data: ["razorpay_payment_id": "pay_test", "razorpay_order_id": "order_test", "razorpay_signature": "signature"]) != nil)
print("Razorpay model checks passed")
'''
with tempfile.TemporaryDirectory() as directory:
    source = Path(directory) / 'main.swift'
    source.write_text('import Foundation\n' + helpers + models + checks)
    subprocess.run(['swift', '-module-cache-path', directory + '/cache', str(source)], check=True)
