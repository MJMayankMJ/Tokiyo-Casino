//
//  FastHandEvaluatorTests.swift
//  Tokiyo CasinoTests
//
//  Phase 1 — correctness for the rollout scorer. Per POKER_AI_DESIGN.md §4.1
//  the new evaluator must be checked against an INDEPENDENT known-answer oracle
//  (not only against the shipping HandEvaluator, which could share a latent
//  bug). The random cross-check stays as an additional regression guard.
//

import XCTest
@testable import Tokiyo_Casino

final class FastHandEvaluatorTests: XCTestCase {

    private func c(_ r: Rank, _ s: Suit) -> Card { Card(suit: s, rank: r) }

    /// sign of score(lhs) - score(rhs): -1 lhs<rhs, 0 tie, 1 lhs>rhs
    private func order(_ lhs: [Card], _ rhs: [Card]) -> Int {
        let a = FastHandEvaluator.score(lhs)
        let b = FastHandEvaluator.score(rhs)
        return a < b ? -1 : (a > b ? 1 : 0)
    }

    func testOracleOrderings() {
        // 1. Wheel (A2345, high=5) ranks below 6-high straight.
        XCTAssertEqual(order(
            [c(.ace,.spades), c(.two,.hearts), c(.three,.diamonds), c(.four,.clubs), c(.five,.spades), c(.king,.diamonds), c(.queen,.clubs)],
            [c(.two,.clubs), c(.three,.spades), c(.four,.hearts), c(.five,.diamonds), c(.six,.clubs), c(.king,.hearts), c(.queen,.spades)]
        ), -1, "wheel should rank below 6-high straight")

        // 2. Straight flush beats four of a kind.
        XCTAssertEqual(order(
            [c(.five,.hearts), c(.six,.hearts), c(.seven,.hearts), c(.eight,.hearts), c(.nine,.hearts), c(.ace,.spades), c(.king,.diamonds)],
            [c(.ace,.clubs), c(.ace,.spades), c(.ace,.hearts), c(.ace,.diamonds), c(.king,.spades), c(.queen,.diamonds), c(.jack,.clubs)]
        ), 1, "straight flush should beat quads")

        // 3a. Full house: higher trips wins.
        XCTAssertEqual(order(
            [c(.king,.spades), c(.king,.hearts), c(.king,.diamonds), c(.queen,.spades), c(.queen,.hearts), c(.two,.clubs), c(.three,.diamonds)],
            [c(.queen,.spades), c(.queen,.hearts), c(.queen,.diamonds), c(.king,.spades), c(.king,.hearts), c(.two,.clubs), c(.three,.diamonds)]
        ), 1, "kings full should beat queens full")

        // 3b. Full house: equal trips, higher pair wins.
        XCTAssertEqual(order(
            [c(.nine,.spades), c(.nine,.hearts), c(.nine,.diamonds), c(.ace,.spades), c(.ace,.hearts), c(.two,.clubs), c(.three,.diamonds)],
            [c(.nine,.spades), c(.nine,.hearts), c(.nine,.diamonds), c(.king,.spades), c(.king,.hearts), c(.two,.clubs), c(.three,.diamonds)]
        ), 1, "999+AA should beat 999+KK")

        // 4. Two pair kicker ordering.
        XCTAssertEqual(order(
            [c(.ace,.spades), c(.ace,.hearts), c(.king,.spades), c(.king,.hearts), c(.queen,.diamonds), c(.two,.clubs), c(.three,.diamonds)],
            [c(.ace,.spades), c(.ace,.hearts), c(.king,.spades), c(.king,.hearts), c(.jack,.diamonds), c(.two,.clubs), c(.three,.diamonds)]
        ), 1, "two pair with Q kicker beats J kicker")

        // 5. Flush kicker ordering.
        XCTAssertEqual(order(
            [c(.ace,.hearts), c(.king,.hearts), c(.queen,.hearts), c(.jack,.hearts), c(.nine,.hearts), c(.two,.spades), c(.three,.diamonds)],
            [c(.ace,.hearts), c(.king,.hearts), c(.queen,.hearts), c(.jack,.hearts), c(.eight,.hearts), c(.two,.spades), c(.three,.diamonds)]
        ), 1, "A-high flush ...9 beats ...8")

        // 6. Quad kicker ordering.
        XCTAssertEqual(order(
            [c(.seven,.spades), c(.seven,.hearts), c(.seven,.diamonds), c(.seven,.clubs), c(.ace,.spades), c(.two,.hearts), c(.three,.diamonds)],
            [c(.seven,.spades), c(.seven,.hearts), c(.seven,.diamonds), c(.seven,.clubs), c(.king,.spades), c(.two,.hearts), c(.three,.diamonds)]
        ), 1, "quad 7s with A kicker beats K kicker")

        // 7. Board plays the board (royal on board) => tie regardless of holes.
        XCTAssertEqual(order(
            [c(.two,.hearts), c(.three,.diamonds), c(.ace,.spades), c(.king,.spades), c(.queen,.spades), c(.jack,.spades), c(.ten,.spades)],
            [c(.four,.hearts), c(.five,.diamonds), c(.ace,.spades), c(.king,.spades), c(.queen,.spades), c(.jack,.spades), c(.ten,.spades)]
        ), 0, "board-plays-the-board should tie")

        // 8. Ace-high beats king-high (no pair/straight/flush).
        XCTAssertEqual(order(
            [c(.ace,.spades), c(.jack,.clubs), c(.nine,.hearts), c(.seven,.diamonds), c(.five,.clubs), c(.three,.spades), c(.two,.diamonds)],
            [c(.king,.spades), c(.jack,.clubs), c(.nine,.hearts), c(.seven,.diamonds), c(.five,.clubs), c(.three,.spades), c(.two,.diamonds)]
        ), 1, "ace-high beats king-high")
    }

    func testCategoryLadderStrictlyIncreasing() {
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
        for i in 1..<ladder.count {
            let lo = FastHandEvaluator.score(ladder[i - 1].1)
            let hi = FastHandEvaluator.score(ladder[i].1)
            XCTAssertGreaterThan(hi, lo, "\(ladder[i].0) should outrank \(ladder[i - 1].0)")
        }
    }

    /// Regression guard: FastHandEvaluator must agree with the shipping
    /// HandEvaluator's ordering across many random 7-card hand pairs.
    func testCrossCheckAgainstHandEvaluator() {
        var deck = [Card]()
        for s in Suit.allCases { for r in Rank.allCases { deck.append(Card(suit: s, rank: r)) } }

        var rng = SystemRandomNumberGenerator()
        var mismatches = 0
        let samples = 20_000

        for _ in 0..<samples {
            deck.shuffle(using: &rng)
            let a = Array(deck[0..<7])
            let b = Array(deck[7..<14])

            let fast = order(a, b)
            let brA = HandEvaluator.evaluateBestHand(from: a).value
            let brB = HandEvaluator.evaluateBestHand(from: b).value
            let slow = brA < brB ? -1 : (brA > brB ? 1 : 0)

            if fast != slow { mismatches += 1 }
        }
        XCTAssertEqual(mismatches, 0, "FastHandEvaluator disagreed with HandEvaluator on \(mismatches)/\(samples) hands")
    }
}
