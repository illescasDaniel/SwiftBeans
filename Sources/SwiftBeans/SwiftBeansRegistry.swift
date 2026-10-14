import Foundation

/// Per-`@ApplicationContext` instance storage for singleton beans.
///
/// Added to the context type by the `@ApplicationContext` macro as `_swiftBeansRegistry`.
public final class SwiftBeansRegistry: @unchecked Sendable {
	private let lock = NSLock()
	private var storage: [String: Any] = [:]

	public init() {}

	/// Returns the cached instance for `key`, or creates and stores one.
	///
	/// `create` runs **outside** the lock so nested singleton resolution
	/// (a factory that resolves another singleton) does not re-enter the lock
	/// (`NSLock` / `os_unfair_lock` are not recursive).
	public func singleton<T>(key: String, create: () -> T) -> T {
		lock.lock()
		if let existing = storage[key] as? T {
			lock.unlock()
			return existing
		}
		lock.unlock()

		let created = create()

		lock.lock()
		defer { lock.unlock() }
		if let existing = storage[key] as? T {
			return existing
		}
		storage[key] = created
		return created
	}
}
