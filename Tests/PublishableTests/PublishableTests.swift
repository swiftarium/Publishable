@testable import Publishable
import XCTest

private struct Model {
    @Publishable var value: String
}

private final class Subscriber {
    let name: String

    init(name: String) {
        self.name = name
    }
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
    
    func testWeakRefRelease() {
        let model = Model(value: "OldValue")
        
        var subscriber1: Subscriber? = Subscriber(name: "Subscriber 1")
        let subscriber2: Subscriber? = Subscriber(name: "Subscriber 2")
        var subscriber3: Subscriber? = Subscriber(name: "Subscriber 3")
        
        var subscribers: [String] = []
        
        model.$value.subscribe(by: subscriber1!) { subscribers.append($0.subscriber.name) }
        model.$value.subscribe(by: subscriber2!) { subscribers.append($0.subscriber.name) }
        model.$value.subscribe(by: subscriber3!) { subscribers.append($0.subscriber.name) }
        
        subscriber1 = nil
        subscriber3 = nil
        
        model.value = "NewValue"
        
        XCTAssertEqual(subscribers, ["Subscriber 2"])
    }
}
