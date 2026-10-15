import Dispatch
import Foundation
import SwiftBeans
import Synchronization
import Testing

@Suite("SwiftBeansRegistry — SPEC Singleton storage")
struct SwiftBeansRegistryTests {
	final class Token: @unchecked Sendable {}

	/// Thread-safe invocation counter for factories.
	final class Counter: Sendable {
		private let count = Mutex(0)

		func increment() {
			count.withLock { $0 += 1 }
		}

		var value: Int {
			count.withLock { $0 }
		}
	}

	@Test
	func `Given singleton scope When resolved twice Then same instance`() {
		let registry = SwiftBeansRegistry()
		let first = registry.singleton(key: "token") { Token() }
		let second = registry.singleton(key: "token") { Token() }
		#expect(first === second)
	}

	@Test
	func `Given two keys When resolved Then each gets its own instance`() {
		let registry = SwiftBeansRegistry()
		let first = registry.singleton(key: "first") { Token() }
		let second = registry.singleton(key: "second") { Token() }
		#expect(first !== second)
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
			registry.singleton(key: "leaf") { Leaf() }
		}
		func root() -> Root {
			registry.singleton(key: "root") { Root(leaf: leaf()) }
		}

		let first = root()
		let second = root()
		#expect(first === second)
		#expect(first.leaf === second.leaf)
		#expect(first.leaf === leaf())
	}

	@Test
	func `Given concurrent first access When raced Then the factory runs once and every caller shares the instance`() {
		let registry = SwiftBeansRegistry()
		let counter = Counter()
		let results = Mutex<[ObjectIdentifier]>([])

		DispatchQueue.concurrentPerform(iterations: 64) { _ in
			let token = registry.singleton(key: "token") {
				counter.increment()
				Thread.sleep(forTimeInterval: 0.02) // widen the race window
				return Token()
			}
			results.withLock { $0.append(ObjectIdentifier(token)) }
		}

		#expect(counter.value == 1)
		let identifiers = results.withLock { $0 }
		#expect(identifiers.count == 64)
		#expect(Set(identifiers).count == 1)
	}

	@Test
	func `Given concurrent nested resolution When raced Then each factory runs once`() {
		let registry = SwiftBeansRegistry()
		let leafCount = Counter()
		let rootCount = Counter()

		DispatchQueue.concurrentPerform(iterations: 32) { index in
			if index.isMultiple(of: 2) {
				_ = registry.singleton(key: "root") {
					rootCount.increment()
					return registry.singleton(key: "leaf") {
						leafCount.increment()
						Thread.sleep(forTimeInterval: 0.01)
						return Token()
					}
				}
			} else {
				_ = registry.singleton(key: "leaf") {
					leafCount.increment()
					Thread.sleep(forTimeInterval: 0.01)
					return Token()
				}
			}
		}

		#expect(rootCount.value == 1)
		#expect(leafCount.value == 1)
	}

	@Test
	func `Given a slow factory for one key When another key is resolved meanwhile Then it does not wait`() {
		let registry = SwiftBeansRegistry()
		let otherResolved = DispatchSemaphore(value: 0)
		let slowStarted = DispatchSemaphore(value: 0)
		let waitResult = Mutex<DispatchTimeoutResult?>(nil)
		let group = DispatchGroup()

		DispatchQueue.global().async(group: group) {
			_ = registry.singleton(key: "slow") {
				slowStarted.signal()
				// With one global creation lock, "fast" could never be resolved while we wait here.
				waitResult.withLock { $0 = otherResolved.wait(timeout: .now() + 2) }
				return Token()
			}
		}
		DispatchQueue.global().async(group: group) {
			slowStarted.wait()
			_ = registry.singleton(key: "fast") { Token() }
			otherResolved.signal()
		}

		#expect(group.wait(timeout: .now() + 5) == .success)
		#expect(waitResult.withLock { $0 } == .success)
	}

	@Test
	func `Given a factory that resolves its own key When resolved Then the process traps instead of hanging`() async {
		await #expect(processExitsWith: .failure) {
			let registry = SwiftBeansRegistry()
			_ = registry.singleton(key: "self") {
				registry.singleton(key: "self") { 1 }
			}
		}
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
