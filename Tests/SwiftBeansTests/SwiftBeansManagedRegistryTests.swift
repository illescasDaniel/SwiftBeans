import SwiftBeans
import Testing

@Suite("Child contexts — managed singleton lifecycle")
@MainActor
struct SwiftBeansManagedRegistryTests {
	final class Events { var values: [String] = [] }
	final class Token: ContextCleanup {
		let name: String
		let events: Events
		var action: (@MainActor () async -> Void)?
		init(_ name: String, _ events: Events) {
			self.name = name
			self.events = events
		}
		func close() async {
			events.values.append(name)
			await action?()
		}
	}
	final class Gate {
		var entered = false
		var started: CheckedContinuation<Void, Never>?
		var resume: CheckedContinuation<Void, Never>?
		func signalEntry() {
			entered = true
			started?.resume()
			started = nil
		}
		func wait() async {
			signalEntry()
			await withCheckedContinuation { resume = $0 }
		}
		func waitForEntry() async {
			if !entered { await withCheckedContinuation { started = $0 } }
		}
		func release() {
			resume?.resume()
			resume = nil
		}
	}

	@Test func `Given a singleton When resolved twice Then creation occurs once`() {
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let events = Events()
		var calls = 0
		let first = registry.singleton(key: "token") {
			calls += 1
			return Token("one", events)
		}
		let second = registry.singleton(key: "token") {
			calls += 1
			return Token("two", events)
		}
		#expect(first === second)
		#expect(calls == 1)
	}

	@Test
	func `Given nested and aliased singletons When closed Then cleanup is reverse creation and once per object`()
		async
	{
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let events = Events()
		let outer = registry.singleton(key: "outer") {
			_ = registry.singleton(key: "inner") { Token("inner", events) }
			return Token("outer", events)
		}
		_ = registry.singleton(key: "alias") { outer }
		await registry.close()
		await registry.close()
		#expect(events.values == ["outer", "inner"])
	}

	@Test func `Given cached objects When cleanup finishes Then cache ownership is released`() async {
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let events = Events()
		weak var weakToken: Token?
		do {
			let token = registry.singleton(key: "token") { Token("one", events) }
			weakToken = token
		}
		#expect(weakToken != nil)
		await registry.close()
		#expect(weakToken == nil)
		#expect(events.values == ["one"])
	}

	@Test func `Given an escaped object When context closes Then cleanup precedes object deallocation`() async {
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let events = Events()
		var escaped: Token? = registry.singleton(key: "token") { Token("one", events) }
		weak var weakToken = escaped
		await registry.close()
		#expect(events.values == ["one"])
		#expect(weakToken != nil)
		escaped = nil
		#expect(weakToken == nil)
	}

	@Test
	func `Given a dropped unclosed registry When objects have no other owner Then ARC releases without callbacks`()
	{
		let events = Events()
		weak var weakToken: Token?
		do {
			let registry = SwiftBeansManagedRegistry(contextName: "Session")
			let token = registry.singleton(key: "token") { Token("one", events) }
			weakToken = token
		}
		#expect(weakToken == nil)
		#expect(events.values.isEmpty)
	}

	@Test(arguments: [false, true])
	func `Given suspended cleanup When callers repeat or cancel Then all await one uncancelled operation`(
		_ cancelSecond: Bool
	) async {
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let events = Events()
		let gate = Gate()
		let token = registry.singleton(key: "token") { Token("one", events) }
		token.action = {
			await gate.wait()
			#expect(!Task.isCancelled)
		}
		var finished = 0
		let first = Task {
			await registry.close()
			finished += 1
		}
		await gate.waitForEntry()
		let secondEntry = Gate()
		let second = Task {
			secondEntry.signalEntry()
			await registry.close()
			finished += 1
		}
		await secondEntry.waitForEntry()
		first.cancel()
		if cancelSecond { second.cancel() }
		#expect(finished == 0)
		#expect(events.values == ["one"])
		gate.release()
		await first.value
		await second.value
		await registry.close()
		#expect(finished == 2)
		#expect(events.values == ["one"])
	}
	@Test func `Given a retained nonparticipating singleton When closed Then arbitrary methods remain untouched`()
		async
	{
		final class PlainObject { var value = 42 }
		let registry = SwiftBeansManagedRegistry(contextName: "Session")
		let object = registry.singleton(key: "plain") { PlainObject() }
		await registry.close()
		#expect(object.value == 42)
		object.value += 1
		#expect(object.value == 43)
	}

}
