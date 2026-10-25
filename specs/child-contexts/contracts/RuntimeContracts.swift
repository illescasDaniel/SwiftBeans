// Phase 2 contract snapshot. Not compiled into the product; stub methods must not run.
public enum ChildContextTeardown: String, Sendable {
	case arc
	case managed
}

@MainActor
public protocol ContextCleanup: AnyObject {
	func close() async
}

// Signatures only: this is not a lifecycle implementation.
@MainActor
public final class SwiftBeansManagedRegistry {
	public init(contextName: String) {}

	public func requireOpen() {
		fatalError("Contract stub")
	}

	public func singleton<T>(key: String, create: @MainActor () -> T) -> T {
		fatalError("Contract stub")
	}

	public func close() async {
		fatalError("Contract stub")
	}
}

// Compiler-only shapes for participation casts and actor-inheriting cleanup tasks.
// These functions are not a registry implementation and are never executed.
@MainActor
private func cleanupParticipant<T>(_ value: T) -> (any ContextCleanup)? {
	value as? any ContextCleanup
}

@MainActor
private func cleanupTaskShape(
	callbacks: [any ContextCleanup],
	completion: @escaping @MainActor () -> Void
) -> Task<Void, Never> {
	Task { @MainActor in
		for callback in callbacks.reversed() {
			await callback.close()
		}
		completion()
	}
}
