/// Marks the root of a compile-time bean graph. Adds `_swiftBeansRegistry` storage.
@attached(member, names: named(_swiftBeansRegistry))
public macro ApplicationContext() = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ApplicationContextMacro"
)

/// Marks a type that declares static `@Bean` factories.
@attached(member)
public macro Configuration(in owner: Any.Type? = nil) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ConfigurationMacro"
)

/// Marks a static factory method that provides a bean.
@attached(peer)
public macro Bean(in owner: Any.Type? = nil, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "BeanMacro"
)

/// Marks a static factory method that provides a named bean, injected with `@Qualifier(name)`.
///
/// `name` must be a string literal shaped like an identifier; the accessor is `name` + type (`snakeCaseJSONDecoder`).
@attached(peer)
public macro Bean(in owner: Any.Type? = nil, named name: String, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "BeanMacro"
)

/// Attribute-only stereotype for a concrete injectable type (discovered by the build plugin).
@attached(member)
public macro Service(in owner: Any.Type? = nil, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// A named `@Service`, injected with `@Qualifier(name)`.
@attached(member)
public macro Service(in owner: Any.Type? = nil, named name: String, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Registers a concrete type under a protocol (or other) injectable key.
@attached(member)
public macro Service(in owner: Any.Type? = nil, boundTo: Any.Type, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Registers a concrete type under a protocol (or other) injectable key and a name.
@attached(member)
public macro Service(in owner: Any.Type? = nil, boundTo: Any.Type, named name: String, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Marks the initializer the generated graph calls when a `@Service` type has more than one.
@attached(peer)
public macro Inject() = #externalMacro(
	module: "SwiftBeansMacros",
	type: "InjectMacro"
)

/// A runtime-created child graph over one application context.
@attached(member, names: named(_swiftBeansRegistry), named(_swiftBeansParent), named(init), named(close))
public macro ChildContext(of parent: Any.Type, teardown: ChildContextTeardown = .arc) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ChildContextMacro"
)

/// A stored input supplied to the child's generated initializer.
@attached(peer)
public macro ContextInput() = #externalMacro(module: "SwiftBeansMacros", type: "ContextInputMacro")
