//
//  JKSeededRNG.swift
//  Tokiyo Casino — Jackaroo
//
//  Codable deterministic RNG. SplitMix64 — small, fast, good enough
//  for shuffling / random tiebreaks / variant resolution. The whole
//  point is replayability: serialize the state, restore the state,
//  and every subsequent draw is identical.
//
//  We never use `Array.shuffle()` or `Int.random(in:)` anywhere in
//  the engine — they pull from the system RNG.
//

import Foundation

public struct JKSeededRNG: RandomNumberGenerator, Codable, Hashable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        // Mix the seed once so a `seed = 0` doesn't produce all zeros.
        self.state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }

    /// Inclusive on both ends. Bounded uniform via rejection — bias
    /// from a single modulo is small at typical hand sizes but we
    /// avoid it anyway so test fixtures are clean.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        precondition(range.lowerBound <= range.upperBound)
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        // Largest multiple of `span` that fits in UInt64.
        let limit = UInt64.max - (UInt64.max % span)
        var x: UInt64
        repeat { x = next() } while x >= limit
        return range.lowerBound + Int(x % span)
    }
}

extension Array {
    /// Fisher-Yates shuffle backed by `JKSeededRNG`. In-place and
    /// deterministic per RNG state.
    mutating func jkShuffle(using rng: inout JKSeededRNG) {
        guard count > 1 else { return }
        for i in stride(from: count - 1, through: 1, by: -1) {
            let j = rng.nextInt(in: 0...i)
            swapAt(i, j)
        }
    }

    func jkShuffled(using rng: inout JKSeededRNG) -> [Element] {
        var out = self
        out.jkShuffle(using: &rng)
        return out
    }
}
