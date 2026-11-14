import SwiftUI

/// Remplace `@State` : sans Xcode (Command Line Tools seuls), le plugin de
/// macro SwiftUI n'existe pas, donc l'état local passe par un ObservableObject.
final class Box<T>: ObservableObject {
    @Published var value: T
    init(_ value: T) { self.value = value }
}

@propertyWrapper
struct Local<T>: DynamicProperty {
    @StateObject private var box: Box<T>
    init(wrappedValue: T) { _box = StateObject(wrappedValue: Box(wrappedValue)) }
    var wrappedValue: T {
        get { box.value }
        nonmutating set { box.value = newValue }
    }
    var projectedValue: Binding<T> {
        let b = box
        return Binding(get: { b.value }, set: { b.value = $0 })
    }
}
