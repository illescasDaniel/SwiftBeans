import SwiftBeans
import Testing

@MainActor
@Service(in: ManagedSession.self)
final class LateSingleton {}

@MainActor
@Service(in: ManagedSession.self, scope: .transient)
final class LateTransient {}

@MainActor
@Service(in: ManagedSession.self)
final class LateAssisted {
	init(@Assisted id: Int) {}
}

@MainActor
@Service(in: ManagedSession.self, scope: .transient)
final class LifecycleFactories {
	let singleton: @MainActor () -> LateSingleton
	let transient: @MainActor () -> LateTransient
	let assisted: @MainActor (Int) -> LateAssisted
	let parent: @MainActor () -> SharedTransport
	let input: @MainActor () -> SessionUser
	init(
		singleton: @escaping @MainActor () -> LateSingleton,
		transient: @escaping @MainActor () -> LateTransient,
		assisted: @escaping @MainActor (Int) -> LateAssisted,
		parent: @escaping @MainActor () -> SharedTransport,
		input: @escaping @MainActor () -> SessionUser
	) {
		self.singleton = singleton
		self.transient = transient
		self.assisted = assisted
		self.parent = parent
		self.input = input
	}
}

private struct LifecycleExitCase: Codable, Sendable {
	var mode: String
	var during: Bool
	static let cases = [false, true].flatMap { during in
		[
			"cached", "unresolved", "transient", "assisted", "protocol", "factory", "factory-transient",
			"factory-assisted", "factory-parent", "factory-input",
		].map { LifecycleExitCase(mode: $0, during: during) }
	}
}

@Suite("Child contexts — resolution preconditions in separate processes", .serialized, .timeLimit(.minutes(1)))
struct ChildContextLifecycleProcessFixtures {
	@MainActor
	private final class Gate {
		var entered = false
		var started: CheckedContinuation<Void, Never>?
		var pending: CheckedContinuation<Void, Never>?
		func wait() async {
			entered = true
			started?.resume()
			started = nil
			await withCheckedContinuation { pending = $0 }
		}
		func waitForEntry() async { if !entered { await withCheckedContinuation { started = $0 } } }
		func release() {
			pending?.resume()
			pending = nil
		}
	}

	@MainActor
	private static func access(_ mode: String, context: ManagedSession, factories: LifecycleFactories) {
		switch mode {
		case "cached": _ = context.sessionRepository
		case "unresolved": _ = context.lateSingleton
		case "transient": _ = context.lateTransient
		case "assisted": _ = context.lateAssisted(id: 1)
		case "protocol":
			let value: any ManagedSessionProtocol = context
			_ = value.sessionRepository
		case "factory": _ = factories.singleton()
		case "factory-transient": _ = factories.transient()
		case "factory-assisted": _ = factories.assisted(1)
		case "factory-parent": _ = factories.parent()
		case "factory-input": _ = factories.input()
		default: preconditionFailure("invalid fixture mode")
		}
	}

	@Test(arguments: LifecycleExitCase.cases)
	private func
		`Given closing or closed graph When resolution escapes through any accessor Then a named precondition traps`(
			_ item: LifecycleExitCase
		) async
	{
		let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
			@MainActor [item = item as LifecycleExitCase] in
			let context = ManagedSession(
				parent: RootContext(), currentUser: SessionUser(id: 1), cleanupInput: CleanupInput())
			let repository = context.sessionRepository as! LiveSessionRepository
			let factories = context.lifecycleFactories
			if item.during {
				let gate = Gate()
				repository.onClose = { await gate.wait() }
				let close = Task { await context.close() }
				await gate.waitForEntry()
				ChildContextLifecycleProcessFixtures.access(
					item.mode, context: context, factories: factories)
				gate.release()
				await close.value
			} else {
				await context.close()
				ChildContextLifecycleProcessFixtures.access(
					item.mode, context: context, factories: factories)
			}
		}
		let stderr = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
		#expect(stderr.contains("cannot resolve from ManagedSession"))
	}

	@Test func `Given cleanup calls its retained factory When close begins Then resolution is rejected`() async {
		let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) {
			@MainActor in
			let context = ManagedSession(
				parent: RootContext(), currentUser: SessionUser(id: 1), cleanupInput: CleanupInput())
			let factories = context.lifecycleFactories
			let repository = context.sessionRepository as! LiveSessionRepository
			repository.onClose = { _ = factories.parent() }
			await context.close()
		}
		let stderr = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
		#expect(stderr.contains("cannot resolve from ManagedSession"))
	}
}
