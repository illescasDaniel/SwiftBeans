/// Finds `@Bean` factories called directly from another `@Bean` body or an `@Service` initializer body.
///
/// A direct call bypasses the generated context (a singleton factory runs again), so the diagnostic
/// suggests taking the dependency as a parameter. Specified in `specs/inter-bean-call-diagnostic/SPEC.md`.
enum DirectCallAnalyzer {
	static func analyze(_ files: [ScannedFile]) -> [GeneratorDiagnostic] {
		let configurationNames = Set(files.flatMap(\.types).filter(\.isConfiguration).map(\.name))
		let allBeans = files.flatMap(\.beans).filter { configurationNames.contains($0.enclosingName) }
		guard !allBeans.isEmpty else { return [] }
		var beansByName: [String: [BeanDecl]] = [:]
		for bean in allBeans {
			beansByName[bean.name, default: []].append(bean)
		}
		let serviceTypes = Set(files.flatMap(\.services).map(\.typeName))

		var diagnostics: [GeneratorDiagnostic] = []
		for file in files {
			for caller in file.beans where configurationNames.contains(caller.enclosingName) {
				diagnostics += check(
					caller.bodyCalls,
					owner: "@Bean '\(caller.enclosingName).\(caller.name)'",
					ownerType: caller.enclosingName,
					excluding: caller,
					beansByName: beansByName
				)
			}
			for body in file.initializerBodies where serviceTypes.contains(body.typeName) {
				diagnostics += check(
					body.calls,
					owner: "@Service initializer '\(body.typeName).init'",
					ownerType: body.typeName,
					excluding: nil,
					beansByName: beansByName
				)
			}
		}
		return diagnostics
	}

	private static func check(
		_ calls: [CallSite],
		owner: String,
		ownerType: String,
		excluding caller: BeanDecl?,
		beansByName: [String: [BeanDecl]]
	) -> [GeneratorDiagnostic] {
		calls.compactMap { call in
			guard let callee = resolve(call, ownerType: ownerType, beansByName: beansByName) else { return nil }
			if let caller, callee.enclosingName == caller.enclosingName, callee.name == caller.name { return nil }
			let calleeName = "\(callee.enclosingName).\(callee.name)"
			return GeneratorDiagnostic(
				severity: .warning,
				id: "bean.directCall",
				location: call.location,
				message: "\(owner) calls @Bean '\(calleeName)' directly instead of receiving it from the context; "
					+ "add a parameter '\(callee.name): \(callee.returnSpelling)' "
					+ "(a direct call bypasses the scope, so a singleton is created again)",
				notes: [GeneratorDiagnostic(
					severity: .note,
					id: "bean.directCall.callee",
					location: callee.location,
					message: "@Bean declared here"
				)]
			)
		}
	}

	/// The one `@Bean` the call names, or `nil` when it is not a bean call or is ambiguous.
	private static func resolve(_ call: CallSite, ownerType: String, beansByName: [String: [BeanDecl]]) -> BeanDecl? {
		guard let candidates = beansByName[call.name] else { return nil }
		let matches: [BeanDecl]
		switch call.base {
		case nil, "Self":
			matches = candidates.filter { $0.enclosingName == ownerType }
		case let base?:
			matches = candidates.filter { $0.enclosingName == base || $0.enclosingName.hasSuffix(".\(base)") }
		}
		guard let first = matches.first, Set(matches.map(\.enclosingName)).count == 1 else { return nil }
		return first
	}
}
