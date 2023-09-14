import Foundation

/// A property wrapper that allows objects to subscribe to property changes.
/// ```
/// class Model {
///     @Publishable var count = 0
/// }
///
/// let model = Model()
/// model.$count.subscribe(by: self) { (self, changes) in
///     print("Count changed from \(changes.old) to \(changes.new)")
/// }
///
/// model.count = 5  // Outputs: "Count changed from 0 to 5"
/// ```
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

    private var queue = DispatchQueue(label: "com.publishable.queue", attributes: .concurrent)
    private func read<T>(_ action: () -> T) -> T { queue.sync { action() } }
    private func write(_ action: () -> Void) { queue.sync(flags: .barrier) { action() } }

    var projectedValue: Publishable { self }
    var wrappedValue: Property {
        get { read { value } }
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
        write {
            let anyCallback: Callback<AnyObject> = { args in
                callback((args.subscriber as! Subscriber, args.changes))
            }
            subscriptions.append(.init(callback: anyCallback, subscriber: .init(subscriber)))
            if immediate { callback((subscriber, (value, value))) }
        }
    }

    /// Unsubscribes an object so it will no longer be notified of property changes.
    /// - Parameter subscriber: The object to unsubscribe.
    func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        write {
            subscriptions.removeAll { $0.subscriber.value == nil || $0.subscriber.value === subscriber }
        }
    }

    /// Publishes changes to all subscribers.
    /// - Parameter changes: Optional specific changes to publish. If nil, uses current value for both old and new.
    func publish(_ changes: Changes? = nil) {
        write {
            let (old, new) = changes ?? (value, value)
            subscriptions = subscriptions.compactMap { subscription in
                guard let subscriber = subscription.subscriber.value else { return nil }
                subscription.callback((subscriber, (old, new)))
                return subscription
            }
        }
    }
}
