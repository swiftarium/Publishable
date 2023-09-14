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
    typealias AnyCallback = ((subscriber: AnyObject?, changes: Changes)) -> Void

    typealias SubscriptionToken = UUID

    /// A structure that holds a weak reference to an object of type `T`.
    private struct WeakRef<T: AnyObject> {
        weak var value: T?

        var isAlive: Bool { value != nil }

        /// Initializes a new weak reference.
        /// - Parameter value: The object to be weakly referenced.
        init(_ value: T?) {
            self.value = value
        }
    }

    /// Represents a subscription to the property changes.
    private struct Subscription<Subscriber: AnyObject> {
        let token: SubscriptionToken?
        let subscriber: WeakRef<Subscriber>
        let callback: AnyCallback
    }

    private var value: Property
    private var subscriptions: [Subscription<AnyObject>] = []

    private var queue = DispatchQueue(label: "com.publishable.queue", attributes: .concurrent)
    private func read<T>(_ action: () -> T) -> T { queue.sync { action() } }
    private func write<T>(_ action: () -> T) -> T { queue.sync(flags: .barrier) { action() } }

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
            let anyCallback: AnyCallback = { args in
                callback((args.subscriber as! Subscriber, args.changes))
            }
            subscriptions.append(.init(
                token: nil,
                subscriber: .init(subscriber),
                callback: anyCallback
            ))
            if immediate { callback((subscriber, (value, value))) }
        }
    }

    @discardableResult
    func subscribe(
        immediate: Bool = false,
        _ callback: @escaping (_ changes: Changes) -> Void
    ) -> SubscriptionToken {
        write {
            let anyCallback: AnyCallback = { args in
                callback(args.changes)
            }
            let token = SubscriptionToken()
            subscriptions.append(.init(
                token: token,
                subscriber: .init(nil),
                callback: anyCallback
            ))
            if immediate { callback((value, value)) }
            return token
        }
    }

    /// Unsubscribes an object so it will no longer be notified of property changes.
    /// - Parameter subscriber: The object to unsubscribe.
    func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        write { subscriptions.removeAll { !$0.subscriber.isAlive || $0.subscriber.value === subscriber } }
    }

    func unsubscribe(token: SubscriptionToken) {
        write { subscriptions.removeAll { !$0.subscriber.isAlive || $0.token == token } }
    }

    /// Publishes changes to all subscribers.
    /// - Parameter changes: Optional specific changes to publish. If nil, uses current value for both old and new.
    func publish(_ changes: Changes? = nil) {
        write {
            let (old, new) = changes ?? (value, value)
            subscriptions = subscriptions.compactMap { subscription in
                guard subscription.subscriber.isAlive || subscription.token != nil else { return nil }
                subscription.callback((subscription.subscriber.value, (old, new)))
                return subscription
            }
        }
    }
}
