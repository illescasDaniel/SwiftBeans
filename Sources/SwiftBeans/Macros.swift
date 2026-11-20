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
///
/// Pass `autoInit: true` to have SwiftBeans generate the initializer from the type's stored properties:
/// stored instance properties without an initial value become parameters (any access level, declaration
/// order, `@escaping` added to function types, `var x: T?` defaults to `nil`). `@Assisted` and
/// `@Qualifier("name")` can mark those properties. The type must not declare an initializer in its body.
/// See "Auto-generated initializers" in the README.
@attached(member, names: named(init))
public macro Service(in owner: Any.Type? = nil, scope: BeanScope = .singleton, autoInit: Bool = false) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// A named `@Service`, injected with `@Qualifier(name)`.
///
/// `autoInit: true` generates the initializer from stored properties; see ``Service(in:scope:autoInit:)``.
@attached(member, names: named(init))
public macro Service(in owner: Any.Type? = nil, named name: String, scope: BeanScope = .singleton, autoInit: Bool = false) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Registers a concrete type under a protocol (or other) injectable key.
///
/// `autoInit: true` generates the initializer from stored properties; see ``Service(in:scope:autoInit:)``.
@attached(member, names: named(init))
public macro Service(in owner: Any.Type? = nil, boundTo: Any.Type, scope: BeanScope = .singleton, autoInit: Bool = false) = #externalMacro(
	module: "SwiftBeansMacros",
	type: "ServiceMacro"
)

/// Registers a concrete type under a protocol (or other) injectable key and a name.
///
/// `autoInit: true` generates the initializer from stored properties; see ``Service(in:scope:autoInit:)``.
@attached(member, names: named(init))
public macro Service(in owner: Any.Type? = nil, boundTo: Any.Type, named name: String, scope: BeanScope = .singleton, autoInit: Bool = false) = #externalMacro(
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

/// Marks a stored property of an `@Service(autoInit: true)` type as a runtime argument.
///
/// This marker macro only applies to stored properties, which can then stay `let`. The generated initializer's
/// parameter carries the same attribute. On initializer or `@Bean` parameters, `@Assisted` resolves to the
/// `Assisted` property wrapper instead. Anywhere else on a property it is a compile-time error.
@attached(peer)
public macro Assisted() = #externalMacro(module: "SwiftBeansMacros", type: "AssistedMarkerMacro")

/// Marks a stored property of an `@Service(autoInit: true)` type as a named dependency.
///
/// `@Qualifier("snakeCase") private let decoder: JSONDecoder` receives the `JSONDecoder` from
/// `@Bean(named: "snakeCase")`. On initializer or `@Bean` parameters, `@Qualifier` resolves to the
/// `Qualifier` property wrapper instead. The name must be a string literal.
@attached(peer)
public macro Qualifier(_ name: String) = #externalMacro(module: "SwiftBeansMacros", type: "QualifierMarkerMacro")
