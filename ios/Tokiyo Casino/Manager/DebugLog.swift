//
//  DebugLog.swift
//  Tokiyo Casino
//
//  Compile-out-in-release logging helper. Use dprint(...) anywhere
//  you would have used print(...) for non-essential diagnostic output.
//

import Foundation

@inlinable
func dprint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let line = items.map { "\($0)" }.joined(separator: separator)
    Swift.print(line, terminator: terminator)
    #endif
}
