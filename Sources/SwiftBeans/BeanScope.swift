/// Lifetime of a bean relative to its `@ApplicationContext` instance.
public enum BeanScope: String, Sendable, Codable, Equatable {
	/// One instance per `@ApplicationContext` lifetime.
	case singleton

	/// New instance on every resolve / accessor call.
	case transient
}
