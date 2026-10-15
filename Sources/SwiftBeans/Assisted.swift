/// Marks an initializer or `@Bean` parameter as a runtime argument (assisted injection).
///
/// The generated context exposes a method taking the assisted parameters instead of a property.
/// It is only a marker for the generator: callers pass a plain `Value` and the body sees a plain `Value`.
@propertyWrapper
@frozen
public struct Assisted<Value> {
	public let wrappedValue: Value

	@inlinable
	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
}

extension Assisted: Sendable where Value: Sendable {}
