import AutoCleaner
import Dispatch
import WeakRef

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

    struct Subscription<Subscriber: AnyObject> {
        let token: (any SubscriptionToken)?
        let subscriber: WeakRef<Subscriber>
        let callback: AnyCallback
    }

    private(set) var value: Property
    private(set) lazy var subscriptions = AutoCleaner([Subscription<AnyObject>]()) { !self.isValid(subscription: $0) }

    private(set) var queue = DispatchQueue(label: "com.publishable.queue", attributes: .concurrent)
    private func read<T>(_ action: () -> T) -> T { queue.sync { action() } }
    private func write<T>(_ action: () -> T) -> T { queue.sync(flags: .barrier) { action() } }

    public var projectedValue: Publishable { self }
    public var wrappedValue: Property {
        get { read { value } }
        set {
            let changes: Changes? = write {
                guard value != newValue else { return nil }
                defer { value = newValue }
                return (value, newValue)
            }
            if let changes { publish(changes) }
        }
    }

    public init(wrappedValue: Property) {
        self.value = wrappedValue
        subscriptions.start { count in
            let interval = (min: 10.0, max: 120.0)
            let rate = (interval.max - interval.min) / 100.0
            let frequency = interval.max - (rate * Double(count))
            return .seconds(Int(max(min(frequency, interval.max), interval.min)))
        }
    }

    /// Subscribe to changes of the property using a subscriber object.
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

        write {
            subscriptions.update { collection in
                collection.append(.init(
                    token: nil,
                    subscriber: .init(subscriber),
                    callback: anyCallback
                ))
            }
        }

        if immediate, let subscriber {
            callback(subscriber, (value, value))
        }
    }

    /// Subscribe to changes of the property.
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
        let anyCallback: AnyCallback = { callback($1) }
        let token = tokenProvider?() ?? DefaultToken()

        write {
            subscriptions.update { collection in
                collection.append(.init(
                    token: token,
                    subscriber: .init(nil),
                    callback: anyCallback
                ))
            }
        }

        if immediate {
            callback((value, value))
        }

        return token
    }

    /// Unsubscribe a subscriber from observing the property changes.
    /// - Parameter subscriber: The subscriber to unsubscribe.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(by: subscriber)
    /// ```
    public func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        write {
            subscriptions.update { collection in
                collection.removeAll { !isValid(subscription: $0) || $0.subscriber == subscriber }
            }
        }
    }

    /// Unsubscribe using a token.
    /// - Parameter token: The token for unsubscribing.
    ///
    /// Example:
    /// ```
    /// model.$value.unsubscribe(by: token)
    /// ```
    public func unsubscribe<Token: SubscriptionToken>(by token: Token) {
        write {
            subscriptions.update { collection in
                collection.removeAll { !isValid(subscription: $0) || token == $0.token }
            }
        }
    }

    /// Manually notifies all subscribers of the current property value.
    public func publish() { publish((value, value)) }
    func publish(_ changes: Changes) {
        read { subscriptions }.collection.forEach {
            guard isValid(subscription: $0) else { return }
            $0.callback($0.subscriber.value, changes)
        }
    }

    func isValid(subscription: Subscription<AnyObject>) -> Bool {
        return subscription.subscriber.hasValue || subscription.token != nil
    }
}
