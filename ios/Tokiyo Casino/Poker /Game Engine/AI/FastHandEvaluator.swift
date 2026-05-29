//
//  FastHandEvaluator.swift
//  Poker — AI / Phase 1
//
//  Low-allocation 7-card hand scorer used inside the Monte Carlo equity loop.
//  Returns a single comparable Int (higher = stronger). The absolute scheme does
//  NOT match HandEvaluator.value — only the ORDERING is meaningful, and it is
//  verified by FastHandEvaluatorTests (independent known-answer oracle) plus a
//  random cross-check against the shipping HandEvaluator.
//
//  Why a second evaluator exists: Phase 0 measured the shipping
//  HandEvaluator at ~785 ms / 1k iterations (it generates all 21 five-card
//  combinations and allocates an Array + Dictionary per combo). That is
//  ~20-50x too slow to call inside a rollout. This scorer is ~36x faster:
//  one pass over the cards building rank/suit histograms and bitmasks, no
//  combination generation, no per-call Set/Dictionary.
//
//  See POKER_AI_DESIGN.md §3 and §4.1.
//

import Foundation

enum FastHandEvaluator {

    // Category constants (kept in the top bits of the score).
    // highCard=1 ... straightFlush=9. Royal flush is just a straight flush
    // with high card = ace, so it needs no separate category.

    @inline(__always)
    private static func suitIndex(_ s: Suit) -> Int {
        switch s {
        case .hearts:   return 0
        case .diamonds: return 1
        case .clubs:    return 2
        case .spades:   return 3
        }
    }

    /// Highest card completing a 5-straight in `mask`, or 0 if none.
    /// Bit `r` set => rank `r` present; bit 1 is the ace-low slot (wheel).
    @inline(__always)
    private static func straightHigh(_ mask: Int) -> Int {
        var high = 14
        while high >= 5 {
            let window = 0b11111 << (high - 4)
            if (mask & window) == window { return high }
            high -= 1
        }
        return 0
    }

    /// Pack a category + ordered tiebreak ranks into one comparable Int.
    /// `cat` occupies fixed top bits; each rank takes 4 bits (max 5 ranks => 20
    /// bits) so the category always dominates regardless of how many kickers a
    /// category carries.
    @inline(__always)
    private static func packed(_ cat: Int, _ ranks: [Int]) -> Int {
        var p = 0
        for r in ranks { p = (p << 4) | r }
        return (cat << 24) | p
    }

    /// Score the best 5-card hand contained in `cards` (5–7 cards).
    static func score(_ cards: [Card]) -> Int {
        var rankCount = [Int](repeating: 0, count: 15)  // index by rawValue 2...14
        var suitCount = [Int](repeating: 0, count: 4)
        var suitMask  = [Int](repeating: 0, count: 4)
        var rankMask  = 0

        for card in cards {
            let r = card.rank.rawValue
            let s = suitIndex(card.suit)
            rankCount[r] += 1
            suitCount[s] += 1
            suitMask[s] |= (1 << r)
            rankMask   |= (1 << r)
        }

        var flushSuit = -1
        for s in 0..<4 where suitCount[s] >= 5 { flushSuit = s }

        // 1. Straight flush (incl. royal)
        if flushSuit >= 0 {
            let m = suitMask[flushSuit]
            let withWheel = m | ((m & (1 << 14)) >> 13)  // ace also counts as low
            let high = straightHigh(withWheel)
            if high > 0 { return packed(9, [high]) }
        }

        // Group ranks by count (scan high -> low so first-found is highest).
        var quad = 0, trip1 = 0, trip2 = 0, pair1 = 0, pair2 = 0
        var r = 14
        while r >= 2 {
            switch rankCount[r] {
            case 4: quad = r
            case 3: if trip1 == 0 { trip1 = r } else if trip2 == 0 { trip2 = r }
            case 2: if pair1 == 0 { pair1 = r } else if pair2 == 0 { pair2 = r }
            default: break
            }
            r -= 1
        }

        // Highest `k` ranks present, excluding ranks flagged in `usedMask`.
        func topKickers(excluding usedMask: Int, count k: Int) -> [Int] {
            var result = [Int]()
            result.reserveCapacity(k)
            var rr = 14
            while rr >= 2 && result.count < k {
                if rankCount[rr] > 0 && (usedMask & (1 << rr)) == 0 { result.append(rr) }
                rr -= 1
            }
            return result
        }

        // 2. Four of a kind
        if quad > 0 {
            return packed(8, [quad] + topKickers(excluding: 1 << quad, count: 1))
        }

        // 3. Full house (two trips => use lower trip as the pair)
        if trip1 > 0 {
            let pairRank = max(trip2, pair1)
            if pairRank > 0 { return packed(7, [trip1, pairRank]) }
        }

        // 4. Flush
        if flushSuit >= 0 {
            var ranks = [Int]()
            ranks.reserveCapacity(5)
            let fm = suitMask[flushSuit]
            var fr = 14
            while fr >= 2 && ranks.count < 5 {
                if (fm & (1 << fr)) != 0 { ranks.append(fr) }
                fr -= 1
            }
            return packed(6, ranks)
        }

        // 5. Straight
        let straight = straightHigh(rankMask | ((rankMask & (1 << 14)) >> 13))
        if straight > 0 { return packed(5, [straight]) }

        // 6. Three of a kind
        if trip1 > 0 {
            return packed(4, [trip1] + topKickers(excluding: 1 << trip1, count: 2))
        }

        // 7. Two pair (third pair, if any, plays as a kicker by rank)
        if pair1 > 0 && pair2 > 0 {
            let used = (1 << pair1) | (1 << pair2)
            return packed(3, [pair1, pair2] + topKickers(excluding: used, count: 1))
        }

        // 8. One pair
        if pair1 > 0 {
            return packed(2, [pair1] + topKickers(excluding: 1 << pair1, count: 3))
        }

        // 9. High card
        return packed(1, topKickers(excluding: 0, count: 5))
    }
}
