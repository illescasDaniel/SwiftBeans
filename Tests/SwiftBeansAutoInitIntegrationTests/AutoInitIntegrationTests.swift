import Foundation
import SwiftBeans
import Testing

@MainActor
@Suite("Service auto-init — generated graph compiles and wires")
struct AutoInitIntegrationTests {
	// Scenario: coordinator class with private closure dependencies is built with injected factories
	@Test
	func `Given a coordinator with private closure properties When built from the context Then it is built with injected factories`() {
		let context = AutoInitContext()
		let coordinator = context.coordinator
		#expect(coordinator.path.isEmpty)
		#expect(coordinator.selectedTab == 0)
		#expect(coordinator.repository() === context.repository)
		#expect(coordinator.detail(for: Item(id: 7)).item == Item(id: 7))
		#expect(context.coordinator !== coordinator, "transient scope is kept")
	}

	// Scenario: dependency assisted and qualified properties wire the graph and the snake case decoder
	@Test
	func `Given dependency, assisted and qualified properties When the context builds the service Then the graph and the snake case decoder are wired`() throws {
		let context = AutoInitContext()
		let model = context.detailViewModel(item: Item(id: 3))
		#expect(model.item == Item(id: 3))
		#expect(try model.decodeFirstName(#"{"first_name": "Ada"}"#) == "Ada")
		#expect(context.repository.calls == 1)
	}

	// Scenario: direct calls with property names as labels compile
	@Test
	func `Given an auto-init service When it is called directly Then the property names are the labels`() throws {
		let repository = Repository()
		let model = DetailViewModel(repository: repository, item: Item(id: 1), decoder: JSONDecoder())
		#expect(model.item.id == 1)
		let coordinator = Coordinator(makeRepository: { repository }, makeDetail: { _ in model })
		#expect(coordinator.repository() === repository)
	}

	// Scenario: ObservationIgnored property is injected
	@Test
	func `Given an ObservationIgnored property When the context builds the service Then it is injected`() {
		let context = AutoInitContext()
		context.tracker.touch()
		#expect(context.tracker.count == 1)
		#expect(context.repository.calls == 1)
	}

	// Scenario: struct with private properties is injected through the generated init
	@Test
	func `Given a struct with private properties When the context builds it Then it is injected through the generated init`() {
		let context = AutoInitContext()
		context.repository.calls = 5
		#expect(context.reporter.report() == 5)
	}

	// Scenario: actor is constructed through init
	@Test
	func `Given an actor service When the context builds it Then it is constructed through the generated init`() async {
		let context = AutoInitContext()
		let counter = context.counterActor
		#expect(await counter.increment() == "store1")
		#expect(await counter.increment() == "store2")
	}

	// Scenario: wrappers still apply on parameters next to property markers
	@Test
	func `Given wrappers on init parameters next to property markers When the context builds the service Then the wrappers still apply`() {
		let context = AutoInitContext()
		let handWritten = context.handWritten(item: Item(id: 9))
		#expect(handWritten.item == Item(id: 9))
		#expect(handWritten.decoder.keyDecodingStrategy.isSnakeCase)
		let tagged = context.tagged(title: "x")
		#expect(tagged.title == "x")
		#expect(tagged.decoder.keyDecodingStrategy.isSnakeCase)
	}
}

private extension JSONDecoder.KeyDecodingStrategy {
	var isSnakeCase: Bool {
		if case .convertFromSnakeCase = self { return true }
		return false
	}
}
