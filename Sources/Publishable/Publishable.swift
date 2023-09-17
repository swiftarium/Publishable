import AutoCleaner
import Dispatch
import WeakRef

/// `Publishable` allows you to observe changes on properties.
///
/// Example:
/// ```swift
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

    struct Subscription {
        let callback: AnyCallback
    }

    private(set) var value: Property
    private(set) lazy var subscriptions = AutoCleaner([SubscriptionIdentifier: Subscription]()) { element in
        !element.key.isValid
    }

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
    /// ```swift
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
            callback(subscriber as! Subscriber, changes)
        }

        if immediate, let subscriber {
            callback(subscriber, (value, value))
        }

        write {
            let identifier: SubscriptionIdentifier = .subscriber(.init(subscriber))
            let subscription: Subscription = .init(callback: anyCallback)
            subscriptions.items.updateValue(subscription, forKey: identifier)
        }
    }

    /// Subscribe to changes of the property.
    /// - Parameters:
    ///   - immediate: If true, immediately calls the callback with the current value.
    ///   - callback: The function to be called when the property changes.
    /// - Returns: A token representing the subscription, useful for unsubscribing.
    ///
    /// Example:
    /// ```swift
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

        if immediate {
            callback((value, value))
        }

        return write {
            let token = tokenProvider?() ?? DefaultToken()
            let identifier: SubscriptionIdentifier = .token(token)
            let subscription: Subscription = .init(callback: anyCallback)
            subscriptions.items.updateValue(subscription, forKey: identifier)
            return token
        }
    }

    /// Unsubscribe a subscriber from observing the property changes.
    /// - Parameter subscriber: The subscriber to unsubscribe.
    ///
    /// Example:
    /// ```swift
    /// model.$value.unsubscribe(by: subscriber)
    /// ```
    public func unsubscribe<Subscriber: AnyObject>(by subscriber: Subscriber) {
        write {
            let identifier: SubscriptionIdentifier = .subscriber(.init(subscriber))
            subscriptions.items.removeValue(forKey: identifier)
        }
    }

    /// Unsubscribe using a token.
    /// - Parameter token: The token for unsubscribing.
    ///
    /// Example:
    /// ```swift
    /// model.$value.unsubscribe(by: token)
    /// ```
    public func unsubscribe<Token: SubscriptionToken>(by token: Token) {
        write {
            let identifier: SubscriptionIdentifier = .token(token)
            subscriptions.items.removeValue(forKey: identifier)
        }
    }

    /// Manually notifies all subscribers of the current property value.
    public func publish() { publish((value, value)) }
    func publish(_ changes: Changes) {
        read {
            subscriptions.clean()
            return subscriptions.items
        }.forEach { identifier, subscription in
            guard identifier.isValid else { return }
            switch identifier {
            case .token: subscription.callback(nil, changes)
            case let .subscriber(subscriber): subscription.callback(subscriber.value, changes)
            }
        }
    }
}
