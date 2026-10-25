import Dispatch
import SwiftBeans
import Synchronization
import Testing

@Service
final class ArcCreationCounter: Sendable {
	private let storage = Mutex(0)
	func increment() { storage.withLock { $0 += 1 } }
	var value: Int { storage.withLock { $0 } }
}

@Service(scope: .transient)
final class SharedValidator {}

@Service(in: ArcSession.self, scope: .transient)
final class ArcReport {
	let validator: SharedValidator
	init(validator: SharedValidator) { self.validator = validator }
}

@MainActor
final class CleanupLedger { var closes = 0 }

@MainActor
@ChildContext(of: RootContext.self)
final class DefaultArcSession {
	@ContextInput let ledger: CleanupLedger
}

@MainActor
@Service(in: DefaultArcSession.self)
final class ArcCleanup: ContextCleanup {
	let ledger: CleanupLedger
	init(ledger: CleanupLedger) { self.ledger = ledger }
	func close() async { ledger.closes += 1 }
}

@Suite("Child contexts — ownership limits and ARC baseline")
struct AdditionalLifetimeTests {
	@Test func `Given a parent transient When child resolves twice Then instances stay transient`() {
		let context = ArcSession(parent: RootContext(), currentUser: SessionUser(id: 1))
		let first = context.arcReport
		let second = context.arcReport
		#expect(first !== second)
		#expect(first.validator !== second.validator)
	}

	/// Test-only harness: immutable fixture fields plus the registry synchronize all shared access.
	/// This does not add a Sendable promise to a context or bean in the library.
	private final class ConcurrentAccess: @unchecked Sendable {
		let context: ArcSession
		let identities = Mutex<Set<ObjectIdentifier>>([])
		init(_ context: ArcSession) { self.context = context }
		func resolve() {
			let identity = ObjectIdentifier(context.arcRepository)
			identities.withLock { _ = $0.insert(identity) }
		}
	}

	@Test func `Given concurrent first access to an ARC child When resolved Then construction runs exactly once`() {
		let root = RootContext()
		let access = ConcurrentAccess(ArcSession(parent: root, currentUser: SessionUser(id: 1)))
		DispatchQueue.concurrentPerform(iterations: 64) { _ in access.resolve() }
		#expect(access.identities.withLock { $0.count } == 1)
		#expect(root.arcCreationCounter.value == 1)
	}

	@MainActor @Test func `Given ARC default When a participating object is released Then no async callback runs`()
	{
		let ledger = CleanupLedger()
		var context: DefaultArcSession? = DefaultArcSession(parent: RootContext(), ledger: ledger)
		weak let object = context!.arcCleanup
		#expect(object != nil)
		context = nil
		#expect(object == nil)
		#expect(ledger.closes == 0)
	}

	@MainActor @Test
	func `Given an unclosed managed child When last ownership ends Then no asynchronous fallback is scheduled`() {
		let ledger = CleanupLedger()
		var context: ManagedSession? = ManagedSession(
			parent: RootContext(), currentUser: SessionUser(id: 1), cleanupInput: CleanupInput())
		weak let repository = context!.sessionRepository as? LiveSessionRepository
		repository?.onClose = { ledger.closes += 1 }
		context = nil
		#expect(repository == nil)
		#expect(ledger.closes == 0)
	}

	@MainActor @Test
	func `Given closed context still retained When only it owns parent and inputs Then their ownership continues`()
		async
	{
		var parent: RootContext? = RootContext()
		var user: SessionUser? = SessionUser(id: 1)
		var input: CleanupInput? = CleanupInput()
		var context: ManagedSession? = ManagedSession(parent: parent!, currentUser: user!, cleanupInput: input!)
		weak let weakParent = parent
		weak let weakUser = user
		weak let weakInput = input
		parent = nil
		user = nil
		input = nil
		await context!.close()
		#expect(weakParent != nil && weakUser != nil && weakInput != nil)
		#expect(context!.currentUser.id == 1)
		#expect(weakInput?.closeCount == 0)
		context = nil
		#expect(weakParent == nil && weakUser == nil && weakInput == nil)
	}
}
