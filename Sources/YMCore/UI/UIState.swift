import SwiftUI

/// Safe SwiftUI State wrapper compatible with standalone Swift 6 Command Line Tools environments
/// where Apple's `SwiftUIMacros` plugin is not bundled in CLT.
/// Delegates directly to `SwiftUI.State<Value>` and conforms to `DynamicProperty`.
@propertyWrapper
public struct UIState<Value>: DynamicProperty {
    private var storage: State<Value>

    public init(wrappedValue: Value) {
        self.storage = State(wrappedValue: wrappedValue)
    }

    public init(initialValue: Value) {
        self.storage = State(initialValue: initialValue)
    }

    public var wrappedValue: Value {
        get { storage.wrappedValue }
        nonmutating set { storage.wrappedValue = newValue }
    }

    public var projectedValue: Binding<Value> {
        storage.projectedValue
    }
}
