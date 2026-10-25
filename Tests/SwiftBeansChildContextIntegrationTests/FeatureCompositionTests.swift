import SwiftBeans
import Testing

@MainActor
@Service
final class ParentCleanup: ContextCleanup {
	var closeCount = 0
	nonisolated init() {}
	func close() async { closeCount += 1 }
}

@MainActor
@Service(in: ManagedSession.self)
final class ParentCleanupConsumer {
	let parent: ParentCleanup
	init(parent: ParentCleanup) { self.parent = parent }
}

@MainActor
@Service(in: ManagedSession.self)
final class UnusedCleaner: ContextCleanup {
	let input: CleanupInput
	init(input: CleanupInput) {
		self.input = input
		input.unusedConstructions += 1
	}
	func close() async { input.closeCount += 1 }
}

@MainActor
@Service(in: ManagedSession.self)
final class AssistedCleaner: ContextCleanup {
	var closeCount = 0
	init(@Assisted id: Int) {}
	func close() async { closeCount += 1 }
}

protocol FixtureNote: AnyObject { var label: String { get } }

@Service(named: "app")
final class RootNote: FixtureNote { let label = "app" }

@Service(in: ArcSession.self, named: "child")
final class ArcNote: FixtureNote { let label = "child" }

@Service
final class RootNoteConsumer {
	let notes: [any FixtureNote]
	init(notes: [any FixtureNote]) { self.notes = notes }
}

@Service(in: ArcSession.self)
final class ChildNoteConsumer {
	let notes: [any FixtureNote]
	let rootNote: RootNote
	let root: RootNoteConsumer
	init(notes: [any FixtureNote], @Qualifier("app") rootNote: RootNote, root: RootNoteConsumer) {
		self.notes = notes
		self.rootNote = rootNote
		self.root = root
	}
}

protocol ArrayNote { var label: String { get } }
struct OverrideNote: ArrayNote { let label = "override" }

@Service(in: ArcSession.self)
final class ArrayMember: ArrayNote { let label = "member" }

@Configuration
enum RootArrayConfiguration {
	@Bean static func notes() -> [any ArrayNote] { [OverrideNote()] }
}

@Service(in: ArcSession.self)
final class ArrayConsumer {
	let notes: [any ArrayNote]
	init(notes: [any ArrayNote]) { self.notes = notes }
}

@Suite("Child contexts — shipped feature composition")
struct FeatureCompositionTests {
	@Test
	func `Given visible named members When child resolves Then collections and qualifiers preserve each owner`() {
		let root = RootContext()
		let context = ArcSession(parent: root, currentUser: SessionUser(id: 1))
		let consumer = context.childNoteConsumer
		#expect(consumer.notes.map(\.label) == ["app", "child"])
		#expect(consumer.rootNote === root.appRootNote)
		#expect(consumer.root === root.rootNoteConsumer)
		#expect(consumer.root.notes.map(\.label) == ["app"])
		#expect(consumer.notes[0] === root.appRootNote)
	}

	@Test func `Given a parent array bean When child also has members Then array wins without merging`() {
		let context = ArcSession(parent: RootContext(), currentUser: SessionUser(id: 1))
		#expect(context.arrayConsumer.notes.map(\.label) == ["override"])
	}

	@Test func `Given annotated plain type When manually constructed Then no context is required`() {
		let user = SessionUser(id: 1)
		let counter = ArcCreationCounter()
		let repository = ArcRepository(transport: SharedTransport(), user: user, counter: counter)
		#expect(repository.user === user)
		#expect(counter.value == 1)
	}
}
