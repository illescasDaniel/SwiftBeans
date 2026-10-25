// Declaration contract snapshot, not compiled into the SwiftBeans product.
// ChildContextTeardown and BeanScope resolve from the runtime at implementation time.

@attached(member, names: named(_swiftBeansRegistry), named(_swiftBeansParent), named(init), named(close))
public macro ChildContext(
	of parent: Any.Type,
	teardown: ChildContextTeardown = .arc
) = #externalMacro(module: "SwiftBeansMacros", type: "ChildContextMacro")

@attached(peer)
public macro ContextInput() = #externalMacro(module: "SwiftBeansMacros", type: "ContextInputMacro")

@attached(member)
public macro Configuration(in owner: Any.Type? = nil) = #externalMacro(
	module: "SwiftBeansMacros", type: "ConfigurationMacro"
)

@attached(peer)
public macro Bean(in owner: Any.Type? = nil, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros", type: "BeanMacro"
)

@attached(peer)
public macro Bean(in owner: Any.Type? = nil, named name: String, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros", type: "BeanMacro"
)

@attached(member)
public macro Service(in owner: Any.Type? = nil, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros", type: "ServiceMacro"
)

@attached(member)
public macro Service(in owner: Any.Type? = nil, named name: String, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros", type: "ServiceMacro"
)

@attached(member)
public macro Service(in owner: Any.Type? = nil, boundTo: Any.Type, scope: BeanScope = .singleton) = #externalMacro(
	module: "SwiftBeansMacros", type: "ServiceMacro"
)

@attached(member)
public macro Service(
	in owner: Any.Type? = nil,
	boundTo: Any.Type,
	named name: String,
	scope: BeanScope = .singleton
) = #externalMacro(module: "SwiftBeansMacros", type: "ServiceMacro")
