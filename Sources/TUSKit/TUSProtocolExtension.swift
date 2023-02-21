//
//  TUSProtocolExtension.swift
//
//
//  Created by Brad Patras on 7/14/22.
//

/// Available [TUS protocol extensions](https://tus.io/protocols/resumable-upload.html#protocol-extensions) that
/// the client supports.
public enum TUSProtocolExtension: String, CaseIterable {
    case creation = "creation"
    case creationWithUpload = "creation-with-upload"
    case termination = "termination"
    case concatenation = "concatenation"
    case creationDeferLength = "creation-defer-length"
    case checksum = "checksum"
    case checksumTrailer = "checksum-trailer"
    case expiration = "expiration"
}







