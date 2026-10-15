/// Load lifecycle shared by the view models. Views map it to display copy; tests assert on it.
enum LoadState: Equatable {
	case idle
	case loading
	case loaded
	case failed(String)
}
