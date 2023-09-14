# Publishable

A Swift property wrapper that enables easy property observation for classes. With Publishable, any object can subscribe to property changes and be notified when those changes occur.

## Installation

### Swift Package Manager

To integrate `Publishable` into your Xcode project using SPM, add it to the dependencies value of your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/jinyongp/Publishable.git", from: "1.0.0"),
]
```

## Usage

Using Publishable is straightforward:

1. Annotate the property you want to observe with @Publishable.
2. Subscribe to changes on that property.
3. (Optional) unsubscribe when you no longer want to observe changes.

**Examples**

```swift
import Publishable

class Model {
    @Publishable var count = 0
}

let model = Model()

// Subscribe to changes
model.$count.subscribe(by: self) { (subscriber, changes) in
    print("Count changed from \(changes.old) to \(changes.new)")
}

model.count = 5  // This will print: "Count changed from 0 to 5"
```

## Test

To run the included tests, use the command:

```bash
$ swift test
```


## License

This library is released under the MIT license. See [LICENSE](/LICENSE) for details.
