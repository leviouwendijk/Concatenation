import Foundation

extension Array where Element: Hashable {
    public func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Dictionary {
    public func merging(_ other: Dictionary, uniquingKeysWith combine: (Value,Value)->Value) -> Dictionary {
        var copy = self
        other.forEach { copy[$0] = combine(copy[$0] ?? $1, $1) }
        return copy
    }
}
