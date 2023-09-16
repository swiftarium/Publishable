@testable import Publishable
import XCTest

final class PublishableThreadSafetyTests: XCTestCase {
    struct TestModel {
        @Publishable var number: Int = 0
        @Publishable var string: String = ""
        @Publishable var array: [String] = []
        @Publishable var dict: [String: String] = [:]
    }

    class TestSubscriber {
        let name: String

        init(name: String) {
            self.name = name
        }
    }

    var model: TestModel!
    var expect: XCTestExpectation!

    override func setUp() {
        super.setUp()
        model = TestModel()
    }

    func testConcurrentValueChanges() {
        let iterations = 100000
        expect = expectation(description: "Waiting for all value changes to complete")

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            model.number = iteration

            if iteration == iterations - 1 {
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(model.number, iterations - 1)
    }

    func testConcurrentSubscriptions() {
        let iterations = 100000
        expect = expectation(description: "Waiting for all subscriptions to complete")

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            model.$number.subscribe { _ in }

            if model.$number.subscriptions.count == iterations {
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(model.$number.subscriptions.count, iterations)
    }

    func testConcurrentNotifications() {
        let iterations = 100000
        expect = expectation(description: "Waiting for all notifications")
        expect.expectedFulfillmentCount = iterations

        model.$number.subscribe { _, _ in
            self.expect.fulfill()
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            model.number = iteration + 1
        }

        waitForExpectations(timeout: 2)
    }
}
