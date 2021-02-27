//
//  TUSExecutor+Utility.swift
//  TUSKit
//
//  Created by Hanno  Gödecke on 27.02.21.
//

import Foundation

extension TUSExecutor {
    func dataIntoChunks(data: Data, chunkSize: Int, chunkStartParam: Int = 0) -> [Data] {
        var chunks = [Data]()
        var chunkStart = chunkStartParam
        while chunkStart < data.count {
            let remaining = data.count - chunkStart
            let nextChunkSize = min(chunkSize, remaining)
            let chunkEnd = chunkStart + nextChunkSize

            chunks.append(data.subdata(in: chunkStart ..< chunkEnd))

            chunkStart = chunkEnd
        }
        return chunks
    }
}
