//
//  EquityBenchmark.swift
//  Poker AI — Phase 0 benchmark harness
//
//  Purpose (per POKER_AI_DESIGN.md §9 / §7 Phase 0):
//    Wrap the SHIPPING HandEvaluator in a Monte Carlo equity loop and time one
//    representative postflop scenario across a range of iteration counts. The
//    output locks in the `equitySamples` difficulty tiers and decides whether we
//    need to bridge OMPEval (C++) before writing any product code.
//
//  This file is intentionally STANDALONE so it runs with the command-line
//  toolchain:
//
//      swift Benchmarks/PokerAIPhase0/EquityBenchmark.swift
//
//  It does NOT import the app target because the app's Card.swift imports UIKit
//  (UIColor), which is unavailable to the macOS command-line `swift`. Instead it
//  carries:
//    1. UIKit-free Suit / Rank / Card matching the app's exact rawValues.
//    2. A VERBATIM copy of HandEvaluator (Foundation-only) so the timing is a
//       faithful reflection of the real evaluator's cost, including its
//       brute-force 7-choose-5 combination generation.
//    3. The EquityCalculator Monte Carlo loop exactly as specced in §4.1.
//
//  CAVEAT: numbers here are measured on a Mac (fast cores), not on an iPhone.
//  Treat them as an upper bound on speed / lower bound on time; a mid-range
//  device is typically 2-4x slower per core. The benchmark prints this reminder.
//

import Foundation

// MARK: - Model (UIKit-free copies, rawValues identical to the app)

enum Suit: String, CaseIterable {
    case hearts, diamonds, clubs, spades
}

enum Rank: Int, CaseIterable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Card: Equatable, Hashable {
    let suit: Suit
    let rank: Rank
}

// MARK: - HandRank (verbatim from HandEvaluator.swift)

enum HandRank: Int, Comparable {
    case highCard = 1
    case onePair = 2
    case twoPair = 3
    case threeOfAKind = 4
    case straight = 5
    case flush = 6
    case fullHouse = 7
    case fourOfAKind = 8
    case straightFlush = 9
    case royalFlush = 10

    static func < (lhs: HandRank, rhs: HandRank) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct HandEvaluation {
    let rank: HandRank
    let cards: [Card]
    let kickers: [Rank]
    let value: Int
}

// MARK: - HandEvaluator (VERBATIM copy of the shipping algorithm)

final class HandEvaluator {

    static func evaluateBestHand(from cards: [Card]) -> HandEvaluation {
        guard cards.count >= 5 else {
            return HandEvaluation(
                rank: .highCard,
                cards: cards.sorted { $0.rank.rawValue > $1.rank.rawValue },
                kickers: cards.map { $0.rank }.sorted(by: >),
                value: calculateHighCardValue(cards)
            )
        }

        let combinations = generateCombinations(cards, choose: 5)
        var bestEvaluation: HandEvaluation?

        for combo in combinations {
            let evaluation = evaluateFiveCards(combo)
            if bestEvaluation == nil || evaluation.value > bestEvaluation!.value {
                bestEvaluation = evaluation
            }
        }

        return bestEvaluation!
    }

    private static func generateCombinations(_ cards: [Card], choose k: Int) -> [[Card]] {
        guard k > 0 else { return [[]] }
        guard k <= cards.count else { return [] }
        if k == cards.count { return [cards] }

        var result: [[Card]] = []
        for i in 0...(cards.count - k) {
            let current = cards[i]
            let remaining = Array(cards[(i + 1)...])
            let subCombinations = generateCombinations(remaining, choose: k - 1)
            for subCombo in subCombinations {
                result.append([current] + subCombo)
            }
        }
        return result
    }

    private static func evaluateFiveCards(_ cards: [Card]) -> HandEvaluation {
        let sortedCards = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }

        let isFlush = checkFlush(cards)
        let straightHighCard = checkStraight(sortedCards)
        let isWheel = checkWheel(sortedCards)
        let isStraight = straightHighCard != nil || isWheel

        let rankGroups = Dictionary(grouping: cards, by: { $0.rank })
        let counts = rankGroups.mapValues { $0.count }.sorted { $0.value > $1.value }

        if isFlush && isStraight {
            let ranks = Set(sortedCards.map { $0.rank })
            if ranks == [.ace, .king, .queen, .jack, .ten] {
                return HandEvaluation(rank: .royalFlush, cards: sortedCards, kickers: [], value: 900000000)
            }
            let highValue = isWheel ? 5 : (straightHighCard?.rawValue ?? 0)
            return HandEvaluation(rank: .straightFlush, cards: sortedCards, kickers: [], value: 800000000 + highValue * 100000)
        }

        if counts.first?.value == 4 {
            let quad = counts.first!.key
            let kicker = rankGroups.keys.first { $0 != quad }!
            return HandEvaluation(rank: .fourOfAKind, cards: sortedCards, kickers: [kicker], value: 700000000 + quad.rawValue * 100000 + kicker.rawValue)
        }

        if counts.first?.value == 3 && counts.dropFirst().first?.value == 2 {
            let trips = counts.first!.key
            let pair = counts.dropFirst().first!.key
            return HandEvaluation(rank: .fullHouse, cards: sortedCards, kickers: [], value: 600000000 + trips.rawValue * 100000 + pair.rawValue * 1000)
        }

        if isFlush {
            let values = sortedCards.map { $0.rank.rawValue }
            return HandEvaluation(rank: .flush, cards: sortedCards, kickers: sortedCards.map { $0.rank }, value: 500000000 + calculateKickerValue(values))
        }

        if isStraight {
            let highValue = isWheel ? 5 : (straightHighCard?.rawValue ?? 0)
            return HandEvaluation(rank: .straight, cards: sortedCards, kickers: [], value: 400000000 + highValue * 100000)
        }

        if counts.first?.value == 3 {
            let trips = counts.first!.key
            let kickers = rankGroups.keys.filter { $0 != trips }.sorted(by: >)
            return HandEvaluation(rank: .threeOfAKind, cards: sortedCards, kickers: kickers, value: 300000000 + trips.rawValue * 100000 + calculateKickerValue(kickers.map { $0.rawValue }))
        }

        if counts.first?.value == 2 && counts.dropFirst().first?.value == 2 {
            let pairs = counts.prefix(2).map { $0.key }.sorted(by: >)
            let kicker = rankGroups.keys.first { !pairs.contains($0) }!
            return HandEvaluation(rank: .twoPair, cards: sortedCards, kickers: [kicker], value: 200000000 + pairs[0].rawValue * 100000 + pairs[1].rawValue * 1000 + kicker.rawValue)
        }

        if counts.first?.value == 2 {
            let pair = counts.first!.key
            let kickers = rankGroups.keys.filter { $0 != pair }.sorted(by: >)
            return HandEvaluation(rank: .onePair, cards: sortedCards, kickers: kickers, value: 100000000 + pair.rawValue * 100000 + calculateKickerValue(kickers.map { $0.rawValue }))
        }

        return HandEvaluation(rank: .highCard, cards: sortedCards, kickers: sortedCards.map { $0.rank }, value: calculateKickerValue(sortedCards.map { $0.rank.rawValue }))
    }

    private static func checkFlush(_ cards: [Card]) -> Bool {
        return cards.allSatisfy { $0.suit == cards[0].suit }
    }

    private static func checkStraight(_ sortedCards: [Card]) -> Rank? {
        let ranks = sortedCards.map { $0.rank.rawValue }
        for i in 0..<ranks.count - 1 {
            if ranks[i] - ranks[i + 1] != 1 { return nil }
        }
        return sortedCards[0].rank
    }

    private static func checkWheel(_ sortedCards: [Card]) -> Bool {
        let ranks = sortedCards.map { $0.rank }
        return ranks[0] == .ace && ranks[1] == .five && ranks[2] == .four && ranks[3] == .three && ranks[4] == .two
    }

    private static func calculateKickerValue(_ values: [Int]) -> Int {
        var result = 0
        var multiplier = 1
        for value in values.prefix(5).reversed() {
            result += value * multiplier
            multiplier *= 15
        }
        return result
    }

    private static func calculateHighCardValue(_ cards: [Card]) -> Int {
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        return calculateKickerValue(sorted.map { $0.rank.rawValue })
    }
}

// MARK: - FastEvaluator (low-allocation 7-card eval, candidate for Phase 1)
//
// Produces a single comparable Int score (poker ordering). Internal scheme need
// not match the shipping HandEvaluator's `value`; only correctness of ORDERING
// matters for equity. Validated by runOracleTests() (known-answer) AND the
// random cross-check below. NOTE: "low-allocation", not allocation-free — it
// still allocates small [Int] count arrays and a Set for kicker exclusion; the
// production FastHandEvaluator should remove those (bitmask kickers, no Set).

enum FastEvaluator {

    private static func suitIndex(_ s: Suit) -> Int {
        switch s {
        case .hearts: return 0
        case .diamonds: return 1
        case .clubs: return 2
        case .spades: return 3
        }
    }

    /// Highest card completing a 5-straight in `mask` (bit r set => rank r present;
    /// bit 1 is the ace-low slot). Returns nil if no straight.
    private static func straightHigh(_ mask: Int) -> Int? {
        var high = 14
        while high >= 5 {
            let window = 0b11111 << (high - 4)
            if (mask & window) == window { return high }
            high -= 1
        }
        return nil
    }

    /// cat in fixed top bits; tiebreak ranks packed 4 bits each into low 24 bits.
    private static func score(_ cat: Int, _ ranks: [Int]) -> Int {
        var packed = 0
        for r in ranks { packed = (packed << 4) | r }
        return (cat << 24) | packed
    }

    static func score7(_ cards: [Card]) -> Int {
        var rankCount = [Int](repeating: 0, count: 15)
        var suitCount = [Int](repeating: 0, count: 4)
        var suitRankMask = [Int](repeating: 0, count: 4)

        for card in cards {
            let r = card.rank.rawValue
            let s = suitIndex(card.suit)
            rankCount[r] += 1
            suitCount[s] += 1
            suitRankMask[s] |= (1 << r)
        }

        var flushSuit = -1
        for s in 0..<4 where suitCount[s] >= 5 { flushSuit = s }

        // 1. Straight flush
        if flushSuit >= 0 {
            let m = suitRankMask[flushSuit]
            let withWheel = m | ((m & (1 << 14)) >> 13) // ace low at bit 1
            if let high = straightHigh(withWheel) {
                return score(9, [high])
            }
        }

        // Group ranks by count (descending rank order).
        var quads: [Int] = [], trips: [Int] = [], pairs: [Int] = [], singles: [Int] = []
        var rankMask = 0
        var r = 14
        while r >= 2 {
            let count = rankCount[r]
            if count > 0 { rankMask |= (1 << r) }
            switch count {
            case 4: quads.append(r)
            case 3: trips.append(r)
            case 2: pairs.append(r)
            case 1: singles.append(r)
            default: break
            }
            r -= 1
        }

        func topRanks(excluding used: Set<Int>, count k: Int) -> [Int] {
            var result: [Int] = []
            var rr = 14
            while rr >= 2 && result.count < k {
                if rankCount[rr] > 0 && !used.contains(rr) { result.append(rr) }
                rr -= 1
            }
            return result
        }

        // 2. Quads
        if let quad = quads.first {
            let kicker = topRanks(excluding: [quad], count: 1)
            return score(8, [quad] + kicker)
        }

        // 3. Full house
        if let trip = trips.first {
            // pair candidate: a second set of trips counts as a pair, or best pair
            let pairCandidate = max(trips.dropFirst().first ?? 0, pairs.first ?? 0)
            if pairCandidate > 0 {
                return score(7, [trip, pairCandidate])
            }
        }

        // 4. Flush
        if flushSuit >= 0 {
            var flushRanks: [Int] = []
            var fr = 14
            while fr >= 2 && flushRanks.count < 5 {
                if (suitRankMask[flushSuit] & (1 << fr)) != 0 { flushRanks.append(fr) }
                fr -= 1
            }
            return score(6, flushRanks)
        }

        // 5. Straight
        let maskWithWheel = rankMask | ((rankMask & (1 << 14)) >> 13)
        if let high = straightHigh(maskWithWheel) {
            return score(5, [high])
        }

        // 6. Trips
        if let trip = trips.first {
            return score(4, [trip] + topRanks(excluding: [trip], count: 2))
        }

        // 7. Two pair
        if pairs.count >= 2 {
            let p0 = pairs[0], p1 = pairs[1]
            let kicker = topRanks(excluding: [p0, p1], count: 1)
            return score(3, [p0, p1] + kicker)
        }

        // 8. One pair
        if let pair = pairs.first {
            return score(2, [pair] + topRanks(excluding: [pair], count: 3))
        }

        // 9. High card
        return score(1, topRanks(excluding: [], count: 5))
    }
}

// MARK: - EquityCalculator (Monte Carlo, per §4.1)

enum EquityCalculator {

    /// Returns hero win-equity in 0.0 ... 1.0 (ties counted as 1 / numTied).
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int,
        rng: inout SystemRandomNumberGenerator
    ) -> Double {
        precondition(hole.count == 2, "hero must hold exactly 2 cards")
        precondition(board.count <= 5, "board cannot exceed 5 cards")

        // 1. Build remaining deck (52 minus hole + board).
        let used = Set(hole + board)
        var fullDeck: [Card] = []
        fullDeck.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let card = Card(suit: suit, rank: rank)
                if !used.contains(card) { fullDeck.append(card) }
            }
        }

        let boardNeeded = 5 - board.count
        var totalScore = 0.0

        for _ in 0..<iterations {
            var deck = fullDeck
            deck.shuffle(using: &rng)
            var cursor = 0

            // 2. Deal opponent hole cards.
            var oppHoles: [[Card]] = []
            oppHoles.reserveCapacity(opponents)
            for _ in 0..<opponents {
                oppHoles.append([deck[cursor], deck[cursor + 1]])
                cursor += 2
            }

            // Deal the missing board cards.
            var fullBoard = board
            if boardNeeded > 0 {
                fullBoard.append(contentsOf: deck[cursor..<(cursor + boardNeeded)])
                cursor += boardNeeded
            }

            // 3. Evaluate hero + each opponent (7-card best hand).
            let heroValue = HandEvaluator.evaluateBestHand(from: hole + fullBoard).value

            var bestOpp = Int.min
            for opp in oppHoles {
                let v = HandEvaluator.evaluateBestHand(from: opp + fullBoard).value
                if v > bestOpp { bestOpp = v }
            }

            // 4. Tally.
            if heroValue > bestOpp {
                totalScore += 1.0
            } else if heroValue == bestOpp {
                // Count how many opponents tie the hero at the top.
                let tiedOpponents = oppHoles.reduce(0) { acc, opp in
                    HandEvaluator.evaluateBestHand(from: opp + fullBoard).value == heroValue ? acc + 1 : acc
                }
                totalScore += 1.0 / Double(tiedOpponents + 1)
            }
            // loss: add nothing
        }

        return totalScore / Double(iterations)
    }
}

// MARK: - EquityCalculator using FastEvaluator (identical loop, fast scoring)

enum EquityCalculatorFast {
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int,
        rng: inout SystemRandomNumberGenerator
    ) -> Double {
        let used = Set(hole + board)
        var fullDeck: [Card] = []
        fullDeck.reserveCapacity(52)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let card = Card(suit: suit, rank: rank)
                if !used.contains(card) { fullDeck.append(card) }
            }
        }

        let boardNeeded = 5 - board.count
        var totalScore = 0.0

        for _ in 0..<iterations {
            var deck = fullDeck
            deck.shuffle(using: &rng)
            var cursor = 0

            var oppHoles: [[Card]] = []
            oppHoles.reserveCapacity(opponents)
            for _ in 0..<opponents {
                oppHoles.append([deck[cursor], deck[cursor + 1]])
                cursor += 2
            }

            var fullBoard = board
            if boardNeeded > 0 {
                fullBoard.append(contentsOf: deck[cursor..<(cursor + boardNeeded)])
                cursor += boardNeeded
            }

            let heroValue = FastEvaluator.score7(hole + fullBoard)
            var bestOpp = Int.min
            var tied = 0
            for opp in oppHoles {
                let v = FastEvaluator.score7(opp + fullBoard)
                if v > bestOpp { bestOpp = v; tied = 0 }
                else if v == bestOpp { tied += 1 }
            }

            if heroValue > bestOpp {
                totalScore += 1.0
            } else if heroValue == bestOpp {
                let tiedOpponents = oppHoles.reduce(0) { acc, opp in
                    FastEvaluator.score7(opp + fullBoard) == heroValue ? acc + 1 : acc
                }
                totalScore += 1.0 / Double(tiedOpponents + 1)
            }
            _ = tied
        }

        return totalScore / Double(iterations)
    }
}

// MARK: - Benchmark driver

func c(_ r: Rank, _ s: Suit) -> Card { Card(suit: s, rank: r) }

/// Independent oracle tests: assert FastEvaluator's ORDERING directly on
/// hand-built cases whose correct ranking is known a priori. This does NOT
/// compare against the shipping HandEvaluator, so a latent bug there cannot be
/// silently inherited. (Per POKER_AI_DESIGN.md §4.1 "Correctness".)
func runOracleTests() -> (passed: Int, failed: Int) {
    // expectedSign of (score(lhs) - score(rhs)): -1 lhs<rhs, 0 tie, 1 lhs>rhs
    typealias Case = (name: String, lhs: [Card], rhs: [Card], expected: Int)

    let cases: [Case] = [
        // 1. Wheel (A2345, high=5) ranks BELOW 6-high straight.
        ("wheel < 6-high straight",
         [c(.ace,.spades), c(.two,.hearts), c(.three,.diamonds), c(.four,.clubs), c(.five,.spades), c(.king,.diamonds), c(.queen,.clubs)],
         [c(.two,.clubs), c(.three,.spades), c(.four,.hearts), c(.five,.diamonds), c(.six,.clubs), c(.king,.hearts), c(.queen,.spades)],
         -1),

        // 2. Straight flush beats four of a kind.
        ("straight flush > quads",
         [c(.five,.hearts), c(.six,.hearts), c(.seven,.hearts), c(.eight,.hearts), c(.nine,.hearts), c(.ace,.spades), c(.king,.diamonds)],
         [c(.ace,.clubs), c(.ace,.spades), c(.ace,.hearts), c(.ace,.diamonds), c(.king,.spades), c(.queen,.diamonds), c(.jack,.clubs)],
         1),

        // 3a. Full house: higher trips wins (KKKQQ > QQQKK).
        ("KKK+QQ > QQQ+KK",
         [c(.king,.spades), c(.king,.hearts), c(.king,.diamonds), c(.queen,.spades), c(.queen,.hearts), c(.two,.clubs), c(.three,.diamonds)],
         [c(.queen,.spades), c(.queen,.hearts), c(.queen,.diamonds), c(.king,.spades), c(.king,.hearts), c(.two,.clubs), c(.three,.diamonds)],
         1),

        // 3b. Full house: equal trips, higher pair wins (999AA > 999KK).
        ("999+AA > 999+KK",
         [c(.nine,.spades), c(.nine,.hearts), c(.nine,.diamonds), c(.ace,.spades), c(.ace,.hearts), c(.two,.clubs), c(.three,.diamonds)],
         [c(.nine,.spades), c(.nine,.hearts), c(.nine,.diamonds), c(.king,.spades), c(.king,.hearts), c(.two,.clubs), c(.three,.diamonds)],
         1),

        // 4. Two pair kicker ordering (AAKK+Q > AAKK+J).
        ("two pair higher kicker wins",
         [c(.ace,.spades), c(.ace,.hearts), c(.king,.spades), c(.king,.hearts), c(.queen,.diamonds), c(.two,.clubs), c(.three,.diamonds)],
         [c(.ace,.spades), c(.ace,.hearts), c(.king,.spades), c(.king,.hearts), c(.jack,.diamonds), c(.two,.clubs), c(.three,.diamonds)],
         1),

        // 5. Flush kicker ordering (A-high flush ...9 > ...8).
        ("flush higher kicker wins",
         [c(.ace,.hearts), c(.king,.hearts), c(.queen,.hearts), c(.jack,.hearts), c(.nine,.hearts), c(.two,.spades), c(.three,.diamonds)],
         [c(.ace,.hearts), c(.king,.hearts), c(.queen,.hearts), c(.jack,.hearts), c(.eight,.hearts), c(.two,.spades), c(.three,.diamonds)],
         1),

        // 6. Quad kicker ordering (7777+A > 7777+K).
        ("quads higher kicker wins",
         [c(.seven,.spades), c(.seven,.hearts), c(.seven,.diamonds), c(.seven,.clubs), c(.ace,.spades), c(.two,.hearts), c(.three,.diamonds)],
         [c(.seven,.spades), c(.seven,.hearts), c(.seven,.diamonds), c(.seven,.clubs), c(.king,.spades), c(.two,.hearts), c(.three,.diamonds)],
         1),

        // 7. Board plays the board (royal on board) => tie regardless of hole cards.
        ("board-plays-the-board ties",
         [c(.two,.hearts), c(.three,.diamonds), c(.ace,.spades), c(.king,.spades), c(.queen,.spades), c(.jack,.spades), c(.ten,.spades)],
         [c(.four,.hearts), c(.five,.diamonds), c(.ace,.spades), c(.king,.spades), c(.queen,.spades), c(.jack,.spades), c(.ten,.spades)],
         0),

        // 8. Ace-high beats king-high (no pair/straight/flush).
        ("ace-high > king-high",
         [c(.ace,.spades), c(.jack,.clubs), c(.nine,.hearts), c(.seven,.diamonds), c(.five,.clubs), c(.three,.spades), c(.two,.diamonds)],
         [c(.king,.spades), c(.jack,.clubs), c(.nine,.hearts), c(.seven,.diamonds), c(.five,.clubs), c(.three,.spades), c(.two,.diamonds)],
         1),
    ]

    // 9. Category ladder: each strictly beats the previous.
    let ladder: [(String, [Card])] = [
        ("high card", [c(.ace,.spades), c(.jack,.clubs), c(.nine,.hearts), c(.seven,.diamonds), c(.five,.clubs), c(.three,.spades), c(.two,.diamonds)]),
        ("one pair",  [c(.ace,.spades), c(.ace,.hearts), c(.jack,.clubs), c(.nine,.diamonds), c(.seven,.clubs), c(.three,.spades), c(.two,.diamonds)]),
        ("two pair",  [c(.ace,.spades), c(.ace,.hearts), c(.king,.clubs), c(.king,.diamonds), c(.seven,.clubs), c(.three,.spades), c(.two,.diamonds)]),
        ("trips",     [c(.ace,.spades), c(.ace,.hearts), c(.ace,.diamonds), c(.king,.clubs), c(.seven,.clubs), c(.three,.spades), c(.two,.diamonds)]),
        ("straight",  [c(.five,.spades), c(.six,.hearts), c(.seven,.diamonds), c(.eight,.clubs), c(.nine,.spades), c(.king,.diamonds), c(.two,.clubs)]),
        ("flush",     [c(.ace,.hearts), c(.king,.hearts), c(.queen,.hearts), c(.jack,.hearts), c(.nine,.hearts), c(.three,.spades), c(.two,.diamonds)]),
        ("full house",[c(.king,.spades), c(.king,.hearts), c(.king,.diamonds), c(.queen,.spades), c(.queen,.hearts), c(.two,.clubs), c(.three,.diamonds)]),
        ("quads",     [c(.seven,.spades), c(.seven,.hearts), c(.seven,.diamonds), c(.seven,.clubs), c(.ace,.spades), c(.two,.hearts), c(.three,.diamonds)]),
        ("straight flush", [c(.five,.hearts), c(.six,.hearts), c(.seven,.hearts), c(.eight,.hearts), c(.nine,.hearts), c(.ace,.spades), c(.king,.diamonds)]),
    ]

    func sign(_ x: Int) -> Int { x < 0 ? -1 : (x > 0 ? 1 : 0) }
    var passed = 0, failed = 0

    for tc in cases {
        let got = sign(FastEvaluator.score7(tc.lhs) - FastEvaluator.score7(tc.rhs))
        if got == tc.expected { passed += 1 }
        else { failed += 1; print("  FAIL: \(tc.name) — expected sign \(tc.expected), got \(got)") }
    }

    for i in 1..<ladder.count {
        let lo = FastEvaluator.score7(ladder[i-1].1)
        let hi = FastEvaluator.score7(ladder[i].1)
        if hi > lo { passed += 1 }
        else { failed += 1; print("  FAIL: ladder \(ladder[i].0) (\(hi)) not > \(ladder[i-1].0) (\(lo))") }
    }

    return (passed, failed)
}

/// Validate that FastEvaluator produces the SAME pairwise ordering as the
/// shipping brute-force evaluator across many random 7-card hands.
func validateFastEvaluator(samples: Int) -> (checked: Int, mismatches: Int) {
    var deck: [Card] = []
    for s in Suit.allCases { for r in Rank.allCases { deck.append(Card(suit: s, rank: r)) } }

    var rng = SystemRandomNumberGenerator()
    var mismatches = 0
    var checked = 0

    for _ in 0..<samples {
        deck.shuffle(using: &rng)
        let a = Array(deck[0..<7])
        let b = Array(deck[7..<14])

        let brA = HandEvaluator.evaluateBestHand(from: a).value
        let brB = HandEvaluator.evaluateBestHand(from: b).value
        let fA = FastEvaluator.score7(a)
        let fB = FastEvaluator.score7(b)

        func sign(_ x: Int, _ y: Int) -> Int { x < y ? -1 : (x > y ? 1 : 0) }
        if sign(brA, brB) != sign(fA, fB) { mismatches += 1 }
        checked += 1
    }
    return (checked, mismatches)
}

func runBenchmark() {
    // Representative postflop scenario (per §9 "one representative postflop
    // equity scenario"): hero holds the nut flush draw + two overcards on a
    // two-tone flop versus 2 opponents — a common, computation-heavy spot
    // (3 seven-card evaluations per iteration, frequent near-ties).
    let hero  = [c(.ace, .spades), c(.king, .spades)]
    let board = [c(.queen, .spades), c(.seven, .spades), c(.two, .hearts)]
    let opponents = 2

    let iterationCounts = [200, 500, 1000, 1500, 2000, 3000, 5000, 10000]

    print("=== Poker AI Phase 0 — Equity Benchmark ===")
    print("Scenario: hero AsKs | board Qs 7s 2h | vs \(opponents) opponents")
    print("Host: macOS command-line swift. Device is ~2-4x SLOWER per core.")
    print("")

    // --- Correctness 1: independent oracle tests (known-answer, no comparison) ---
    print("Oracle tests (FastEvaluator, independent known-answer cases):")
    let oracle = runOracleTests()
    print("  \(oracle.passed) passed, \(oracle.failed) failed")
    print("")

    // --- Correctness 2: does FastEvaluator order hands like the shipping one? ---
    let v = validateFastEvaluator(samples: 200_000)
    print("Cross-check (FastEvaluator vs shipping HandEvaluator):")
    print("  \(v.checked) random hand pairs, \(v.mismatches) ordering mismatches")
    print("")

    func bench(_ label: String,
               _ fn: ([Card], [Card], Int, Int, inout SystemRandomNumberGenerator) -> Double) {
        print(label)
        print(String(format: "  %-12@ %-10@ %-14@ %-16@",
                     "iterations" as NSString, "equity" as NSString,
                     "wall (ms)" as NSString, "ms / 1k iters" as NSString))
        print("  " + String(repeating: "-", count: 54))

        var warmRNG = SystemRandomNumberGenerator()
        _ = fn(hero, board, opponents, 200, &warmRNG) // warm-up

        for n in iterationCounts {
            var rng = SystemRandomNumberGenerator()
            let start = DispatchTime.now()
            let eq = fn(hero, board, opponents, n, &rng)
            let end = DispatchTime.now()
            let ms = Double(end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000.0
            let msPer1k = ms / (Double(n) / 1000.0)
            print(String(format: "  %-12d %-10.4f %-14.2f %-16.3f", n, eq, ms, msPer1k))
        }
        print("")
    }

    bench("Evaluator A — shipping HandEvaluator (brute-force 7-choose-5):",
          EquityCalculator.equity)
    bench("Evaluator B — FastEvaluator (low-allocation, candidate for Phase 1):",
          EquityCalculatorFast.equity)

    print("Interpretation:")
    print(" - 'equity' should converge as iterations rise (true ~0.55-0.60 here).")
    print("   Both evaluators must converge to the SAME value (correctness).")
    print(" - §4.1 budget: <100 ms per decision (hidden by the ~1.5s think delay).")
    print(" - Device estimate = (ms / 1k) * 2-4. Check the 3000-sample (Hard/Expert) row.")
    print(" - If Evaluator B clears budget on-device, NO OMPEval C++ bridge is needed.")
}

runBenchmark()
