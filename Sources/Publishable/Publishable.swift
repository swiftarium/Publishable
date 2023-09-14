/// A property wrapper that allows objects to subscribe to property changes.
@propertyWrapper
final class Publishable<Property> {
    /// Represents a change in property values.
    typealias Changes = (old: Property, new: Property)

    /// Callback type that gets invoked when a property changes.
    /// - Parameters:
    ///   - subscriber: The object that subscribed to the changes.
    ///   - changes: The old and new property values.
    typealias Callback<Subscriber: AnyObject> = ((subscriber: Subscriber, changes: Changes)) -> Void

    /// A structure that holds a weak reference to an object of type `T`.
    private struct WeakRef<T: AnyObject> {
        weak var value: T?

        /// Initializes a new weak reference.
        /// - Parameter value: The object to be weakly referenced.
        init(_ value: T?) {
            self.value = value
        }
    }

    /// Represents a subscription to the property changes.
    private struct Subscription<Subscriber: AnyObject> {
        let callback: Callback<Subscriber>
        let subscriber: WeakRef<Subscriber>
    }

    private var value: Property
    private var subscriptions: [Subscription<AnyObject>] = []

    /// Access to the `Publishable` instance for more advanced operations like subscribing and unsubscribing.
    var projectedValue: Publishable { self }

    /// The property's value. Setting this will notify any subscribers of the change.
    var wrappedValue: Property {
        get { value }
        set {
            let oldValue = value
            value = newValue
            publish((oldValue, newValue))
        }
    }

    /// Initializes the property with an initial value.
    /// - Parameter wrappedValue: The initial value of the property.
    init(wrappedValue: Property) {
        self.value = wrappedValue
    }

    /// Subscribes an object to be notified of property changes.
    /// - Parameters:
    ///   - subscriber: The object that wants to be notified of changes.
    ///   - immediate: If `true`, the callback will be called immediately with the current value.
    ///   - callback: The function to call when the property changes.
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

    /// Unsubscribes an object so it will no longer be notified of property changes.
    /// - Parameter subscriber: The object to unsubscribe.
    func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        subscriptions.removeAll { $0.subscriber.value == nil || $0.subscriber.value === subscriber }
    }

    /// Publishes changes to all subscribers.
    /// - Parameter changes: Optional specific changes to publish. If nil, uses current value for both old and new.
    func publish(_ changes: Changes? = nil) {
        let (old, new) = changes ?? (value, value)
        subscriptions = subscriptions.compactMap { subscription in
            guard let subscriber = subscription.subscriber.value else { return nil }
            subscription.callback((subscriber, (old, new)))
            return subscription
        }
    }
}
