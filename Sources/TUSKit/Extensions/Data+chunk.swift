import Foundation

extension Data {
    
    /// Chunk a piece of Data into smaller data components
    /// - Parameters:
    ///   - size: The number of bytes to cut the data up in
    ///   - chunkStartParam: The byte from which to start
    /// - Returns: An array of Data chunks.
    func chunks(size: Int, chunkStartParam: Int = 0) -> [Data] {
        var chunks = [Data]()
        var chunkStart = chunkStartParam
        while chunkStart < self.count {
            let remaining = self.count - chunkStart
            let nextChunkSize = Swift.min(size, remaining)
            let chunkEnd = chunkStart + nextChunkSize

            chunks.append(self.subdata(in: chunkStart ..< chunkEnd))

            chunkStart = chunkEnd
        }
        return chunks
    }
}

