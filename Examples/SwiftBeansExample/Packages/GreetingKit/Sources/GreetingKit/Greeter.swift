/// Produces a greeting for a name.
public protocol Greeter: Sendable {
	func greet(_ name: String) -> String
}
