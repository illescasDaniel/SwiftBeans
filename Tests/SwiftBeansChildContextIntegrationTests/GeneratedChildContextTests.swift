import SwiftBeans
import Testing

@ApplicationContext
final class RootContext {}

@Service
final class SharedTransport {}

final class SessionUser {
	let id: Int
	init(id: Int) { self.id = id }
}

@ChildContext(of: RootContext.self)
final class ArcSession {
	@ContextInput let currentUser: SessionUser
}

@Service(in: ArcSession.self)
final class ArcRepository {
	let transport: SharedTransport
	let user: SessionUser
	init(transport: SharedTransport, user: SessionUser, counter: ArcCreationCounter) {
		self.transport = transport
		self.user = user
		counter.increment()
	}
}

@MainActor
final class CleanupInput: ContextCleanup {
	var closeCount = 0
	var unusedConstructions = 0
	func close() async { closeCount += 1 }
}

@MainActor
@ChildContext(of: RootContext.self, teardown: .managed)
final class ManagedSession {
	@ContextInput let currentUser: SessionUser
	@ContextInput let cleanupInput: CleanupInput
}

@MainActor
protocol SessionRepository: AnyObject {
	var user: SessionUser { get }
	var transport: SharedTransport { get }
	var closeCount: Int { get }
}

@MainActor
@Service(in: ManagedSession.self, boundTo: SessionRepository.self)
final class LiveSessionRepository: SessionRepository, ContextCleanup {
	let user: SessionUser
	let transport: SharedTransport
	var closeCount = 0
	var onClose: (@MainActor () async -> Void)?
	init(user: SessionUser, transport: SharedTransport) {
		self.user = user
		self.transport = transport
	}
	func close() async {
		closeCount += 1
		await onClose?()
	}
}

@MainActor
@Service(in: ManagedSession.self, scope: .transient)
final class SessionModel {
	let repository: any SessionRepository
	init(repository: any SessionRepository) { self.repository = repository }
}

@MainActor
@Service(in: ManagedSession.self)
final class SessionDetail {
	let repository: any SessionRepository
	let id: Int
	init(repository: any SessionRepository, @Assisted id: Int) {
		self.repository = repository
		self.id = id
	}
}

@MainActor
@Service(in: ManagedSession.self, scope: .transient)
final class SessionCoordinator {
	let makeModel: @MainActor () -> SessionModel
	let makeDetail: @MainActor (Int) -> SessionDetail
	let makeParent: @MainActor () -> SharedTransport
	init(
		makeModel: @escaping @MainActor () -> SessionModel,
		makeDetail: @escaping @MainActor (Int) -> SessionDetail,
		makeParent: @escaping @MainActor () -> SharedTransport
	) {
		self.makeModel = makeModel
		self.makeDetail = makeDetail
		self.makeParent = makeParent
	}
}

@MainActor
@Service(in: ManagedSession.self, scope: .transient)
final class TransientCleaner: ContextCleanup {
	var closeCount = 0
	func close() async { closeCount += 1 }
}

final class FakeRootContext: RootContextProtocol {
	let arcCreationCounter = ArcCreationCounter()
	var sharedValidator: SharedValidator { SharedValidator() }
	let sharedTransport = SharedTransport()
	let parentCleanup = ParentCleanup()
	let appRootNote = RootNote()
	var rootNoteConsumer: RootNoteConsumer { RootNoteConsumer(notes: [appRootNote]) }
	var arrayNoteArray: [any ArrayNote] { RootArrayConfiguration.notes() }
}

@Suite("Child contexts — real macro and plugin graph")
struct GeneratedChildContextTests {
	@Test func `Given two ARC children When resolved Then parent shared and own singleton identities are correct`()
	{
		let root = RootContext()
		let user = SessionUser(id: 1)
		let first = ArcSession(parent: root, currentUser: user)
		let second = ArcSession(parent: root, currentUser: SessionUser(id: 2))
		#expect(first.arcRepository === first.arcRepository)
		#expect(first.arcRepository !== second.arcRepository)
		#expect(first.arcRepository.user === user)
		#expect(first.arcRepository.transport === root.sharedTransport)
		#expect(second.arcRepository.transport === root.sharedTransport)
	}

	@Test func `Given ARC child When ownership ends Then its cache and retained parent are released`() {
		var root: RootContext? = RootContext()
		weak let parent = root
		var child: ArcSession? = ArcSession(parent: root!, currentUser: SessionUser(id: 1))
		weak let repository = child!.arcRepository
		root = nil
		#expect(parent != nil)
		#expect(repository != nil)
		child = nil
		#expect(parent == nil)
		#expect(repository == nil)
	}

	@MainActor @Test
	func
		`Given a fake parent When managed factories run Then real generated accessors preserve scope and cleanup ownership`()
		async
	{
		let parent = FakeRootContext()
		let input = CleanupInput()
		let context = ManagedSession(parent: parent, currentUser: SessionUser(id: 1), cleanupInput: input)
		let coordinator = context.sessionCoordinator
		let first = coordinator.makeModel()
		let second = coordinator.makeModel()
		#expect(first !== second)
		#expect(first.repository === second.repository)
		#expect(first.repository.transport === parent.sharedTransport)
		#expect(coordinator.makeParent() === parent.sharedTransport)
		#expect(coordinator.makeDetail(42).id == 42)
		#expect(coordinator.makeDetail(1) !== coordinator.makeDetail(1))
		let transient = context.transientCleaner
		let assisted = context.assistedCleaner(id: 1)
		let parentCleaner = context.parentCleanupConsumer.parent
		let protocolValue: any ManagedSessionProtocol = context
		await protocolValue.close()
		await protocolValue.close()
		#expect(first.repository.closeCount == 1)
		#expect(transient.closeCount == 0)
		#expect(input.closeCount == 0)
		#expect(input.unusedConstructions == 0)
		#expect(assisted.closeCount == 0)
		#expect(parentCleaner.closeCount == 0)
		#expect(context.currentUser.id == 1)
	}

	@MainActor @Test
	func `Given a flow ownership chain When close and release finish Then factories do not form a registry cycle`()
		async
	{
		let parent = FakeRootContext()
		var context: ManagedSession? = ManagedSession(
			parent: parent, currentUser: SessionUser(id: 1), cleanupInput: CleanupInput())
		var coordinator: SessionCoordinator? = context!.sessionCoordinator
		weak let weakContext = context
		weak let weakCoordinator = coordinator
		weak var weakRepository: AnyObject?
		do {
			let model = coordinator!.makeModel()
			weakRepository = model.repository
		}
		await context!.close()
		context = nil
		#expect(
			weakContext != nil,
			"factory closures retain the context until the transient coordinator is released")
		coordinator = nil
		#expect(weakContext == nil)
		#expect(weakCoordinator == nil)
		#expect(weakRepository == nil)
	}
}
