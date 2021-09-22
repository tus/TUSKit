# TUSKit

A description of this package.

## Singleton

To support multiple clients for uploads, TUSClient does not support singletons.
You can make your own singleton, e.g.

```swift
final class MyClass {
     static let client = TUSClient(...)
}
```
