@propertyWrapper
final class Publishable<Property> {
    typealias Changes = (old: Property, new: Property)
    typealias Callback<Subscriber: AnyObject> = ((subscriber: Subscriber, changes: Changes)) -> Void

    private struct WeakRef<T: AnyObject> {
        weak var value: T?
        init(_ value: T?) {
            self.value = value
        }
    }

    private struct Subscription<Subscriber: AnyObject> {
        let callback: Callback<Subscriber>
        let subscriber: WeakRef<Subscriber>
    }

    private var value: Property
    private var subscriptions: [Subscription<AnyObject>] = []

    var wrappedValue: Property {
        get { value }
        set {
            let oldValue = value
            value = newValue
            publish((oldValue, newValue))
        }
    }

    var projectedValue: Publishable { self }
    init(wrappedValue: Property) {
        self.value = wrappedValue
    }

    func subscribe<Subscriber: AnyObject>(
        by subscriber: Subscriber,
        immediate: Bool = false,
        _ callback: @escaping Callback<Subscriber>
    ) {
        let anyCallback: Callback<AnyObject> = { args in
            callback((args.subscriber as! Subscriber, args.changes))
        }
        subscriptions.append(.init(callback: anyCallback, subscriber: .init(subscriber)))
        if immediate { callback((subscriber, (value, value))) }
    }

    func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        subscriptions.removeAll { $0.subscriber.value == nil || $0.subscriber.value === subscriber }
    }

    func publish(_ changes: Changes? = nil) {
        let (old, new) = changes ?? (value, value)
        subscriptions = subscriptions.compactMap { subscription in
            guard let subscriber = subscription.subscriber.value else { return nil }
            subscription.callback((subscriber, (old, new)))
            return subscription
        }
    }
}
