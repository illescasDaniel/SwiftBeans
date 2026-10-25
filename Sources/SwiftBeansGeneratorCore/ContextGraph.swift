import Foundation
import SwiftBeansSyntaxRules

struct OwnerReference {
	var name: String
	var lexicalScope: String
	var location: SourcePosition
}

struct ContextInputDecl {
	var name: String
	var typeSpelling: String
	var key: BeanKey
	var emittedType: EmittedType
	var spelledWithAny: Bool
	var location: SourcePosition
}

struct ChildContextDecl {
	var context: ContextDecl
	var parent: OwnerReference
	var teardown: TeardownLiteral
	var inputs: [ContextInputDecl]
}

struct ProviderID: Hashable {
	var owner: String
	var key: BeanKey
}

/// A provider remains owned once; visibility views only retain references to its record.
struct GraphProvider {
	var owner: String
	var bean: BeanProvider
	var inputType: String?
	var id: ProviderID { ProviderID(owner: owner, key: bean.key) }
	var accessorName: String {
		if case .contextInput(let name) = bean.construction { return name }
		return bean.key.accessorName
	}
}

struct ResolvedParameterBinding {
	var injection: Injection?
	var factory: FactoryBinding?
}

struct ContextCodePlan {
	var context: ContextDecl
	var parent: ContextDecl?
	var isManaged: Bool
	var own: [GraphProvider]
	var visible: [GraphProvider]
	var isMainActor: Bool { context.isMainActor }
	let accessorNames: [BeanKey: String]
	let beans: [BeanProvider]
	let injection: ParameterInjection
	let bindings: [SourcePosition: ResolvedParameterBinding]
	private let providersByKey: [BeanKey: GraphProvider]

	init(
		context: ContextDecl, parent: ContextDecl?, isManaged: Bool, own: [GraphProvider],
		visible: [GraphProvider]
	) {
		self.context = context
		self.parent = parent
		self.isManaged = isManaged
		self.own = own
		self.visible = visible
		accessorNames = Dictionary(
			visible.map { ($0.bean.key, $0.accessorName) }, uniquingKeysWith: { first, _ in first })
		beans = visible.map(\.bean)
		providersByKey = Dictionary(visible.map { ($0.bean.key, $0) }, uniquingKeysWith: { first, _ in first })
		let injection = ParameterInjection(
			beans, accessorNames: accessorNames,
			owners: Dictionary(
				visible.map { ($0.bean.key, $0.owner) }, uniquingKeysWith: { first, _ in first }))
		self.injection = injection
		let byKey = Dictionary(beans.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
		let positions = Dictionary(
			beans.enumerated().map { ($0.element.key, $0.offset) }, uniquingKeysWith: { first, _ in first })
		var bindings: [SourcePosition: ResolvedParameterBinding] = [:]
		for provider in own {
			let index = positions[provider.bean.key]!
			for parameter in provider.bean.parameters {
				bindings[parameter.location] = ResolvedParameterBinding(
					injection: injection.injection(for: parameter, of: index),
					factory: parameter.factory.map {
						FactoryBinding.resolve($0, providersByKey: { byKey[BeanKey($0)] })
					}
				)
			}
		}
		self.bindings = bindings
	}
	func path(_ key: BeanKey) -> String {
		guard let provider = providersByKey[key] else { preconditionFailure("unplanned provider") }
		return (provider.owner == context.name ? "self." : "self._swiftBeansParent.") + provider.accessorName
	}
	func typeSpelling(_ provider: BeanProvider) -> String? { own.first { $0.bean.key == provider.key }?.inputType }
}

/// Partitions one scan into owner-qualified plans. The legacy root-only path never enters here.
enum ContextGraph {
	static func generate(files: [ScannedFile], providers: [BeanProvider], initialDiagnostics: [GeneratorDiagnostic])
		-> GenerationResult
	{
		var diagnostics = initialDiagnostics + files.flatMap(\.contextDiagnostics)
		let roots = files.filter { $0.source.origin == .target }.flatMap(\.contexts)
		let children = files.filter { $0.source.origin == .target }.flatMap(\.children).sorted {
			$0.context.name < $1.context.name
		}
		func error(_ id: String, _ at: SourcePosition, _ message: String) {
			diagnostics.append(GeneratorDiagnostic(id: id, location: at, message: message))
		}
		guard roots.count == 1 else {
			if roots.isEmpty {
				let at =
					children.first?.context.location ?? files.first!.contextDiagnostics.first?
					.location ?? SourcePosition(file: files.first!.source.path, line: 1, column: 1)
				error(
					"context.missingRoot", at,
					"child context features require one @ApplicationContext in the target")
			}
			return failed(diagnostics)
		}
		let childNames = Set(children.map { $0.context.name })
		for ext in files.flatMap(\.extensions) where childNames.contains(ext.extendedName) {
			for initializer in ext.initializers {
				error(
					"context.customInitializer", initializer.location,
					"@ChildContext owns its initializer; remove the handwritten initializer from the extension"
				)
			}
		}
		let root = roots[0]
		let contexts = [root] + children.map(\.context)
		let declaredTypes = Set(files.filter { $0.source.origin == .target }.flatMap(\.types).map(\.name))
		for context in contexts where declaredTypes.contains(context.simpleName + "Protocol") {
			error(
				"context.protocolCollision", context.location,
				"generated protocol '\(context.simpleName)Protocol' conflicts with a declared type")
		}
		for group in Dictionary(grouping: contexts, by: { $0.simpleName }).values where group.count > 1 {
			for context in group {
				error(
					"context.protocolCollision", context.location,
					"generated protocol '\(context.simpleName)Protocol' conflicts with another context"
				)
			}
		}
		func resolve(_ reference: OwnerReference) -> ContextDecl? {
			var scope = reference.lexicalScope.split(separator: ".").map(String.init)
			while true {
				let name = (scope + [reference.name]).joined(separator: ".")
				if let exact = contexts.first(where: { $0.name == name }) { return exact }
				// A nearer ordinary type shadows a same-named outer context in Swift too.
				if declaredTypes.contains(name) { return nil }
				if scope.isEmpty { break }
				scope.removeLast()
			}
			let matches = contexts.filter { reference.name.hasSuffix("." + $0.name) }
			return matches.count == 1 ? matches.first : nil
		}
		func needsWitness(_ reference: OwnerReference, _ target: ContextDecl) -> Bool {
			var scope = reference.lexicalScope.split(separator: ".").map(String.init)
			while true {
				if (scope + [reference.name]).joined(separator: ".") == target.name { return false }
				if scope.isEmpty { break }
				scope.removeLast()
			}
			return true
		}
		var witnesses: [(String, OwnerReference, ContextDecl)] = []
		for child in children {
			guard let parent = resolve(child.parent), parent.name == root.name else {
				error(
					"context.invalidParent", child.parent.location,
					"parent of '\(child.context.name)' must be the target's @ApplicationContext; nested/cyclic children are unsupported"
				)
				continue
			}
			if needsWitness(child.parent, parent) {
				witnesses.append((child.context.name, child.parent, parent))
			}
		}
		let owners = files.reduce(into: [SourcePosition: OwnerReference]()) {
			$0.merge($1.owners, uniquingKeysWith: { first, _ in first })
		}
		let defaults = files.reduce(into: [String: OwnerReference]()) {
			$0.merge($1.configurationOwners, uniquingKeysWith: { first, _ in first })
		}
		for reference in Array(owners.values) + Array(defaults.values) where resolve(reference) == nil {
			error(
				"context.invalidOwner", reference.location,
				"'\(reference.name)' is not a context in this target")
		}
		for type in defaults.keys.sorted() {
			let reference = defaults[type]!
			if let owner = resolve(reference), needsWitness(reference, owner) {
				witnesses.append((type, reference, owner))
			}
		}
		var graph: [GraphProvider] = []
		for bean in providers {
			let declaringType: String
			switch bean.construction {
			case .initializer(let type), .staticMethod(let type, _): declaringType = type
			case .contextInput: preconditionFailure("inputs are assigned below")
			}
			let reference = owners[bean.location] ?? defaults[declaringType]
			let owner: ContextDecl
			if let reference {
				guard let resolved = resolve(reference) else {
					error(
						"context.invalidOwner", reference.location,
						"'\(reference.name)' is not a context in this target")
					continue
				}
				owner = resolved
				if owner.name != root.name, case .localPackage = bean.origin {
					error(
						"context.packageOwner", reference.location,
						"child-owned providers must live in the app target")
					continue
				}
				if owners[bean.location] != nil && needsWitness(reference, owner) {
					witnesses.append((declaringType, reference, owner))
				}
			} else {
				owner = root
			}
			graph.append(GraphProvider(owner: owner.name, bean: bean))
		}
		var inheritance: [String: [TypeKey]] = [:]
		for file in files {
			for type in file.types { inheritance[type.name, default: []] += type.inheritedTypes }
			for ext in file.extensions { inheritance[ext.extendedName, default: []] += ext.inheritedTypes }
		}
		for child in children {
			for input in child.inputs {
				var conformances: Set<TypeKey> = []
				var pending = [input.key.type]
				while let key = pending.popLast() {
					for inherited in inheritance[key.description] ?? []
					where conformances.insert(inherited).inserted { pending.append(inherited) }
				}
				let bean = BeanProvider(
					key: input.key, emittedType: input.emittedType, spelledWithAny: input.spelledWithAny, scope: .singleton,
					origin: .target, location: input.location,
					displayName: "\(child.context.name).\(input.name)",
					construction: .contextInput(propertyName: input.name), parameters: [],
					conformances: conformances)
				graph.append(
					GraphProvider(
						owner: child.context.name, bean: bean, inputType: input.typeSpelling))
			}
		}
		annotateDefinitionDiagnostics(&diagnostics, files: files, graph: graph) { location, type in
			let reference = owners[location] ?? defaults[type]
			return reference.flatMap(resolve)?.name ?? root.name
		}
		var plans: [ContextCodePlan] = []
		for context in contexts {
			let child = children.first { $0.context.name == context.name }
			let own = graph.filter { $0.owner == context.name }
			let visible = graph.filter {
				$0.owner == context.name || (child != nil && $0.owner == root.name)
			}.sorted { ($0.bean.key, $0.bean.location) < ($1.bean.key, $1.bean.location) }
			let plan = ContextCodePlan(
				context: context, parent: child == nil ? nil : root,
				isManaged: child?.teardown == .managed, own: own, visible: visible)
			var errors = GraphValidator.validate(
				plan.beans, consumerKeys: Set(own.map { $0.bean.key }),
				accessorNames: plan.accessorNames, bindings: plan.bindings)
			for index in errors.indices {
				if errors[index].id == "graph.missingDependency" {
					let parameter = own.flatMap { $0.bean.parameters }.first {
						$0.location == errors[index].location
					}
					let key = parameter?.key ?? parameter?.factory.map { BeanKey($0.returnKey) }
					let other = graph.filter { candidate in
						candidate.bean.key == key
							&& !visible.contains(where: { $0.id == candidate.id })
					}
					if !other.isEmpty {
						errors[index].id = "graph.contextVisibility"
						errors[index].message +=
							"; provided only by \(Set(other.map(\.owner)).sorted().joined(separator: ", ")), not visible from \(context.name) (shorter-lived or sibling context)"
					} else {
						errors[index].message +=
							"; visible contexts checked: \(context.name), inputs\(child == nil ? "" : ", " + root.name)"
					}
				}
			}
			for index in errors.indices
			where errors[index].id != "graph.missingDependency"
				&& errors[index].id != "graph.contextVisibility"
			{
				if errors[index].id == "graph.duplicateProvider",
					let offending = visible.first(where: {
						$0.bean.location == errors[index].location
					})
				{
					let owners = Set(
						visible.filter { $0.bean.key == offending.bean.key }.map(\.owner)
					).sorted()
					errors[index].message += "; owning contexts: " + owners.joined(separator: ", ")
				} else {
					errors[index].message += "; context: " + context.name
				}
			}
			diagnostics += errors
			for provider in own
			where provider.accessorName.hasPrefix("_swiftBeans")
				|| (plan.isManaged && provider.accessorName == "close")
			{
				error(
					"context.reservedName", provider.bean.location,
					"'\(provider.accessorName)' conflicts with a generated context member")
			}
			plans.append(plan)
		}
		if diagnostics.contains(where: { $0.severity == .error }) { return failed(diagnostics) }
		var imports = files.flatMap(\.imports)
		for provider in providers {
			if case .localPackage(let module) = provider.origin {
				imports.append(
					ImportRecord(
						module: module, testable: false, preconcurrency: false, condition: nil))
			}
		}
		let accessorTypes = AccessorTypePlanner.plan(views: plans.map { AccessorTypeView(visible: $0.visible) })
		var output = CodeGenerator.header + "\n" + CodeGenerator.importBlock(imports) + "\n"
		for plan in plans {
			let generated = CodeGenerator.generate(
				context: plan.context, providers: plan.own.map(\.bean), imports: [],
				accessorTypes: accessorTypes.types(ownedBy: plan.context.name), plan: plan,
				includePreamble: false)
			output += generated + "\n"
		}
		for (index, witness) in witnesses.enumerated() {
			let (type, reference, target) = witness
			output +=
				"extension \(type) {\n#sourceLocation(file: \(reference.location.file.debugDescription), line: \(reference.location.line))\n\tprivate static func _swiftBeansValidateContextReference\(index)() {\n\t\tlet _: (\(reference.name)) -> \(target.name) = { $0 }\n\t\tlet _: (\(target.name)) -> \(reference.name) = { $0 }\n\t}\n#sourceLocation()\n}\n"
		}
		return GenerationResult(
			diagnostics: sorted(diagnostics), output: output,
			graphMarkdown: ContextGraphDump.markdown(plans), graphDot: ContextGraphDump.dot(plans))
	}

	/// Resolver errors can precede graph planning; preserve the owning context in those diagnostics too.
	private static func annotateDefinitionDiagnostics(
		_ diagnostics: inout [GeneratorDiagnostic], files: [ScannedFile], graph: [GraphProvider],
		owner: (SourcePosition, String) -> String
	) {
		var parameters: [ParameterInfo] = []
		for file in files {
			for type in file.types {
				parameters += type.memberwise
				for initializer in type.initializers { parameters += initializer.parameters }
			}
			for ext in file.extensions {
				for initializer in ext.initializers { parameters += initializer.parameters }
			}
			for bean in file.beans { parameters += bean.parameters }
		}
		let info = Dictionary(parameters.map { ($0.location, $0) }, uniquingKeysWith: { first, _ in first })
		var labels: [SourcePosition: Set<String>] = [:]
		for provider in graph {
			labels[provider.bean.location, default: []].insert(provider.owner)
			for parameter in provider.bean.parameters {
				labels[parameter.location, default: []].insert(provider.owner)
				if let original = info[parameter.location] {
					for location in [
						original.typeLocation, original.defaultLocation,
						original.qualifier?.location,
					].compactMap({ $0 }) {
						labels[location, default: []].insert(provider.owner)
					}
				}
			}
		}
		for file in files {
			for service in file.services {
				for location in [service.boundTo?.location, service.scopeLocation].compactMap({ $0 }) {
					labels[location, default: []].insert(owner(service.location, service.typeName))
				}
			}
			for bean in file.beans {
				labels[bean.returnTypeLocation, default: []].insert(
					owner(bean.location, bean.enclosingName))
			}
		}
		for index in diagnostics.indices {
			if let contexts = labels[diagnostics[index].location], !contexts.isEmpty {
				diagnostics[index].message += "; context: " + contexts.sorted().joined(separator: ", ")
			}
		}
	}

	private static func sorted(_ diagnostics: [GeneratorDiagnostic]) -> [GeneratorDiagnostic] {
		var seen: Set<String> = []
		return diagnostics.sorted { ($0.location, $0.message) < ($1.location, $1.message) }.filter {
			seen.insert("\($0.id):\($0.location):\($0.message)").inserted
		}
	}
	private static func failed(_ diagnostics: [GeneratorDiagnostic]) -> GenerationResult {
		GenerationResult(diagnostics: sorted(diagnostics), output: nil)
	}
}
