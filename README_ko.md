# Publishable

## 개요

`Publishable`은 Property Wrapper 클래스로 속성의 변경 구독하여 쉽게 추적할 수 있습니다.

## 주요 기능

- 속성 값의 변경을 구독하여 변경 발생 시 특정 작업을 수행할 수 있습니다.
- 구독자 객체를 약한 참조로 저장하여 메모리 누수를 방지합니다.
- 구독자 객체를 전달한 경우, 해당 객체가 해제될 때 구독을 자동으로 제거합니다.
- 쓰레드 안전한 구현을 제공하여 멀티 쓰레드 환경에서 동시성 문제를 방지합니다.

## 설치방법

### Swift Package Manager

SPM으로 `Publishable`을 설치하려면 `Package.swift`의 `dependencies` 배열에 추가하세요.

```swift
dependencies: [
    .package(url: "https://github.com/swiftarium/Publishable.git", from: "1.4.0"),
]
```

그리고, `Publishable`을 사용할 타겟의 의존성으로 `"Publishable"`를 지정하세요.

```swift
targets: [
    .target(name: "YourTarget", dependencies: ["EventBus"]),
]
```

## API Reference

### Publishable

```swift
// 속성의 변경을 구독합니다.
func subscribe(immediate: Bool, tokenProvider: TokenProvider?, (Changes) -> Void) -> any SubscriptionToken
func subscribe<Subscriber>(by: Subscriber?, immediate: Bool, Callback<Subscriber>)

// 구독을 해제합니다.
func unsubscribe<Token>(by: Token)
func unsubscribe<Subscriber>(by: Subscriber)

// 수동으로 변경을 발행합니다.
func publish()
```

특정 속성의 변경을 관찰하고 싶다면, 해당 속성에 `@Publishable`을 적용하세요.

```swift
class MyModel {
    @Publishable var count: Int = 0
}
```

`@Publishable`을 적용한 속성은 `subscribe` 메서드를 통해 구독할 수 있습니다.

```swift
let model = MyModel()

// 구독자 객체를 전달한 경우, 해당 객체가 해제될 때 구독을 자동으로 제거합니다.
class SubscriberClass {
    init() {
        model.$count.subscribe(by: self) { subscriber, changes in
            print("Count changed from \(changes.old) to \(changes.new)")
        }
    }
}

let subscriber = SubscriberClass()

model.count = 5  // This will print: "Count changed from 0 to 5"

// 구독을 해제합니다.
model.$count.unsubscribe(by: subscriber)
```

구독자 객체를 전달하지 않은 경우, 구독을 해제하기 위한 토큰을 반환합니다.

```swift
let token = model.$count.subscribe { changes in
    print("Count changed from \(changes.old) to \(changes.new)")
}

model.count = 10  // This will print: "Count changed from 5 to 10"

// 구독을 해제합니다.
model.$count.unsubscribe(by: token)
```

## 테스트

```bash
$ swift test
```

## License

This library is released under the MIT license. See [LICENSE](/LICENSE) for details.
