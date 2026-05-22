//
//  JKMoveResolverTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Apply-and-verify tests for every card type's effect on state.
//

import XCTest
@testable import Tokiyo_Casino

final class JKMoveResolverTests: XCTestCase {

    func testFieldFromHome_movesMarbleToBase() {
        let graph = JKBoardGraph()
        var state = JKFixture.makeState()
        JKFixture.setHand([JKFixture.aceSpades], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.fieldFromHome(card: JKFixture.aceSpades, marble: 0),
                       by: 0, to: &state)
        if case .track(let cell) = state.marbles[0].position {
            XCTAssertEqual(cell, graph.baseCell[0])
        } else {
            XCTFail("Marble should be on Base after fielding")
        }
        XCTAssertEqual(state.firePile.last, JKFixture.aceSpades)
        XCTAssertEqual(state.players[0].hand.count, 0)
    }

    func testForward_capturesOpponentOnLandingCell() {
        let graph = JKBoardGraph()
        var state = JKFixture.makeState()
        let ownStart = graph.walk(from: graph.baseCell[0]!, steps: 3, direction: .cw).last!
        let target = graph.walk(from: ownStart, steps: 2, direction: .cw).last!
        JKFixture.place(0, at: .track(ownStart), in: &state)
        JKFixture.place(4, at: .track(target), in: &state) // seat 1 marble
        JKFixture.setHand([JKFixture.twoHearts], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.forward(card: JKFixture.twoHearts, marble: 0, steps: 2),
                       by: 0, to: &state)
        // Captured marble should be Home now.
        if case .home = state.marbles[4].position {
            // ok
        } else {
            XCTFail("Captured marble must return Home")
        }
        // Our marble took the destination cell.
        if case .track(let cell) = state.marbles[0].position {
            XCTAssertEqual(cell, target)
        } else {
            XCTFail("Mover must land on target")
        }
    }

    func testSwap_exchangesPositions() {
        let graph = JKBoardGraph()
        var state = JKFixture.makeState()
        let cellA = graph.walk(from: graph.baseCell[0]!, steps: 3, direction: .cw).last!
        let cellB = graph.walk(from: graph.baseCell[1]!, steps: 5, direction: .cw).last!
        JKFixture.place(0, at: .track(cellA), in: &state)
        JKFixture.place(4, at: .track(cellB), in: &state)
        JKFixture.setHand([JKFixture.jackSpades], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.swap(card: JKFixture.jackSpades, ownMarble: 0, otherMarble: 4),
                       by: 0, to: &state)
        if case .track(let c0) = state.marbles[0].position,
           case .track(let c4) = state.marbles[4].position {
            XCTAssertEqual(c0, cellB)
            XCTAssertEqual(c4, cellA)
        } else {
            XCTFail("Swap should have exchanged track positions")
        }
    }

    func testSafeEntry_consumesCardValueAcrossPath() {
        let graph = JKBoardGraph()
        var state = JKFixture.makeState()
        // Place own marble 3 cells before the Safe gate.
        let cell = graph.walk(from: graph.safeGateCell[0]!,
                              steps: graph.trackCells.count - 3,
                              direction: .cw).last!
        JKFixture.place(0, at: .track(cell), in: &state)
        let five = JKCard(suit: .clubs, rank: .five)
        JKFixture.setHand([five], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.forward(card: five, marble: 0, steps: 5),
                       by: 0, to: &state)
        // 5 = 3 to gate + 2 inside Safe → land at safe lane index 1.
        if case .safe(let lane) = state.marbles[0].position {
            XCTAssertEqual(lane, 1)
        } else {
            XCTFail("Marble should have entered own Safe lane")
        }
    }

    func testBurnHand_discardsAllCardsToFirePile() {
        let graph = JKBoardGraph()
        var state = JKFixture.makeState()
        let hand = [JKFixture.aceSpades, JKFixture.twoHearts, JKFixture.fourClubs]
        JKFixture.setHand(hand, for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.burnHand(cards: hand), by: 0, to: &state)
        XCTAssertEqual(state.players[0].hand.count, 0)
        XCTAssertEqual(Set(state.firePile), Set(hand))
    }
}
