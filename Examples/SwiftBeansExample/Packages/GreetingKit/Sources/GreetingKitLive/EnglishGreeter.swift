import GreetingKit
import SwiftBeans

/// Local-package provider: `public` type (auto-init emits a `public init`), so the app's
/// generated context can construct it.
@Service(boundTo: Greeter.self, autoInit: true)
public final class EnglishGreeter: Greeter {
	public func greet(_ name: String) -> String {
		"Hello, \(name)!"
	}
}
