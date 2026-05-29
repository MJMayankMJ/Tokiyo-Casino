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

import Foundation

enum EquityCalculator {

    /// Hero win-equity in 0.0...1.0. Ties are split (counted as 1 / numTied).
    ///
    /// - Parameters:
    ///   - opponentTopFraction: coarse opponent-range filter (§4.1). 1.0 = any
    ///     two cards (uniform). Below 1.0, sampled opponent hole cards are
    ///     rejected unless they fall in roughly the top fraction of starting
    ///     hands — e.g. pass ~0.5 in a raised pot so the AI stops assuming
    ///     opponents hold random junk. Best-effort with a retry cap.
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int,
        opponentTopFraction: Double = 1.0,
        rng: inout some RandomNumberGenerator
    ) -> Double {
        guard hole.count == 2, board.count <= 5, opponents >= 1, iterations > 0 else {
            return 0.0
        }

        // Remaining deck, built once.
        let used = Set(hole + board)
        var deck = [Card]()
        deck.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let card = Card(suit: suit, rank: rank)
                if !used.contains(card) { deck.append(card) }
            }
        }

        let boardNeeded = 5 - board.count
        let cutoff = scoreCutoff(forTopFraction: opponentTopFraction)
        let maxRejections = 30

        var total = 0.0
        var oppHoles = [[Card]]()         // reused scratch
        oppHoles.reserveCapacity(opponents)

        for _ in 0..<iterations {
            // Draw a layout, retrying if the opponent-range filter rejects it.
            var attempt = 0
            while true {
                attempt += 1
                deck.shuffle(using: &rng)
                oppHoles.removeAll(keepingCapacity: true)

                var cursor = 0
                var rejected = false
                for _ in 0..<opponents {
                    let a = deck[cursor], b = deck[cursor + 1]
                    cursor += 2
                    if cutoff > 0 && attempt <= maxRejections {
                        if PreflopRanges.handScore(a, b) < cutoff { rejected = true; break }
                    }
                    oppHoles.append([a, b])
                }
                if rejected { continue }

                // Complete the board from the cards after the opponent holes.
                var fullBoard = board
                if boardNeeded > 0 {
                    fullBoard.append(contentsOf: deck[cursor..<(cursor + boardNeeded)])
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
                break
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

    // MARK: - Opponent-range cutoff

    /// `handScore` for every two-card combo, sorted descending. Built once.
    private static let sortedHandScores: [Double] = {
        var fullDeck = [Card]()
        for suit in Suit.allCases {
            for rank in Rank.allCases { fullDeck.append(Card(suit: suit, rank: rank)) }
        }
        var scores = [Double]()
        scores.reserveCapacity(1326)
        for i in 0..<fullDeck.count {
            for j in (i + 1)..<fullDeck.count {
                scores.append(PreflopRanges.handScore(fullDeck[i], fullDeck[j]))
            }
        }
        return scores.sorted(by: >)
    }()

    /// The `handScore` threshold separating the top `fraction` of starting
    /// hands. Returns 0 (no filtering) when `fraction >= 1`.
    private static func scoreCutoff(forTopFraction fraction: Double) -> Double {
        guard fraction < 1.0 else { return 0.0 }
        guard fraction > 0.0 else { return sortedHandScores.first ?? 0.0 }
        let arr = sortedHandScores
        let idx = min(arr.count - 1, max(0, Int(fraction * Double(arr.count))))
        return arr[idx]
    }
}
