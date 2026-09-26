//
//  TDPRNG.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Mulberry32: deterministic, seedable, and serialisable as a single
//  UInt32 so the whole RNG lives inside `TDPGameState` and a seed replays
//  a session exactly.
//

import Foundation

struct TDPRNG: Codable, Equatable {

    private(set) var state: UInt32

    init(seed: UInt32) {
        self.state = seed == 0 ? 1 : seed
    }

    /// Advances the generator and returns a value in [0, 1).
    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        var t = state
        t = (t ^ (t >> 15)) &* (t | 1)
        t ^= t &+ ((t ^ (t >> 7)) &* (t | 61))
        return Double((t ^ (t >> 14)) & 0xFFFF_FFFF) / 4_294_967_296.0
    }

    /// Uniform integer in [0, upperBound).
    mutating func int(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return min(Int(next() * Double(upperBound)), upperBound - 1)
    }

    /// FNV-1a, for turning a room code into a reproducible seed.
    static func seed(from text: String) -> UInt32 {
        var h: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            h ^= UInt32(byte)
            h = h &* 16_777_619
        }
        return h == 0 ? 1 : h
    }
}
