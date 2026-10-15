import GreetingKit
import Testing
@testable import SwiftBeansExample

/// Runtime checks for the beans that exist to compile-check generated code:
/// local-package provider, nested service, generic-collection key, `@Inject` init.
@Suite("Generated wiring")
@MainActor
struct GeneratedWiringTests {
	@Test
	func `Given local package greeter When resolving through AppContext Then uses GreetingKitLive`() {
		let context = AppContext()
		#expect(context.greeter.greet("Ada") == "Hello, Ada!")
	}

	@Test
	func `Given dictionary bean When consumed as Dictionary spelling Then TagSummary gets the bean`() {
		let context = AppContext()
		#expect(context.tagSummary.tagCounts == context.stringIntDictionary)
		#expect(context.tagSummary.topTags == ["swift", "di", "macros"])
	}

	@Test
	func `Given nested service When resolved twice Then same singleton with live greeting`() {
		let context = AppContext()
		#expect(context.featuresWelcomeBanner === context.featuresWelcomeBanner)
		#expect(context.featuresWelcomeBanner.message == "Hello, SwiftBeans! Top tags: swift, di, macros")
	}

	@Test
	func `Given TagSummary When built from tags Then counts each tag`() {
		let summary = TagSummary(tags: ["a", "b", "a"])
		#expect(summary.tagCounts == ["a": 2, "b": 1])
	}

	@Test
	func `Given FakeAppContext When reading the banner Then uses the preview greeter`() {
		let context = FakeAppContext()
		#expect(context.featuresWelcomeBanner.message.hasPrefix("Hi, SwiftBeans (preview)!"))
	}
}
