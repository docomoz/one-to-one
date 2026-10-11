import Foundation

/// Слияние «поздняя правка побеждает».
public enum SyncMerger {
    /// Побеждает больший `updatedAt`; при равенстве — надгробие, затем больший payload побайтно. Одинаково на обоих устройствах.
    public static func winner(_ a: SyncRecord, _ b: SyncRecord) -> SyncRecord {
        guard a.updatedAt == b.updatedAt else { return a.updatedAt > b.updatedAt ? a : b }
        switch (a.payload, b.payload) {
        case (nil, _): return a
        case (_, nil): return b
        case let (first?, second?): return second.lexicographicallyPrecedes(first) ? a : b
        }
    }
}
