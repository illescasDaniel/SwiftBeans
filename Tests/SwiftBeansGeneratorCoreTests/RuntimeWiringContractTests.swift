import SwiftBeans
import Testing

@Suite("Runtime wiring — SPEC compile-time-di")
struct RuntimeWiringContractTests {
	final class Token: @unchecked Sendable {}

	@Test
	func `Given singleton scope When resolved twice Then same instance`() {
		let registry = SwiftBeansRegistry()
		let first = registry.singleton(key: "Token") { Token() }
		let second = registry.singleton(key: "Token") { Token() }
		#expect(first === second)
	}

	@Test
	func `Given nested singleton factories When resolved Then dependencies share the registry`() {
		final class Leaf: @unchecked Sendable {}
		final class Root: @unchecked Sendable {
			let leaf: Leaf
			init(leaf: Leaf) { self.leaf = leaf }
		}

		let registry = SwiftBeansRegistry()
		func leaf() -> Leaf {
			registry.singleton(key: "Leaf") { Leaf() }
		}
		func root() -> Root {
			registry.singleton(key: "Root") { Root(leaf: leaf()) }
		}

		let first = root()
		let second = root()
		#expect(first === second)
		#expect(first.leaf === second.leaf)
		#expect(first.leaf === leaf())
	}

	@Test
	func `Given transient scope When resolved twice Then instances differ`() {
		let first = Token()
		let second = Token()
		#expect(first !== second)
	}

	@Test
	func `Given service type When constructed manually Then no context required`() {
		struct UserService {
			var name: String
		}
		let service = UserService(name: "manual")
		#expect(service.name == "manual")
	}
}
