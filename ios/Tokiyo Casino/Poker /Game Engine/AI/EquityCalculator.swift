//
//  EquityCalculator.swift
//  Poker — AI / Phase 1
//
//  Monte Carlo win-probability estimation. Replaces the old hand-rank
//  heuristic. Calls FastHandEvaluator (NOT the shipping HandEvaluator, which is
//  too slow for the loop — see POKER_AI_DESIGN.md §3 / §4.1).
//
//  Threading: `equity(...)` is pure and synchronous so it is trivial to test
//  and benchmark, but AIEngine only ever calls it from a background queue (the
//  rollout must never run on the main thread — see §3).
//
//  Allocation: the remaining deck is built once and shuffled IN PLACE each
//  iteration (no per-iteration deck copy). This is the production refinement
//  the design doc called for over the Phase 0 reference.
//
//  Opponent ranges: an opponent given a range below 1.0 is dealt a combo drawn
//  straight from the strongest slice of starting hands (by
//  `PreflopRanges.handScore`), so even a very tight range is sampled exactly.
//  (The first cut rejected random deals with a 30-retry cap and fell back to
//  random cards, which inflated equity against tight ranges — badly so for a
//  shove from a player who almost never shoves.)
//

import Foundation

enum EquityCalculator {

    /// Hero win-equity in 0.0...1.0. Ties are split (counted as 1 / numTied).
    ///
    /// - Parameters:
    ///   - opponentTopFraction: the share of starting hands every opponent is
    ///     assumed to hold (§4.1). 1.0 = any two cards (uniform). Below 1.0
    ///     each opponent holds a hand from roughly the top that fraction of
    ///     starting hands — e.g. pass ~0.5 in a raised pot so the AI stops
    ///     assuming opponents hold random junk.
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int,
        opponentTopFraction: Double = 1.0,
        rng: inout some RandomNumberGenerator
    ) -> Double {
        guard opponents >= 1 else { return 0.0 }
        return equity(
            hole: hole,
            board: board,
            opponentRanges: Array(repeating: opponentTopFraction, count: opponents),
            iterations: iterations,
            rng: &rng
        )
    }

    /// Hero win-equity against one opponent per entry of `opponentRanges`,
    /// each holding the top that-share of starting hands (1.0 = any two
    /// cards). Lets a shover's range differ from the tighter range of someone
    /// who only called the shove.
    static func equity(
        hole: [Card],
        board: [Card],
        opponentRanges: [Double],
        iterations: Int,
        rng: inout some RandomNumberGenerator
    ) -> Double {
        guard hole.count == 2, board.count <= 5, !opponentRanges.isEmpty, iterations > 0 else {
            return 0.0
        }

        // Remaining deck, built once.
        let known = mask(hole) | mask(board)
        var deck = [Card]()
        deck.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let card = Card(suit: suit, rank: rank)
                if known & bit(card) == 0 { deck.append(card) }
            }
        }

        // nil = any two cards, dealt from the deck like the board.
        let rangeSizes: [Int?] = opponentRanges.map { $0 >= 1.0 ? nil : rangeSize(forTopFraction: $0) }
        let boardNeeded = 5 - board.count

        var total = 0.0
        var oppHoles = [[Card]](repeating: [], count: opponentRanges.count)   // reused scratch
        var fullBoard = [Card]()
        fullBoard.reserveCapacity(5)

        for _ in 0..<iterations {
            // Ranged opponents first, so the random cards dealt next avoid them.
            var dead = known
            for (i, size) in rangeSizes.enumerated() {
                guard let size else { continue }
                let combo = drawCombo(fromStrongest: size, avoiding: dead, rng: &rng)
                oppHoles[i] = [combo.a, combo.b]
                dead |= combo.mask
            }

            // Any-two-cards opponents, then the rest of the board, skipping
            // cards a ranged opponent already holds.
            deck.shuffle(using: &rng)
            var cursor = 0
            for i in rangeSizes.indices where rangeSizes[i] == nil {
                while dead & bit(deck[cursor]) != 0 { cursor += 1 }
                let a = deck[cursor]
                cursor += 1
                while dead & bit(deck[cursor]) != 0 { cursor += 1 }
                let b = deck[cursor]
                cursor += 1
                oppHoles[i] = [a, b]
            }
            fullBoard.removeAll(keepingCapacity: true)
            fullBoard.append(contentsOf: board)
            for _ in 0..<boardNeeded {
                while dead & bit(deck[cursor]) != 0 { cursor += 1 }
                fullBoard.append(deck[cursor])
                cursor += 1
            }

            let heroValue = FastHandEvaluator.score(hole + fullBoard)
            var bestOpp = Int.min
            var tiesAtBest = 0
            for oh in oppHoles {
                let v = FastHandEvaluator.score(oh + fullBoard)
                if v > bestOpp { bestOpp = v; tiesAtBest = 1 }
                else if v == bestOpp { tiesAtBest += 1 }
            }

            if heroValue > bestOpp {
                total += 1.0
            } else if heroValue == bestOpp {
                total += 1.0 / Double(tiesAtBest + 1)
            }
        }

        return total / Double(iterations)
    }

    /// Convenience overload using the system RNG.
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int,
        opponentTopFraction: Double = 1.0
    ) -> Double {
        var rng = SystemRandomNumberGenerator()
        return equity(
            hole: hole, board: board, opponents: opponents,
            iterations: iterations, opponentTopFraction: opponentTopFraction, rng: &rng
        )
    }

    // MARK: - Opponent ranges

    private struct Combo {
        let a: Card
        let b: Card
        let mask: UInt64
    }

    /// Every two-card combo, strongest first by `PreflopRanges.handScore`. Built once.
    private static let combosByStrength: [Combo] = {
        var fullDeck = [Card]()
        for suit in Suit.allCases {
            for rank in Rank.allCases { fullDeck.append(Card(suit: suit, rank: rank)) }
        }
        var scored = [(score: Double, combo: Combo)]()
        scored.reserveCapacity(1326)
        for i in 0..<fullDeck.count {
            for j in (i + 1)..<fullDeck.count {
                let a = fullDeck[i], b = fullDeck[j]
                scored.append((PreflopRanges.handScore(a, b), Combo(a: a, b: b, mask: bit(a) | bit(b))))
            }
        }
        return scored.sorted { $0.score > $1.score }.map(\.combo)
    }()

    /// How many of the strongest combos make up the top `fraction` of
    /// starting hands — never fewer than one pocket pair's worth.
    private static func rangeSize(forTopFraction fraction: Double) -> Int {
        let n = combosByStrength.count
        return min(n, max(6, Int((fraction * Double(n)).rounded())))
    }

    /// A random combo from the strongest `size` that shares no card with
    /// `dead`. Falls back to the strongest live combo, so a range the known
    /// cards have (almost) wiped out can't stall the loop.
    private static func drawCombo(
        fromStrongest size: Int,
        avoiding dead: UInt64,
        rng: inout some RandomNumberGenerator
    ) -> Combo {
        for _ in 0..<64 {
            let combo = combosByStrength[Int.random(in: 0..<size, using: &rng)]
            if combo.mask & dead == 0 { return combo }
        }
        return combosByStrength.first { $0.mask & dead == 0 } ?? combosByStrength[0]
    }

    // MARK: - Card bits

    @inline(__always)
    private static func bit(_ card: Card) -> UInt64 {
        let suit: Int
        switch card.suit {
        case .hearts:   suit = 0
        case .diamonds: suit = 1
        case .clubs:    suit = 2
        case .spades:   suit = 3
        }
        return 1 << UInt64(suit * 13 + card.rank.rawValue - 2)
    }

    private static func mask(_ cards: [Card]) -> UInt64 {
        cards.reduce(0) { $0 | bit($1) }
    }
}
