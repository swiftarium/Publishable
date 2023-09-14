import Foundation

/// `Publishable` allows you to observe changes on properties.
///
/// Example:
/// ```
/// class ExampleModel {
///     @Publishable var value: Int = 0
/// }
///
/// let model = ExampleModel()
///
/// model.$value.subscribe { changes in
///     print("Value changed from \(changes.old) to \(changes.new)")
/// }
///
/// model.value = 5  // This will print: "Value changed from 0 to 5"
/// ```
@propertyWrapper
final class Publishable<Property> where Property: Equatable {
    typealias Changes = (old: Property, new: Property)
    typealias Callback<Subscriber: AnyObject> = ((subscriber: Subscriber, changes: Changes)) -> Void
    typealias AnyCallback = ((subscriber: AnyObject?, changes: Changes)) -> Void
    typealias SubscriptionToken = UUID

    private struct WeakRef<T: AnyObject> {
        weak var value: T?
        var isAlive: Bool { value != nil }

        init(_ value: T?) {
            self.value = value
        }
    }

    private struct Subscription<Subscriber: AnyObject> {
        let token: SubscriptionToken?
        let subscriber: WeakRef<Subscriber>
        let callback: AnyCallback
    }

    private var value: Property
    private var subscriptions: [Subscription<AnyObject>] = []

    var projectedValue: Publishable { self }
    var wrappedValue: Property {
        get { value }
        set { updateValue(newValue) }
    }

    init(wrappedValue: Property) { self.value = wrappedValue }

    /// Subscribe to changes using an object.
    /// - Parameters:
    ///   - subscriber: The object subscribing to the changes.
    ///   - immediate: If true, immediately calls the callback with the current value.
    ///   - callback: The function to be called when the property changes.
    ///
    /// Example:
    /// ```
    /// class ExampleModel {
    ///     @Publishable var value: Int = 0
    /// }
    ///
    /// let model = ExampleModel()
    ///
    /// class ExampleSubscriber {
    ///     init() {
    ///         model.$value.subscribe(by: self) { (subscriber, changes) in
    ///             print("Value changed from \(changes.old) to \(changes.new)")
    ///         }
    ///     }
    /// }
    ///
    /// let subscriber = ExampleSubscriber()
    ///
    /// model.value = 5  // This will print: "Value changed from 0 to 5"
    /// ```
    func subscribe<Subscriber: AnyObject>(
        by subscriber: Subscriber,
        immediate: Bool = false,
        _ callback: @escaping Callback<Subscriber>
    ) {
        let anyCallback: AnyCallback = { args in
            if let subscriber = args.subscriber as? Subscriber {
                callback((subscriber, args.changes))
            }
        }
        let subscription: Subscription<AnyObject> = Subscription(
            token: nil,
            subscriber: .init(subscriber),
            callback: anyCallback
        )
        subscriptions.append(subscription)
        if immediate { callback((subscriber, (value, value))) }
    }

    /// Subscribe to changes.
    /// - Parameters:
    ///   - immediate: If true, immediately calls the callback with the current value.
    ///   - callback: The function to be called when the property changes.
    /// - Returns: A token representing the subscription, useful for unsubscribing.
    ///
    /// Example:
    /// ```
    /// class ExampleModel {
    ///     @Publishable var value: Int = 0
    /// }
    ///
    /// let model = ExampleModel()
    ///
    /// let token = model.$value.subscribe { changes in
    ///     print("Value changed from \(changes.old) to \(changes.new)")
    /// }
    ///
    /// model.value = 5  // This will print: "Value changed from 0 to 5"
    /// ```
    @discardableResult
    func subscribe(
        immediate: Bool = false,
        _ callback: @escaping (_ changes: Changes) -> Void
    ) -> SubscriptionToken {
        let anyCallback: AnyCallback = { args in callback(args.changes) }
        let subscription: Subscription<AnyObject> = Subscription(
            token: SubscriptionToken(),
            subscriber: .init(nil),
            callback: anyCallback
        )
        subscriptions.append(subscription)
        if immediate { callback((value, value)) }
        return subscription.token!
    }

    /// Unsubscribe using an object.
    /// - Parameter subscriber: The subscriber to unsubscribe.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(by: subscriber)
    /// ```
    func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        subscriptions.removeAll { !$0.subscriber.isAlive || $0.subscriber.value === subscriber }
    }

    /// Unsubscribe using a token.
    /// - Parameter token: The token for unsubscribing.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(token: token)
    /// ```
    func unsubscribe(token: SubscriptionToken) {
        subscriptions.removeAll { !$0.subscriber.isAlive || $0.token == token }
    }

    /// Notify subscribers.
    /// - Parameter changes: The changes to publish. If not provided, the current value is used.
    ///
    /// Example:
    /// ```
    /// model.$value.publish()  // Notifies subscribers with the current value
    /// ```
    func publish(_ changes: Changes? = nil) {
        let (old, new) = changes ?? (value, value)
        subscriptions = subscriptions.filter { subscription in
            guard subscription.subscriber.isAlive || subscription.token != nil else { return false }
            subscription.callback((subscription.subscriber.value, (old, new)))
            return true
        }
    }

    private func updateValue(_ newValue: Property) {
        let changesToPublish: Changes? = {
            guard value != newValue else { return nil }
            defer { value = newValue }
            return (value, newValue)
        }()
        if let changes = changesToPublish {
            publish(changes)
        }
    }
}
