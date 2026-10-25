/// Selects ARC ownership or explicit, awaited singleton cleanup for a child context.
public enum ChildContextTeardown: String, Sendable {
	case arc
	case managed
}

/// Optional cleanup for child-owned singleton objects in a managed context.
@MainActor
public protocol ContextCleanup: AnyObject {
	func close() async
}

/// Storage and awaited cleanup for one MainActor-isolated managed child.
/// Generated code guards every child-rooted resolution with this registry.
@MainActor
public final class SwiftBeansManagedRegistry {
	private enum State { case open, closing, closed }
	private enum Slot {
		case creating
		case ready(Any)
	}
	private let contextName: String
	private var state = State.open
	private var slots: [String: Slot] = [:]
	private var cleanup: [any ContextCleanup] = []
	private var identities: Set<ObjectIdentifier> = []
	private var closingTask: Task<Void, Never>?

	public init(contextName: String) { self.contextName = contextName }

	/// Inputs stored on the child are intentionally outside this guard.
	public func requireOpen() {
		precondition(state == .open, "cannot resolve from \(contextName): context is closing or closed")
	}

	/// The nonescaping factory runs synchronously on MainActor; it is never retained.
	public func singleton<T>(key: String, create: @MainActor () -> T) -> T {
		requireOpen()
		switch slots[key] {
		case .ready(let value): return value as! T
		case .creating: preconditionFailure("cyclic singleton resolution: '\(key)'")
		case nil: break
		}
		slots[key] = .creating
		let value = create()
		slots[key] = .ready(value)
		if let participant = value as? any ContextCleanup,
			identities.insert(ObjectIdentifier(participant)).inserted
		{
			cleanup.append(participant)
		}
		return value
	}

	/// Repeated callers share completion; cancelling a waiter does not cancel cleanup.
	public func close() async {
		if state == .closed { return }
		if let closingTask {
			await closingTask.value
			return
		}
		state = .closing
		let operation = Task { @MainActor [self] in
			for participant in cleanup.reversed() { await participant.close() }
			slots.removeAll()
			cleanup.removeAll()
			identities.removeAll()
			state = .closed
			closingTask = nil
		}
		closingTask = operation
		await operation.value
	}
}
