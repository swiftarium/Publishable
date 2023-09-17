@testable import Publishable
import XCTest

final class PublishableThreadSafetyTests: XCTestCase {
    struct TestModel {
        @Publishable var number: Int = 0
        @Publishable var string: String = ""
        @Publishable var array: [String] = []
        @Publishable var dict: [String: String] = [:]
    }

    class TestSubscriber {}

    var model: TestModel!

    override func setUp() {
        super.setUp()
        model = TestModel()
    }

    func testConcurrentValueChanges() {
        let iterations = 100000
        let expect = expectation(description: "Waiting for all value changes to complete")

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            model.number = iteration

            if iteration == iterations - 1 {
                expect.fulfill()
            }
        }

        waitForExpectations(timeout: 2)
        XCTAssertEqual(model.number, iterations - 1)
    }

    func testConcurrentSubscribesWithoutObject() {
        let iterations = 100000
        let expectIteration = expectation(description: "Waiting for iteration to complete")
        expectIteration.expectedFulfillmentCount = iterations

        let expect = expectation(description: "Waiting for all subscribes to complete")
        expect.expectedFulfillmentCount = iterations

        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            model.$number.subscribe { _ in
                expect.fulfill()
            }
            expectIteration.fulfill()
        }

        wait(for: [expectIteration])
        sleep(2)

        model.number = 1
        wait(for: [expect], timeout: 2.0)
    }

    func testConcurrentSubscribesWithObject() {
        let iterations = 1000

        let expectIteration = expectation(description: "Waiting for iteration to complete")
        expectIteration.expectedFulfillmentCount = iterations

        let expect = expectation(description: "Waiting for all subscribes to complete")
        expect.expectedFulfillmentCount = iterations

        let subscribers = (1 ... iterations).map { _ in TestSubscriber() }
        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            let subscriber = subscribers[iteration]
            model.$number.subscribe(by: subscriber) { sub, _ in
                XCTAssertIdentical(sub, subscriber)
                expect.fulfill()
            }
            expectIteration.fulfill()
        }

        wait(for: [expectIteration])
        sleep(2)

        model.number = 1
        wait(for: [expect], timeout: 2.0)
    }
    
    func testConcurrentUnsubscribesWithoutObject() {
        let iterations = 100000
        let expectIteration = expectation(description: "Waiting for iteration to complete")
        expectIteration.expectedFulfillmentCount = iterations

        let tokens = (1...iterations).map { _ in
            model.$number.subscribe { _ in
                XCTFail("Callback should not be called")
            }
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            let token = tokens[iteration]
            model.$number.unsubscribe(by: token)
            expectIteration.fulfill()
        }

        wait(for: [expectIteration])
        sleep(2)

        model.number = 1
        sleep(2)
    }
    
    func testConcurrentUnsubscribesWithObject() {
        let iterations = 100000
        let expectIteration = expectation(description: "Waiting for iteration to complete")
        expectIteration.expectedFulfillmentCount = iterations

        let subscribers = (1...iterations).map { _ in TestSubscriber() }
        subscribers.forEach { subscriber in
            model.$number.subscribe(by: subscriber) { _, _ in
                XCTFail("Callback should not be called")
            }
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            let subscriber = subscribers[iteration]
            model.$number.unsubscribe(by: subscriber)
            expectIteration.fulfill()
        }

        wait(for: [expectIteration])
        sleep(2)

        model.number = 1
        sleep(2)
    }

    func testConcurrentNotifications() {
        let iterations = 100000
        let expect = expectation(description: "Waiting for all notifications")
        expect.expectedFulfillmentCount = iterations

        model.$number.subscribe { _, _ in
            expect.fulfill()
        }

        DispatchQueue.concurrentPerform(iterations: iterations) { iteration in
            model.number = iteration + 1
        }

        waitForExpectations(timeout: 2)
    }
}
