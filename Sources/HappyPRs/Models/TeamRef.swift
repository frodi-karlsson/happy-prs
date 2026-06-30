public struct TeamRef: Sendable, Equatable, Hashable {
    public let org: String
    public let slug: String

    public init(org: String, slug: String) {
        self.org = org; self.slug = slug
    }
}
