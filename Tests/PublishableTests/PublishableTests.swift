@testable import Publishable
import XCTest

final class PublishableTests: XCTestCase {
    private struct TestModel {
        @Publishable var number: Int = 0
        @Publishable var string: String = ""
        @Publishable var array: [String] = []
        @Publishable var dict: [String: String] = [:]
    }

    private final class TestSubscriber {
        let name: String

        init(name: String) {
            self.name = name
        }
    }

    func testSubscribe() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        let expectation = self.expectation(
            description: "subscribe"
        )
        expectation.expectedFulfillmentCount = 2

        model.$string.subscribe { changes in
            XCTAssertEqual(changes.old, oldValue)
            XCTAssertEqual(changes.new, newValue)
            expectation.fulfill()
        }

        model.$string.subscribe(by: self) { _, changes in
            XCTAssertEqual(changes.old, oldValue)
            XCTAssertEqual(changes.new, newValue)
            expectation.fulfill()
        }

        model.string = "New Value"
        waitForExpectations(timeout: 1.0)
    }

    func testMultipleSubscribes() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        for i in 0 ..< 100 {
            let expectation = self.expectation(
                description: "multiple subscribes (\(i))"
            )
            expectation.expectedFulfillmentCount = 2

            model.$string.subscribe { changes in
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
                expectation.fulfill()
            }

            model.$string.subscribe(by: self) { _, changes in
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
                expectation.fulfill()
            }
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testSubscribeWithImmediate() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        let expectation = self.expectation(description: "subscribe with immediate")
        expectation.expectedFulfillmentCount = 4

        var immediate1 = true
        model.$string.subscribe(by: self, immediate: true) { _, changes in
            if immediate1 {
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, oldValue)
                immediate1 = false
            } else {
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
            }

            expectation.fulfill()
        }

        var immediate2 = true
        model.$string.subscribe(immediate: true) { changes in
            if immediate2 {
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, oldValue)
                immediate2 = false
            } else {
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
            }

            expectation.fulfill()
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testUnsubscribe() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        let token = model.$string.subscribe { _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$string.subscribe(by: self) { _, _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$string.unsubscribe(by: token)
        model.$string.unsubscribe(by: self)

        model.string = newValue
        sleep(1)
    }

    func testUnsubscribeOnlyWithObject() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        let expectation = self.expectation(
            description: "Callback should be called"
        )

        model.$string.subscribe { payload in
            XCTAssertEqual(payload.old, oldValue)
            XCTAssertEqual(payload.new, newValue)
            expectation.fulfill()
        }

        model.$string.subscribe(by: self) { _, _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$string.unsubscribe(by: self)

        model.string = newValue
        sleep(1)
        waitForExpectations(timeout: 1.0)
    }

    func testUnsubscribeOnlyWithoutObject() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        let expectation = self.expectation(
            description: "Callback should be called"
        )

        let token = model.$string.subscribe { _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$string.subscribe(by: self) { _, payload in
            XCTAssertEqual(payload.old, oldValue)
            XCTAssertEqual(payload.new, newValue)
            expectation.fulfill()
        }

        model.$string.unsubscribe(by: token)

        model.string = newValue
        sleep(1)
        waitForExpectations(timeout: 1.0)
    }

    func testMultipleUnsubscribes() {
        let model = TestModel(string: "Initial")

        model.$string.subscribe(by: self) { _, _ in }
        let token = model.$string.subscribe { _ in }

        model.$string.unsubscribe(by: self)
        model.$string.unsubscribe(by: token)

        // Double unsubscribe shouldn't crash or produce any side effects
        model.$string.unsubscribe(by: self)
        model.$string.unsubscribe(by: token)
    }

    func testComplexPropertyTypes() {
        let model = TestModel()

        let expectation = self.expectation(description: "complex property type")
        expectation.expectedFulfillmentCount = 2

        model.$array.subscribe { changes in
            XCTAssertEqual(changes.new, ["item"])
            expectation.fulfill()
        }

        model.$dict.subscribe { changes in
            XCTAssertEqual(changes.new, ["key": "value"])
            expectation.fulfill()
        }

        model.array.append("item")
        model.dict.updateValue("value", forKey: "key")
        waitForExpectations(timeout: 1.0)
    }

    func testValueNotChanged() {
        let initial = "Not Changed"
        let model = TestModel(string: initial)

        model.$string.subscribe { _ in
            XCTFail("Callback should be not called without changing value")
        }

        model.$string.subscribe(by: self) { _, _ in
            XCTFail("Callback should be not called without changing value")
        }

        model.string = initial
        sleep(1)
    }

    func testWeakReferences() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(string: oldValue)

        var subscriber1: TestSubscriber? = TestSubscriber(name: "Subscriber 1")
        let subscriber2: TestSubscriber? = TestSubscriber(name: "Subscriber 2")
        var subscriber3: TestSubscriber? = TestSubscriber(name: "Subscriber 3")

        let expectation = self.expectation(
            description: "Callback should be called if object still alive"
        )

        model.$string.subscribe(by: subscriber1) { _, _ in
            XCTFail("Callback should not be called after object is released")
        }
        model.$string.subscribe(by: subscriber2) { subscriber, _ in
            XCTAssertIdentical(subscriber, subscriber2)
            expectation.fulfill()
        }
        model.$string.subscribe(by: subscriber3) { _, _ in
            XCTFail("Callback should not be called after object is released")
        }

        subscriber1 = nil
        subscriber3 = nil

        model.string = newValue

        waitForExpectations(timeout: 1.0)
    }
}
