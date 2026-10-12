"""Run with python3 Tests/check_order_status.py."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
models = (root / 'SpiceMonk/Screens/Orders/OrderModels.swift').read_text()
models = models[models.index('struct OrderStatus:'):models.index('struct OrderExpectedDate:')]
helpers = (root / 'SpiceMonk/Core/Network/LenientDecoding.swift').read_text()
checks = r'''
let decoder = JSONDecoder()
for code in -1...4 {
    for value in [String(code), "\"\(code)\""] {
        let json = "{\"code\":\(value),\"label\":\"Status\",\"color\":\"#FF9800\"}"
        let status = try decoder.decode(OrderStatus.self, from: Data(json.utf8))
        assert(status.code == code)
        assert(status.showsDeliveryTimeline == (0...3).contains(code))
    }
}
let timeline = #"[{"label":"Order Placed","date":"30 Sep","completed":1},{"label":"Confirmed","date":null,"completed":true},{"label":"Shipped","date":"<null>","completed":"1"},{"label":"Delivered","date":null,"completed":0}]"#
let steps = try decoder.decode([OrderTimelineStep].self, from: Data(timeline.utf8))
assert(steps.map(\.completed) == [true, true, true, false])
assert(steps[0].date == "30 Sep" && steps[1].date == nil && steps[2].date == nil)
print("Order status and timeline checks passed")
'''
with tempfile.TemporaryDirectory() as directory:
    source = Path(directory) / 'main.swift'
    source.write_text('import Foundation\n' + helpers + models + checks)
    subprocess.run(['swift', '-module-cache-path', '/tmp/spicemonk-status-swift-cache', str(source)], check=True)
