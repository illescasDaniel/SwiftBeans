/// Marks the root of a compile-time bean graph. Adds `_swiftBeansRegistry` storage.
@attached(member, names: named(_swiftBeansRegistry))
public macro ApplicationContext() = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ApplicationContextMacro"
)

/// Marks a type that declares static `@Bean` factories.
@attached(member)
public macro Configuration() = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ConfigurationMacro"
)

/// Marks a static factory method that provides a bean.
@attached(peer)
public macro Bean(scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "BeanMacro"
)

/// Attribute-only stereotype for a concrete injectable type (discovered by the build plugin).
@attached(member)
public macro Service(scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Registers a concrete type under a protocol (or other) injectable key.
@attached(member)
public macro Service(boundTo: Any.Type, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Marks the initializer the generated graph calls when a `@Service` type has more than one.
@attached(peer)
public macro Inject() = #externalMacro(
	module: "SwiftBeansMacros",
	type: "InjectMacro"
)
