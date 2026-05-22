//
//  JKLegalMoveGeneratorTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Per-card legality fixtures + the §7 edge cases from the spec.
//

import XCTest
@testable import Tokiyo_Casino

final class JKLegalMoveGeneratorTests: XCTestCase {

    func testAceFromHome_fieldsToOwnBase() {
        var state = JKFixture.makeState()
        JKFixture.setHand([JKFixture.aceSpades], for: 0, in: &state)
        let gen = JKLegalMoveGenerator(graph: JKBoardGraph())
        let moves = gen.moves(in: state, for: 0)
        XCTAssertTrue(moves.contains(where: {
            if case .fieldFromHome = $0 { return true }
            return false
        }))
    }

    func testKingFromHome_fieldsToOwnBase() {
        var state = JKFixture.makeState()
        JKFixture.setHand([JKFixture.kingSpades], for: 0, in: &state)
        let gen = JKLegalMoveGenerator(graph: JKBoardGraph())
        let moves = gen.moves(in: state, for: 0)
        XCTAssertTrue(moves.contains(where: {
            if case .fieldFromHome = $0 { return true }
            return false
        }))
    }

    func testPlainForward_generatesForwardMove() {
        var state = JKFixture.makeState()
        let graph = JKBoardGraph()
        JKFixture.place(0, at: .track(graph.baseCell[0]!), in: &state)
        JKFixture.setHand([JKFixture.twoHearts], for: 0, in: &state)
        let moves = JKLegalMoveGenerator(graph: graph).moves(in: state, for: 0)
        XCTAssertTrue(moves.contains(where: {
            if case .forward(_, _, let s) = $0 { return s == 2 }
            return false
        }))
    }

    func testFourCard_generatesBackwardMove() {
        var state = JKFixture.makeState()
        let graph = JKBoardGraph()
        // Place marble two cells past Base so backward 4 isn't blocked by Home.
        let twoPast = graph.walk(from: graph.baseCell[0]!, steps: 5, direction: .cw).last!
        JKFixture.place(0, at: .track(twoPast), in: &state)
        JKFixture.setHand([JKFixture.fourClubs], for: 0, in: &state)
        let moves = JKLegalMoveGenerator(graph: graph).moves(in: state, for: 0)
        XCTAssertTrue(moves.contains(where: {
            if case .backward(_, _, let s) = $0 { return s == 4 }
            return false
        }))
    }

    func testJack_swapsOnlyOpponentOnTrackMarbles() {
        var state = JKFixture.makeState()
        let graph = JKBoardGraph()
        // Own marble on track, opponent marble on track elsewhere.
        let ownCell = graph.walk(from: graph.baseCell[0]!, steps: 5, direction: .cw).last!
        let oppCell = graph.walk(from: graph.baseCell[1]!, steps: 6, direction: .cw).last!
        JKFixture.place(0, at: .track(ownCell), in: &state)
        JKFixture.place(4, at: .track(oppCell), in: &state) // seat 1's marble #4
        JKFixture.setHand([JKFixture.jackSpades], for: 0, in: &state)
        let moves = JKLegalMoveGenerator(graph: graph).moves(in: state, for: 0)
        let swaps = moves.compactMap { (m: JKMove) -> (MarbleID, MarbleID)? in
            if case let .swap(_, own, other) = m { return (own, other) }
            return nil
        }
        XCTAssertFalse(swaps.isEmpty, "Expected a Jack swap option")
        // Partner marbles must NOT be swap targets — only opponents.
        for (_, other) in swaps {
            let owner = JKMarble.ownerOf(other)
            XCTAssertNotEqual(owner % 2, 0, "Swap target must be on Team B (opponent)")
        }
    }

    // Edge case 3 — seven-split with two-own restriction.
    func testSevenSplit_twoOwn_rejectsSingleMarbleAllocation() {
        var state = JKFixture.makeState()
        let graph = JKBoardGraph()
        // Only one of own marbles on the track — partner+opponent stay Home.
        let cell = graph.walk(from: graph.baseCell[0]!, steps: 3, direction: .cw).last!
        JKFixture.place(0, at: .track(cell), in: &state)
        JKFixture.setHand([JKFixture.sevenHearts], for: 0, in: &state)
        let moves = JKLegalMoveGenerator(graph: graph).moves(in: state, for: 0)
        // With only one ownable marble on track, a twoOwn 7 has no legal
        // pair → no split-7 should be emitted (and burn would kick in if
        // there were nothing else).
        let splits = moves.contains(where: {
            if case .split7 = $0 { return true }
            return false
        })
        XCTAssertFalse(splits, "twoOwn rejects single-marble (7,0) allocations")
    }

    // Edge case 8 — Ace 1-or-11 generates both variants when both legal.
    func testAce_generatesBothOneAndElevenWhenLegal() {
        var state = JKFixture.makeState()
        let graph = JKBoardGraph()
        let cell = graph.walk(from: graph.baseCell[0]!, steps: 3, direction: .cw).last!
        JKFixture.place(0, at: .track(cell), in: &state)
        JKFixture.setHand([JKFixture.aceSpades], for: 0, in: &state)
        let moves = JKLegalMoveGenerator(graph: graph).moves(in: state, for: 0)
        let forwardSteps = Set(moves.compactMap { (m: JKMove) -> Int? in
            if case let .forward(_, marble, s) = m, marble == 0 { return s }
            return nil
        })
        XCTAssertTrue(forwardSteps.contains(1), "Ace must offer forward-1")
        XCTAssertTrue(forwardSteps.contains(11), "Ace must offer forward-11")
    }
}
