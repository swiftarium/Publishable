# Publishable

[한글문서 KOREAN](/README_ko.md)

## Overview

`Publishable` is a Property Wrapper class that allows you to easily subscribe to and track changes in properties.

## Key Features

- Subscribe to property value changes and execute specific actions when changes occur.
- Store subscriber objects with weak references to prevent memory leaks.
- If a subscriber object is provided, the subscription will be automatically removed when the subscriber object is deallocated.
- Provides a thread-safe implementation to prevent concurrency issues in multi-threaded environments.

## Installation

### Swift Package Manager

To install `Publishable` using SPM, add the following to the `dependencies` array in your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/swiftarium/Publishable.git", from: "1.4.0"),
]
```

Then, specify `"Publishable"` as a dependency for the target where you'll use it.

```swift
targets: [
    .target(name: "YourTarget", dependencies: ["Publishable"]),
]
```

## API Reference

### Publishable

```swift
/// Subscribe to property changes.
/// immediate: If true, the callback will be called immediately after subscription. (default: false)
func subscribe(immediate: Bool, tokenProvider: TokenProvider?, (Changes) -> Void) -> any SubscriptionToken
func subscribe<Subscriber>(by: Subscriber?, immediate: Bool, Callback<Subscriber>)

/// Unsubscribe from property changes.
func unsubscribe<Token>(by: Token)
func unsubscribe<Subscriber>(by: Subscriber)

/// Manually publish changes.
func publish()
```

To subscribe changes to a specific property, apply the `@Publishable` wrapper to that property.

```swift
class MyModel {
    @Publishable var count: Int = 0
}
```

You can subscribe to a property with `@Publishable` using the `subscribe` method.

```swift
let model = MyModel()

// If you provide a subscriber object, the subscription will be automatically removed when the subscriber object is deallocated.
class SubscriberClass {
    init() {
        model.$count.subscribe(by: self) { subscriber, changes in
            print("Count changed from \(changes.old) to \(changes.new)")
        }
    }
}

let subscriber = SubscriberClass()

model.count = 5  // This will print: "Count changed from 0 to 5"

// Unsubscribe from changes.
model.$count.unsubscribe(by: subscriber)
```

If you don't provide a subscriber object, you will receive a token which you can use to unsubscribe.

```swift
let token = model.$count.subscribe { changes in
    print("Count changed from \(changes.old) to \(changes.new)")
}

model.count = 10  // This will print: "Count changed from 5 to 10"

// Unsubscribe from changes.
model.$count.unsubscribe(by: token)
```

## Testing

```bash
$ swift test
```

## License

This library is released under the MIT license. See [LICENSE](/LICENSE) for details.