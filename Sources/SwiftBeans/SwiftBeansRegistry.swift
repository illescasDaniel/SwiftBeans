import Foundation

/// Per-`@ApplicationContext` instance storage for singleton beans.
///
/// Added to the context type by the `@ApplicationContext` macro as `_swiftBeansRegistry`.
///
/// The registry's own state is thread-safe. Beans need not be `Sendable`: whether a bean may be
/// shared across actors follows the context's isolation and is the caller's responsibility.
public final class SwiftBeansRegistry: @unchecked Sendable {
	private enum Slot {
		case creating(owner: pthread_t)
		case ready(Any)
	}

	private let condition = NSCondition()
	private var slots: [String: Slot] = [:]

	public init() {}

	/// Returns the instance for `key`, creating it with `create` at most once per registry.
	///
	/// Concurrent first callers wait for the one creating thread. `create` runs without the lock
	/// held, so it may resolve other singletons, and unrelated keys never wait on each other.
	/// Resolving a key from inside its own factory is a cycle and traps.
	public func singleton<T>(key: String, create: () -> T) -> T {
		condition.lock()
		while true {
			switch slots[key] {
			case .ready(let value):
				condition.unlock()
				return value as! T
			case .creating(let owner):
				if pthread_equal(owner, pthread_self()) != 0 {
					condition.unlock()
					preconditionFailure("cyclic singleton resolution: '\(key)'")
				}
				condition.wait()
			case nil:
				slots[key] = .creating(owner: pthread_self())
				condition.unlock()

				let value = create()

				condition.lock()
				slots[key] = .ready(value)
				condition.broadcast()
				condition.unlock()
				return value
			}
		}
	}
}
