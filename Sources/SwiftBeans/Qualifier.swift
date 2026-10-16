/// Asks for the bean registered with `named:` on an initializer or `@Bean` parameter.
///
/// `@Qualifier("snakeCase") decoder: JSONDecoder` receives the `JSONDecoder` from `@Bean(named: "snakeCase")`.
/// It is only a marker for the generator: callers pass a plain `Value` and the body sees a plain `Value`.
/// The name must be a string literal.
@propertyWrapper
@frozen
public struct Qualifier<Value> {
	public let wrappedValue: Value

	@inlinable
	public init(wrappedValue: Value, _ name: String) {
		self.wrappedValue = wrappedValue
	}
}

extension Qualifier: Sendable where Value: Sendable {}
