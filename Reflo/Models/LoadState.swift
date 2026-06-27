import Foundation

enum LoadState<T: Sendable>: Sendable {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
