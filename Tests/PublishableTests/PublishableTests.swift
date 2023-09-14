@testable import Publishable
import XCTest

final class PublishableTests: XCTestCase {
    private struct TestModel {
        @Publishable var value: String
        @Publishable var count: Int = 0
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
        let model = TestModel(value: oldValue)

        let expectation = self.expectation(
            description: "subscribe"
        )
        expectation.expectedFulfillmentCount = 2

        model.$value.subscribe { changes in
            XCTAssertEqual(changes.old, oldValue)
            XCTAssertEqual(changes.new, newValue)
            expectation.fulfill()
        }

        model.$value.subscribe(by: self) { _, changes in
            XCTAssertEqual(changes.old, oldValue)
            XCTAssertEqual(changes.new, newValue)
            expectation.fulfill()
        }

        model.value = "New Value"
        waitForExpectations(timeout: 1.0)
    }

    func testMultipleSubscribes() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(value: oldValue)

        for i in 0 ..< 100 {
            let expectation = self.expectation(
                description: "multiple subscribes (\(i))"
            )
            expectation.expectedFulfillmentCount = 2

            model.$value.subscribe { changes in
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
                expectation.fulfill()
            }

            model.$value.subscribe(by: self) { _, changes in
                XCTAssertEqual(changes.old, oldValue)
                XCTAssertEqual(changes.new, newValue)
                expectation.fulfill()
            }
        }

        model.value = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testSubscribeWithImmediate() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(value: oldValue)

        let expectation = self.expectation(description: "subscribe with immediate")
        expectation.expectedFulfillmentCount = 4

        var immediate1 = true
        model.$value.subscribe(by: self, immediate: true) { _, changes in
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
        model.$value.subscribe(immediate: true) { changes in
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

        model.value = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testUnsubscribe() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(value: oldValue)

        let token = model.$value.subscribe { _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$value.subscribe(by: self) { _, _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$value.unsubscribe(token: token)
        model.$value.unsubscribe(by: self)

        model.value = newValue
        sleep(1)
    }

    func testWeakReferences() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(value: oldValue)

        var subscriber1: TestSubscriber? = TestSubscriber(name: "Subscriber 1")
        let subscriber2: TestSubscriber? = TestSubscriber(name: "Subscriber 2")
        var subscriber3: TestSubscriber? = TestSubscriber(name: "Subscriber 3")

        let expectation = self.expectation(
            description: "Callback should be called if object still alive"
        )

        model.$value.subscribe(by: subscriber1!) { _, _ in
            XCTFail("Callback should not be called after object is released")
        }
        model.$value.subscribe(by: subscriber2!) { subscriber, _ in
            XCTAssertIdentical(subscriber, subscriber2)
            expectation.fulfill()
        }
        model.$value.subscribe(by: subscriber3!) { _, _ in
            XCTFail("Callback should not be called after object is released")
        }

        subscriber1 = nil
        subscriber3 = nil

        model.value = newValue

        waitForExpectations(timeout: 1.0)
    }

    func testThreadSafety() {
        let oldValue = "Old Value"
        let newValue = "New Value"
        let model = TestModel(value: oldValue)

        let expectation = self.expectation(description: "Thread Safety")
        let dispatchGroup = DispatchGroup()

        var receivedValues: [String] = []

        model.$value.subscribe(by: self) { _, changes in
            receivedValues.append(changes.new)
        }

        model.$value.subscribe { changes in
            receivedValues.append(changes.new)
        }

        DispatchQueue.global(qos: .background).async(group: dispatchGroup) {
            for _ in 0 ..< 100 {
                model.value = newValue
            }
        }

        DispatchQueue.global(qos: .utility).async(group: dispatchGroup) {
            for _ in 0 ..< 100 {
                model.value = oldValue
            }
        }

        dispatchGroup.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)

        // Expect that 200 changes have been received
        XCTAssertEqual(receivedValues.count, 400)
    }
}
