@testable import Publishable
import XCTest

private struct Model {
    @Publishable var value: String
}

private struct A {
    var a: String
}

final class PublishableTests: XCTestCase {
    func testValueChangeNotifiesSubscriber() {
        let oldValue = "OldValue"
        let newValue = "NewValue"

        var receivedOldValue: String?
        var receivedNewValue: String?

        let model = Model(value: oldValue)

        model.$value.subscribe(by: self) { _, changes in
            receivedOldValue = changes.old
            receivedNewValue = changes.new
        }

        model.value = newValue

        XCTAssertEqual(receivedOldValue, oldValue)
        XCTAssertEqual(receivedNewValue, newValue)
    }

    func testImmediateSubscription() {
        let oldValue = "Value"
        let model = Model(value: oldValue)

        var receivedValue: String?

        model.$value.subscribe(by: self, immediate: true) { _, changes in
            receivedValue = changes.new
        }

        XCTAssertEqual(receivedValue, oldValue)
    }

    func testUnsubscribePreventsNotification() {
        let oldValue = "OldValue"
        let newValue = "NewValue"
        let model = Model(value: oldValue)

        var didReceiveChange = false

        model.$value.subscribe(by: self) { _, _ in
            didReceiveChange = true
        }

        model.$value.unsubscribe(by: self)

        model.value = newValue

        XCTAssertFalse(didReceiveChange)
    }
}
