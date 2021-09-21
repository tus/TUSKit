
import Foundation

extension Collection where Index == Int {
    
    /// Add ability to chunk a collection into ranges, uses size of collection to determine amounts
    /// - Parameter size: The size to chunk
    /// - Returns: Returns an array of ranges that this collection can be chunked into
    func chunkRanges(size: Int) -> [Range<Int>] {
        let end = count
        return stride(from: 0, to: end, by: size).map { index in
            let range = index..<Swift.min(index + size, end)
            return range
        }
    }
}
