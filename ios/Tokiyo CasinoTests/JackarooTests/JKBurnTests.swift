//
//  JKBurnTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Burn-on-no-move behaviour (JACKAROO_SPEC.md §3 + §7):
//    ec 1  — no legal move at all → burn the whole hand (default scope)
//    ec 12 — burn only when *no* card in hand has any legal move
//  plus the singleCard burn-scope variant and the resolver's effect.
//

import XCTest
@testable import Tokiyo_Casino

final class JKBurnTests: XCTestCase {

    private let graph = JKBoardGraph()
    private func gen() -> JKLegalMoveGenerator { JKLegalMoveGenerator(graph: graph) }

    // MARK: - ec 1 — nothing playable → whole-hand burn

    func testNoLegalMoveAtAll_burnsWholeHand() {
        var state = JKFixture.makeState()              // every marble in Home
        // No Ace/King → cannot field; everything else needs a marble on
        // the track → no forward/backward/7 is possible.
        let hand = [JKCard(suit: .clubs, rank: .two),
                    JKCard(suit: .diamonds, rank: .three),
                    JKCard(suit: .spades, rank: .six),
                    JKCard(suit: .hearts, rank: .ten)]
        JKFixture.setHand(hand, for: 0, in: &state)

        let moves = gen().moves(in: state, for: 0)
        XCTAssertEqual(moves.count, 1)
        XCTAssertEqual(moves.first, .burnHand(cards: hand))
        XCTAssertTrue(moves.first?.isBurn == true)
    }

    // MARK: - ec 12 — a single dead card does not trigger a burn

    func testBurnNotOffered_whenAnyCardHasAMove() {
        var state = JKFixture.makeState()
        // The 2 is dead (all marbles Home), but the Ace can field a marble.
        let dead = JKCard(suit: .clubs, rank: .two)
        JKFixture.setHand([dead, JKFixture.aceSpades], for: 0, in: &state)

        let moves = gen().moves(in: state, for: 0)
        XCTAssertFalse(moves.contains { $0.isBurn },
                       "Burn must not appear while any card has a legal move")
        XCTAssertTrue(moves.contains { if case .fieldFromHome = $0 { return true }; return false })
    }

    // MARK: - burnScope = singleCard variant

    func testSingleCardBurnScope_offersOneBurnPerDeadCard() {
        var state = JKFixture.makeState(
            rules: JKRulesPreset(burnScope: .singleCard))
        let hand = [JKCard(suit: .clubs, rank: .two),
                    JKCard(suit: .diamonds, rank: .three)]
        JKFixture.setHand(hand, for: 0, in: &state)

        let moves = gen().moves(in: state, for: 0)
        XCTAssertEqual(Set(moves), Set(hand.map { JKMove.burnCard(card: $0) }))
    }

    // MARK: - burnOnNoMove = false

    func testBurnDisabled_yieldsNoMovesWhenStuck() {
        var state = JKFixture.makeState(
            rules: JKRulesPreset(burnOnNoMove: false))
        JKFixture.setHand([JKCard(suit: .clubs, rank: .two)], for: 0, in: &state)
        XCTAssertTrue(gen().moves(in: state, for: 0).isEmpty,
                      "With burnOnNoMove off, a stuck seat produces no moves")
    }

    // MARK: - resolver effect

    func testResolverBurnHand_movesEveryCardToFirePile() {
        var state = JKFixture.makeState()
        let hand = [JKFixture.aceSpades, JKFixture.twoHearts, JKFixture.fourClubs]
        JKFixture.setHand(hand, for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.burnHand(cards: hand), by: 0, to: &state)

        XCTAssertTrue(state.players[0].hand.isEmpty)
        XCTAssertEqual(Set(state.firePile), Set(hand))
        XCTAssertTrue(state.log.contains { if case .burned(0, _) = $0 { return true }; return false })
    }

    func testResolverBurnCard_discardsOnlyThatCard() {
        var state = JKFixture.makeState()
        let dead = JKFixture.twoHearts
        let keep = JKFixture.aceSpades
        JKFixture.setHand([dead, keep], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.burnCard(card: dead), by: 0, to: &state)

        XCTAssertEqual(state.players[0].hand, [keep], "Only the burned card leaves the hand")
        XCTAssertEqual(state.firePile, [dead])
        XCTAssertTrue(state.log.contains { if case .burned(0, [dead]) = $0 { return true }; return false })
    }
}
