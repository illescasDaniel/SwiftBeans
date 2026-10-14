import SwiftUI

@main
struct MyApp: App {
	/// Single graph root for the app process.
	private let context = AppContext()

	var body: some Scene {
		WindowGroup {
			// View ← ViewModel (from DI). ViewModel ← UseCase ← Repository.
			ItemListView(viewModel: context.itemListViewModel)
		}
	}
}
