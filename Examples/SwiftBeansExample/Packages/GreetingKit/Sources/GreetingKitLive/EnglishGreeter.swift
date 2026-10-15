import GreetingKit
import SwiftBeans

/// Local-package provider: `public` type and `public init`, so the app's
/// generated context can construct it.
@Service(boundTo: Greeter.self)
public final class EnglishGreeter: Greeter {
	public init() {}

	public func greet(_ name: String) -> String {
		"Hello, \(name)!"
	}
}
