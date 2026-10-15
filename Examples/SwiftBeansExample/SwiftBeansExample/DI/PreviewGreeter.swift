import GreetingKit

/// App-side `Greeter` for `FakeAppContext`. The live one (`GreetingKitLive.EnglishGreeter`)
/// is only reachable through the generated context; no app file imports `GreetingKitLive`.
nonisolated struct PreviewGreeter: Greeter {
	func greet(_ name: String) -> String {
		"Hi, \(name) (preview)!"
	}
}
