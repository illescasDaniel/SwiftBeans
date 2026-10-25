import SwiftUI

struct UserTabView: View {
	@State private var viewModel: UserTabViewModel
	init(viewModel: UserTabViewModel) { _viewModel = State(initialValue: viewModel) }

	var body: some View {
		Form {
			LabeledContent("Name", value: viewModel.repository.credentials.displayName)
			LabeledContent("Session", value: viewModel.repository.credentials.userID.uuidString)
			LabeledContent("Session updates", value: "\(viewModel.repository.heartbeatCount)")
		}
		.navigationTitle("User")
	}
}
