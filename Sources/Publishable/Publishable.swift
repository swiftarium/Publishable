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
public final class Publishable<Property> where Property: Equatable {
    public typealias Changes = (old: Property, new: Property)
    public typealias Callback<Subscriber: AnyObject> = (_ subscriber: Subscriber, _ changes: Changes) -> Void
    public typealias AnyCallback = (_ subscriber: AnyObject?, _ changes: Changes) -> Void
    public typealias TokenProvider = () -> any SubscriptionToken

    private struct Subscription<Subscriber: AnyObject> {
        let token: (any SubscriptionToken)?
        let subscriber: WeakRef<Subscriber>
        let callback: AnyCallback
    }

    private var value: Property
    private var subscriptions: [Subscription<AnyObject>] = []

    public var projectedValue: Publishable { self }
    public var wrappedValue: Property {
        get { value }
        set {
            let changes: Changes? = {
                guard value != newValue else { return nil }
                defer { value = newValue }
                return (value, newValue)
            }()
            if let changes { publish(changes) }
        }
    }

    public init(wrappedValue: Property) { self.value = wrappedValue }

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
    public func subscribe<Subscriber: AnyObject>(
        by subscriber: Subscriber?,
        immediate: Bool = false,
        _ callback: @escaping Callback<Subscriber>
    ) {
        let anyCallback: AnyCallback = { subscriber, changes in
            if let subscriber = subscriber as? Subscriber {
                callback(subscriber, changes)
            }
        }

        subscriptions.append(.init(
            token: nil,
            subscriber: .init(subscriber),
            callback: anyCallback
        ))

        if immediate, let subscriber {
            callback(subscriber, (value, value))
        }
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
    public func subscribe(
        immediate: Bool = false,
        tokenProvider: TokenProvider? = nil,
        _ callback: @escaping (_ changes: Changes) -> Void
    ) -> any SubscriptionToken {
        let anyCallback: AnyCallback = { _, changes in
            callback(changes)
        }

        let token = tokenProvider?() ?? DefaultToken()
        subscriptions.append(.init(
            token: token,
            subscriber: .init(nil),
            callback: anyCallback
        ))

        if immediate {
            callback((value, value))
        }

        return token
    }

    /// Unsubscribe using an object.
    /// - Parameter subscriber: The subscriber to unsubscribe.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(by: subscriber)
    /// ```
    public func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        subscriptions.removeAll { !isValid(subscription: $0) || $0.subscriber == subscriber }
    }

    /// Unsubscribe using a token.
    /// - Parameter token: The token for unsubscribing.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(by: token)
    /// ```
    public func unsubscribe<Token: SubscriptionToken>(by token: Token) {
        subscriptions.removeAll { !isValid(subscription: $0) || token == $0.token }
    }

    /// Notify subscribers.
    /// - Parameter changes: The changes to publish. If not provided, the current value is used.
    ///
    /// Example:
    /// ```
    /// model.$value.publish()  // Notifies subscribers with the current value
    /// ```
    public func publish(_ changes: Changes? = nil) {
        let (old, new) = changes ?? (value, value)
        subscriptions = subscriptions.filter { subscription in
            guard isValid(subscription: subscription) else { return false }
            subscription.callback(subscription.subscriber.value, (old, new))
            return true
        }
    }

    private func isValid(subscription: Subscription<AnyObject>) -> Bool {
        return subscription.subscriber.value != nil || subscription.token != nil
    }
}
