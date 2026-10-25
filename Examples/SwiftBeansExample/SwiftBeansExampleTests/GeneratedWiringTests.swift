import Foundation
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

	@Test
	func `Given qualified decoders When resolved Then each name is its own singleton`() throws {
		let context = AppContext()
		#expect(context.jsonDecoder === context.jsonDecoder)
		#expect(context.snakeCaseJSONDecoder === context.snakeCaseJSONDecoder)
		#expect(context.jsonDecoder !== context.snakeCaseJSONDecoder)
		#expect(try context.snakeCaseReader.title(from: SnakeCaseReader.sampleJSON) == "Named decoder")
		#expect(throws: DecodingError.self) {
			try context.jsonDecoder.decode(SnakeCaseTitle.self, from: SnakeCaseReader.sampleJSON)
		}
	}

	@Test
	func `Given a named greeter When resolving greeting styles Then each qualifier keeps its bean`() {
		let context = AppContext()
		#expect(context.greetingStyles.standard == "Hello, SwiftBeans!")
		#expect(context.greetingStyles.short == "Hi, SwiftBeans")
		#expect(context.shortGreeter.greet("Ada") == "Hi, Ada")
	}

	@Test
	func `Given named services When resolving the pair Then each qualifier is wired`() {
		let context = AppContext()
		#expect(context.builtinStaticTagSource === context.builtinStaticTagSource)
		#expect(context.tagSourcePair.builtinLabel == "builtin")
		#expect(context.tagSourcePair.remoteLabel == "remote")
		#expect(context.remoteTagSource.label == "remote")
	}

	@Test
	func `Given feature notes When opening the demo Then the collection is in accessor name order`() {
		let notes = AppContext().featuresDemoViewModel.featureNotes
		#expect(notes.map(\.title) == ["@Assisted", "Collections", "Factories", "@Qualifier"])
	}

	@Test(arguments: [false, true])
	func `Given an explicit existential array When read through the context protocol Then order and singleton members survive`(fake: Bool) {
		let context: any AppContextProtocol = fake ? FakeAppContext() : AppContext()
		let notes: [any FeatureNote] = context.highlightsFeatureNoteArray
		#expect(notes.map(\.title) == ["Factories", "@Assisted"])
		#expect(notes.count == 2)
		#expect(notes.first as? FactoryFeatureNote === context.factoryFeatureNote)
		#expect(notes.last as? AssistedFeatureNote === context.assistedFeatureNote)
		let model = context.featuresDemoViewModel
		#expect(model.highlightedNotes.map(\.title) == notes.map(\.title))
		#expect(model.highlightedNotes.first as? FactoryFeatureNote === context.factoryFeatureNote)
		#expect(model.highlightedNotes.last as? AssistedFeatureNote === context.assistedFeatureNote)
		#expect(model.featureNotes.map(\.title) == ["@Assisted", "Collections", "Factories", "@Qualifier"])
	}

}
