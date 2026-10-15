import GreetingKit
import SwiftBeans

/// Namespace for feature services; exercises nested `@Service` keys (`Features.WelcomeBanner`).
enum Features {
	/// Combines a local-package bean (`any Greeter` from `GreetingKitLive`) with an app service.
	@Service
	final class WelcomeBanner: Sendable {
		private let greeter: any Greeter
		private let summary: TagSummary

		init(greeter: any Greeter, summary: TagSummary) {
			self.greeter = greeter
			self.summary = summary
		}

		var message: String {
			"\(greeter.greet("SwiftBeans")) Top tags: \(summary.topTags.joined(separator: ", "))"
		}
	}
}
