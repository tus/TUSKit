//
//  TUSProtocolExtension.swift
//
//
//  Created by Brad Patras on 7/14/22.
//

public enum TUSProtocolExtension {
	case creation

	static let all: [TUSProtocolExtension] = [.creation]
}

extension Array where Element == TUSProtocolExtension {
	public static let all: [TUSProtocolExtension] = [.creation]
}

