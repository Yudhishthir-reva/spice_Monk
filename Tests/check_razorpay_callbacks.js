// Run: node Tests/check_razorpay_callbacks.js
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../SpiceMonk/Screens/Cart/PaymentSimulationSheet.swift'), 'utf8');
const script = source.slice(source.indexOf('        try {\n            const options'), source.indexOf('        </script></body></html>'))
    .replace('\\(encoded)', Buffer.from('{}').toString('base64'));
function checkout() {
    let options, failure;
    const events = [];
    vm.runInNewContext(script, {
        atob: value => Buffer.from(value, 'base64').toString(),
        send: (type, data) => events.push({type, data}),
        Razorpay: function(value) {
            options = value;
            this.on = (_, callback) => { failure = callback; };
            this.open = () => {};
        }
    });
    return { events, options, fail: () => failure({error: {description: 'Payment declined'}}) };
}
let flow = checkout();
flow.fail();
flow.options.modal.ondismiss();
assert.deepEqual(flow.events.map(e => e.type), ['failure']);
assert.equal(flow.events[0].data.message, 'Payment declined');
flow = checkout();
flow.options.handler({razorpay_payment_id: 'pay_test'});
flow.options.modal.ondismiss();
flow.fail();
assert.deepEqual(flow.events.map(e => e.type), ['success']);
flow = checkout();
flow.options.modal.ondismiss();
assert.deepEqual(flow.events.map(e => e.type), ['cancel']);
console.log('Razorpay success, failure and cancellation callback checks passed');
