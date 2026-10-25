import SwiftUI

struct LoginView: View {
	@State private var viewModel: LoginViewModel
	let onSubmit: @MainActor (LoginViewModel) async -> Void

	init(viewModel: LoginViewModel, onSubmit: @escaping @MainActor (LoginViewModel) async -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onSubmit = onSubmit
	}

	var body: some View {
		Form {
			TextField("Name", text: $viewModel.name)
			Text("Use a name to start a local demo session.")
				.foregroundStyle(.secondary)
			if case .failed(let message) = viewModel.state { Text(message).foregroundStyle(.red) }
			Button("Log In") {
				Task { await onSubmit(viewModel) }
			}
			.disabled(viewModel.state == .loading)
			if viewModel.state == .loading { ProgressView() }
		}
		.navigationTitle("SwiftBeans")
	}
}
