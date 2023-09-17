@testable import Publishable
import XCTest

final class PublishableTests: XCTestCase {
    struct TestModel {
        @Publishable var number: Int = 0
        @Publishable var string: String = ""
        @Publishable var array: [String] = []
        @Publishable var dict: [String: String] = [:]
    }

    final class TestSubscriber {
        let name: String

        init(name: String = "") {
            self.name = name
        }
    }

    var model: TestModel!
    let oldValue = "Old Value"
    let newValue = "New Value"

    func testSubscribeWithToken() {
        model = TestModel(string: oldValue)

        let expect = expectation(description: "subscribe")

        model.$string.subscribe { changes in
            XCTAssertEqual(changes.old, self.oldValue)
            XCTAssertEqual(changes.new, self.newValue)
            expect.fulfill()
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testSubscribeWithSubscriber() {
        model = TestModel(string: oldValue)

        let expect = expectation(description: "subscribe with subscriber")
        expect.expectedFulfillmentCount = 1

        model.$string.subscribe(by: self) { subscriber, changes in
            XCTAssertEqual(changes.old, subscriber.oldValue)
            XCTAssertEqual(changes.new, subscriber.newValue)
            expect.fulfill()
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testMultipleSubscribes() {
        model = TestModel(string: oldValue)

        let iterations = 1000
        let expect = expectation(description: "multiple subscribes")
        expect.expectedFulfillmentCount = iterations

        for _ in 0 ..< iterations {
            model.$string.subscribe { changes in
                XCTAssertEqual(changes.old, self.oldValue)
                XCTAssertEqual(changes.new, self.newValue)
                expect.fulfill()
            }
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }
    
    func testMultipleSubscribesBySubscriber() {
        model = TestModel(string: oldValue)

        let iterations = 1000
        let expect = expectation(description: "multiple subscribes")
        expect.expectedFulfillmentCount = iterations

        let subscribers = (1...1000).map { _ in TestSubscriber() }
        subscribers.forEach { subscriber in
            model.$string.subscribe(by: subscriber) { sub, changes in
                XCTAssertIdentical(sub, subscriber)
                XCTAssertEqual(changes.old, self.oldValue)
                XCTAssertEqual(changes.new, self.newValue)
                expect.fulfill()
            }
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testSubscribeWithImmediate() {
        model = TestModel(string: oldValue)

        let expect = expectation(description: "subscribe with immediate")
        expect.expectedFulfillmentCount = 4

        var immediate1 = true
        model.$string.subscribe(by: self, immediate: true) { sub, changes in
            if immediate1 {
                XCTAssertEqual(changes.old, sub.oldValue)
                XCTAssertEqual(changes.new, sub.oldValue)
                immediate1 = false
            } else {
                XCTAssertEqual(changes.old, sub.oldValue)
                XCTAssertEqual(changes.new, sub.newValue)
            }

            expect.fulfill()
        }

        var immediate2 = true
        model.$string.subscribe(immediate: true) { changes in
            if immediate2 {
                XCTAssertEqual(changes.old, self.oldValue)
                XCTAssertEqual(changes.new, self.oldValue)
                immediate2 = false
            } else {
                XCTAssertEqual(changes.old, self.oldValue)
                XCTAssertEqual(changes.new, self.newValue)
            }

            expect.fulfill()
        }

        model.string = newValue
        waitForExpectations(timeout: 1.0)
    }

    func testUnsubscribe() {
        model = TestModel(string: oldValue)

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
        model = TestModel(string: oldValue)

        let expect = expectation(description: "Callback should be called")

        model.$string.subscribe { payload in
            XCTAssertEqual(payload.old, self.oldValue)
            XCTAssertEqual(payload.new, self.newValue)
            expect.fulfill()
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
        model = TestModel(string: oldValue)

        let expect = expectation(description: "Callback should be called")

        let token = model.$string.subscribe { _ in
            XCTFail("Callback should not be called after unsubscribe")
        }

        model.$string.subscribe(by: self) { sub, payload in
            XCTAssertEqual(payload.old, sub.oldValue)
            XCTAssertEqual(payload.new, sub.newValue)
            expect.fulfill()
        }

        model.$string.unsubscribe(by: token)

        model.string = newValue
        sleep(1)
        waitForExpectations(timeout: 1.0)
    }

    func testMultipleUnsubscribes() {
        model = TestModel()

        model.$string.subscribe(by: self) { _, _ in }
        let token = model.$string.subscribe { _ in }

        model.$string.unsubscribe(by: self)
        model.$string.unsubscribe(by: token)

        // Double unsubscribe shouldn't crash or produce any side effects
        model.$string.unsubscribe(by: self)
        model.$string.unsubscribe(by: token)
    }

    func testComplexPropertyTypes() {
        model = TestModel()

        let expect = expectation(description: "complex property type")
        expect.expectedFulfillmentCount = 2

        model.$array.subscribe { changes in
            XCTAssertEqual(changes.new, ["item"])
            expect.fulfill()
        }

        model.$dict.subscribe { changes in
            XCTAssertEqual(changes.new, ["key": "value"])
            expect.fulfill()
        }

        model.array.append("item")
        model.dict.updateValue("value", forKey: "key")
        waitForExpectations(timeout: 1.0)
    }

    func testValueNotChanged() {
        model = TestModel(string: oldValue)

        model.$string.subscribe { _ in
            XCTFail("Callback should be not called without changing value")
        }

        model.$string.subscribe(by: self) { _, _ in
            XCTFail("Callback should be not called without changing value")
        }

        model.string = oldValue
        sleep(1)
    }

    func testWeakReferences() {
        model = TestModel(string: oldValue)

        var subscriber1: TestSubscriber? = TestSubscriber(name: "Subscriber 1")
        let subscriber2: TestSubscriber? = TestSubscriber(name: "Subscriber 2")
        var subscriber3: TestSubscriber? = TestSubscriber(name: "Subscriber 3")

        let expect = expectation(
            description: "Callback should be called if object still alive"
        )

        model.$string.subscribe(by: subscriber1) { _, _ in
            XCTFail("Callback should not be called after object is released")
        }
        model.$string.subscribe(by: subscriber2) { subscriber, _ in
            XCTAssertIdentical(subscriber, subscriber2)
            expect.fulfill()
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
