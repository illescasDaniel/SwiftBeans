import Testing

@testable import SwiftBeansGeneratorCore

@Suite("Accessor spelling — visibility and original evidence")
struct AccessorTypePlannerTests {
	@Test func `Given overlapping views When planned Then synthesized markers do not propagate`() throws {
		let files = [appFile("/App/Types.swift", """
			@Configuration enum Config {
				@Bean(named: "parent") static func parent() -> Pair<P, Q> { fatalError() }
				@Bean(named: "first") static func first() -> Pair<any P, Q> { fatalError() }
				@Bean(named: "second") static func second() -> Pair<P, any Q> { fatalError() }
			}
			""")].map(DeclarationScanner.scan)
		let resolved = ProviderResolver.resolve(files)
		try #require(resolved.diagnostics.isEmpty)
		func provider(_ qualifier: String, owner: String) throws -> GraphProvider {
			let bean = try #require(resolved.providers.first { $0.key.qualifier == qualifier })
			return GraphProvider(owner: owner, bean: bean, inputType: nil)
		}
		let parent = try provider("parent", owner: "Root")
		let first = try provider("first", owner: "First")
		let second = try provider("second", owner: "Second")
		let views = [AccessorTypeView(visible: [parent]),
			AccessorTypeView(visible: [parent, first]), AccessorTypeView(visible: [parent, second])]
		let plan = AccessorTypePlanner.plan(views: views)
		#expect(plan.typesByProvider[parent.id]?.description == "Pair<any P, any Q>")
		#expect(plan.typesByProvider[first.id]?.description == "Pair<any P, Q>")
		#expect(plan.typesByProvider[second.id]?.description == "Pair<P, any Q>")
		#expect(plan.types(ownedBy: "Root")[parent.bean.key] == plan.typesByProvider[parent.id])
		#expect(plan.types(ownedBy: "Missing").isEmpty)
		let reversed = AccessorTypePlanner.plan(views: views.reversed().map {
			AccessorTypeView(visible: Array($0.visible.reversed()))
		})
		#expect(plan.typesByProvider == reversed.typesByProvider)
	}
}
