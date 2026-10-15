// swift-tools-version: 6.0

import PackageDescription

/// Local package used by the example as the generated-code compile check for
/// `.swiftbeans.yml` `local_packages`.
///
/// - `GreetingKit`: the `Greeter` protocol the app imports and depends on.
/// - `GreetingKitLive`: a `public` `@Service` bound to `Greeter`. The app never
///   imports this module; the generated file adds `import GreetingKitLive`.
let package = Package(
	name: "GreetingKit",
	platforms: [
		.macOS(.v15),
		.iOS(.v18),
	],
	products: [
		.library(name: "GreetingKit", targets: ["GreetingKit"]),
		.library(name: "GreetingKitLive", targets: ["GreetingKitLive"]),
	],
	dependencies: [
		.package(path: "../SwiftBeans"),
	],
	targets: [
		.target(name: "GreetingKit"),
		.target(
			name: "GreetingKitLive",
			dependencies: [
				"GreetingKit",
				.product(name: "SwiftBeans", package: "SwiftBeans"),
			]
		),
	]
)
