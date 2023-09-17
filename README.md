# Publishable

`Publishable` is a property wrapper in Swift designed to enable seamless observation of property changes. Whether you're designing reactive UI components or need to monitor data changes, `Publishable` offers a simple and efficient way to keep track.

## Features

- Observes properties for changes.
- Notifies subscribers when a property changes.
- Supports both class-based subscribers and simple subscribers.
- Clears out deallocated class-based subscriptions automatically.
- All operations, including property reads/writes and subscriber management, are thread-safe, courtesy of a dedicated dispatch queue.

## Installation

### Swift Package Manager

To install `Publishable` into your Xcode project using SPM, add it to the dependencies value of your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/jinyongp/Publishable.git", from: "1.4.0"),
]
```

And specify `"Publishable"` as a dependency of the Target in which you wish to use `Publishable`.

```swift
targets: [
    .target(name: "YourTarget", dependencies: ["Publishable"]),
]
```

## Usage

### Basic Usage

Declare a property using the @Publishable property wrapper to make it observable:

```swift 
class MyModel {
    @Publishable var count: Int = 0
}
```

### Subscribing to Changes

You can subscribe to changes in two ways:

1. With a subscriber object:

```swift
let model = MyModel()

class SubscriberClass {
    init() {
        model.$count.subscribe(by: self) { subscriber, changes in
            print("Count changed from \(changes.old) to \(changes.new)")
        }
    }
}

let subscriber = SubscriberClass()

model.count = 5  // This will print: "Count changed from 0 to 5"
```

2. Using with a simple token for unsubscribes:

```swift
let token = model.$count.subscribe { changes in
    print("Count changed from \(changes.old) to \(changes.new)")
}

model.count = 10  // This will print: "Count changed from 5 to 10"
```

### Unsubscribing

1. By a subscriber object:

```swift
model.$count.unsubscribe(by: subscriber)
```

2. Using a token:

```swift
model.$count.unsubscribe(by: token)
```

### Publishing Changes:

If you want to manually notify all subscribers of a change (e.g., for events or updates that aren't related to the property value):

```swift
model.$count.publish()  // Notifies subscribers with the current value
```

## Test

To run the included tests, use the command:

```bash
$ swift test
```


## License

This library is released under the MIT license. See [LICENSE](/LICENSE) for details.
