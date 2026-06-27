import Foundation

struct Chapter: Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let href: String
    let depth: Int
}
