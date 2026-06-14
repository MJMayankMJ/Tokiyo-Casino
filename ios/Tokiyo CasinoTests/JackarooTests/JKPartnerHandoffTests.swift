//
//  JKPartnerHandoffTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Partner handoff (JACKAROO_SPEC.md §3 + §7 ec 9):
//   - Handoff engages the moment a seat's 4th own marble enters Safe,
//     and from then on that seat may move its partner's marbles.
//   - A 7-split applies all of its allocations atomically in one move,
//     so the "remaining steps" of a split that completes the 4-marble
//     set still resolve on the same turn (handoff only affects *future*
//     turns).
//

import XCTest
@testable import Tokiyo_Casino

final class JKPartnerHandoffTests: XCTestCase {

    private let graph = JKBoardGraph()
    private func marble(_ id: MarbleID, in state: JKGameState) -> JKMarble {
        state.marbles.first { $0.id == id }!
    }

    func testHandoffEngages_whenFourthOwnMarbleEntersSafe() {
        var state = JKFixture.makeState()
        // Seat 0: three marbles already in Safe (deepest-first), the 4th
        // one step from entering lane 0.
        JKFixture.place(0, at: .safe(lane: 3), in: &state)
        JKFixture.place(1, at: .safe(lane: 2), in: &state)
        JKFixture.place(2, at: .safe(lane: 1), in: &state)
        JKFixture.place(3, at: .track(95), in: &state)     // distance 3 to gate 98

        let fourClubs = JKCard(suit: .clubs, rank: .four)
        JKFixture.setHand([fourClubs], for: 0, in: &state)

        XCTAssertFalse(state.handoffEngaged[0])
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.forward(card: fourClubs, marble: 3, steps: 4),
                       by: 0, to: &state)

        XCTAssertEqual(state.marbles.first { $0.id == 3 }?.position, .safe(lane: 0))
        XCTAssertTrue(state.handoffEngaged[0], "Handoff engages on the 4th marble entering Safe")
        XCTAssertNil(state.winner, "Only one team finished — game continues")
        XCTAssertTrue(state.log.contains { if case .handoffEngaged(0) = $0 { return true }; return false })
    }

    func testAfterHandoff_ownableMarblesIncludePartner() {
        var state = JKFixture.makeState()
        for (slot, id) in [0, 1, 2, 3].enumerated() {
            JKFixture.place(id, at: .safe(lane: slot), in: &state)
        }
        // Engaging the handoff is the resolver's job; trigger it with a
        // no-op-ish move so the post-move checks run. Easiest: a burn.
        JKFixture.setHand([JKCard(suit: .clubs, rank: .two)], for: 0, in: &state)
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.burnHand(cards: state.players[0].hand), by: 0, to: &state)

        XCTAssertTrue(state.handoffEngaged[0])
        let ownable = state.ownableMarbles(of: 0)
        XCTAssertEqual(ownable.count, 8, "Own 4 + partner 4 once handoff engages")
        XCTAssertTrue(ownable.contains { $0.owner == JKTeam.partner(of: 0) },
                      "Partner (seat 2) marbles become movable after handoff")
    }

    func testSevenSplit_resolvesAllAllocationsInOneMove() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.place(1, at: .track(20), in: &state)
        let seven = JKFixture.sevenHearts
        JKFixture.setHand([seven], for: 0, in: &state)

        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.split7(card: seven, allocations: [
            JKSplitAllocation(marble: 0, steps: 3),
            JKSplitAllocation(marble: 1, steps: 4),
        ]), by: 0, to: &state)

        XCTAssertEqual(state.marbles.first { $0.id == 0 }?.position, .track(13))
        XCTAssertEqual(state.marbles.first { $0.id == 1 }?.position, .track(24))
        XCTAssertEqual(state.players[0].hand.count, 0, "The single 7 card is consumed once")
    }
}
