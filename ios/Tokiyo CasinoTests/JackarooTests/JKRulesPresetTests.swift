//
//  JKRulesPresetTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 5
//
//  Each variant toggle has an isolated effect test, plus the two
//  variant-only edge cases the plan defers here (JACKAROO_SPEC.md §7
//  ec5 `safeEntryMode=exactOnly`, ec10 King-13 capture-along-path) and
//  one full AI-vs-AI smoke game per shipping preset.
//

import XCTest
@testable import Tokiyo_Casino

final class JKRulesPresetTests: XCTestCase {

    private let graph = JKBoardGraph()
    private func gen() -> JKLegalMoveGenerator { JKLegalMoveGenerator(graph: graph) }
    private func marble(_ id: MarbleID, in state: JKGameState) -> JKMarble {
        state.marbles.first { $0.id == id }!
    }

    // Suit-typed cards for the variant tests.
    private let king        = JKCard(suit: .clubs,    rank: .king)
    private let fiveClubs   = JKCard(suit: .clubs,    rank: .five)
    private let sevenClubs  = JKCard(suit: .clubs,    rank: .seven)
    private let redJack     = JKCard(suit: .hearts,   rank: .jack)
    private let blackJack   = JKCard(suit: .spades,   rank: .jack)
    private let redQueen    = JKCard(suit: .hearts,   rank: .queen)
    private let blackQueen  = JKCard(suit: .spades,   rank: .queen)

    // MARK: - ec10 — King-13 captures every marble it passes

    func testKingThirteen_capturesEveryMarbleAlongThePath() {
        var state = JKFixture.makeState(rules: .jawakerComplex)
        JKFixture.place(0, at: .track(5), in: &state)     // seat 0 mover
        JKFixture.place(4, at: .track(9), in: &state)     // seat 1 — passed
        JKFixture.place(8, at: .track(14), in: &state)    // seat 2 — passed
        JKFixture.setHand([king], for: 0, in: &state)

        let o = gen().walkKingThirteen(marble: marble(0, in: state), seat: 0, state: state)
        XCTAssertEqual(o?.destination, .track(18), "5 + 13 = 18")
        XCTAssertEqual(o?.captures.count, 2, "Both passed opponents are captured")
        XCTAssertEqual(Set(o?.captures ?? []), [4, 8])
    }

    func testKingThirteen_resolverSendsAllPassedMarblesHome() {
        var state = JKFixture.makeState(rules: .jawakerComplex)
        JKFixture.place(0, at: .track(5), in: &state)
        JKFixture.place(4, at: .track(9), in: &state)
        JKFixture.place(8, at: .track(14), in: &state)
        JKFixture.setHand([king], for: 0, in: &state)

        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.kingThirteen(card: king, marble: 0), by: 0, to: &state)

        XCTAssertEqual(marble(0, in: state).position, .track(18))
        if case .home = marble(4, in: state).position {} else { XCTFail("marble 4 should be Home") }
        if case .home = marble(8, in: state).position {} else { XCTFail("marble 8 should be Home") }
        let captures = state.log.filter { if case .captured = $0 { return true } else { return false } }
        XCTAssertEqual(captures.count, 2)
    }

    func testKingThirteen_blockedByProtectedBase() {
        var state = JKFixture.makeState(rules: .jawakerComplex)
        JKFixture.place(0, at: .track(20), in: &state)    // seat 0 mover
        JKFixture.place(4, at: .track(25), in: &state)    // seat 1 ON its own Base (25) — protected
        JKFixture.setHand([king], for: 0, in: &state)

        XCTAssertNil(gen().walkKingThirteen(marble: marble(0, in: state), seat: 0, state: state),
                     "A protected Base in the path blocks the 13-step King")
    }

    func testKingThirteen_generatedOnlyInComplexMode() {
        func kingMoves(_ rules: JKRulesPreset) -> [JKMove] {
            var state = JKFixture.makeState(rules: rules)
            JKFixture.place(0, at: .track(10), in: &state)   // on-track marble
            JKFixture.setHand([king], for: 0, in: &state)    // marbles 1,2,3 stay Home
            return gen().moves(in: state, for: 0)
        }
        let complex = kingMoves(.jawakerComplex)
        let basic = kingMoves(.jawakerBasic)
        XCTAssertTrue(complex.contains { if case .kingThirteen = $0 { return true } else { return false } },
                      "Complex King offers the 13-step move")
        XCTAssertFalse(basic.contains { if case .kingThirteen = $0 { return true } else { return false } },
                       "Basic King never offers the 13-step move")
    }

    // MARK: - fiveMode — any marble on track

    func testFiveAnyMarble_movesOpponentInComplexButNotBasic() {
        func fiveMoves(_ rules: JKRulesPreset) -> [JKMove] {
            var state = JKFixture.makeState(rules: rules)
            JKFixture.place(0, at: .track(40), in: &state)   // own marble (plain +5)
            JKFixture.place(4, at: .track(30), in: &state)   // opponent
            JKFixture.setHand([fiveClubs], for: 0, in: &state)
            return gen().moves(in: state, for: 0)
        }
        func targetsOpponent(_ moves: [JKMove]) -> Bool {
            moves.contains { if case let .anyMarble5(_, m, _) = $0 { return m == 4 } else { return false } }
        }
        XCTAssertTrue(targetsOpponent(fiveMoves(.jawakerComplex)),
                      "Complex 5 may move any marble on the track")
        XCTAssertFalse(targetsOpponent(fiveMoves(.jawakerBasic)),
                       "Basic 5 only moves your own marbles")
    }

    // MARK: - sevenMode — multi-own split

    func testSevenMultiOwn_splitsAcrossThreeMarbles() {
        func widestSplit(_ rules: JKRulesPreset) -> Int {
            var state = JKFixture.makeState(rules: rules)
            JKFixture.place(0, at: .track(5), in: &state)
            JKFixture.place(1, at: .track(40), in: &state)
            JKFixture.place(2, at: .track(70), in: &state)
            JKFixture.setHand([sevenClubs], for: 0, in: &state)
            let splits = gen().moves(in: state, for: 0).compactMap { move -> Int? in
                if case let .split7(_, allocs) = move { return allocs.count }
                return nil
            }
            return splits.max() ?? 0
        }
        XCTAssertGreaterThanOrEqual(widestSplit(.community), 3,
                                    "Community 7 can split across 3+ marbles")
        XCTAssertEqual(widestSplit(.jawakerBasic), 2,
                       "Basic 7 splits across exactly two marbles")
    }

    /// A multi-own 7-split that is legal *only* if the sub-steps are
    /// applied in a particular order: marble 0 sits directly behind
    /// marble 1, so marble 1 must move first to clear the path. The
    /// generator must try permuted application orders to find it.
    func testSevenMultiOwn_findsOrderDependentSplit() {
        // Keep direction cw (default seatOrder) while enabling multiOwn.
        var state = JKFixture.makeState(rules: JKRulesPreset(sevenMode: .multiOwn))
        JKFixture.place(0, at: .track(10), in: &state)   // rear
        JKFixture.place(1, at: .track(11), in: &state)   // directly ahead → blocks marble 0
        JKFixture.setHand([sevenClubs], for: 0, in: &state)

        let twoMarbleSplits = gen().moves(in: state, for: 0).compactMap { move -> [JKSplitAllocation]? in
            if case let .split7(_, allocs) = move, Set(allocs.map { $0.marble }) == [0, 1] {
                return allocs
            }
            return nil
        }
        XCTAssertFalse(twoMarbleSplits.isEmpty,
                       "Order-dependent split (move the blocker first) must be found")
        // Every emitted two-marble split must be in a legal order: the
        // blocker (marble 1) is applied before marble 0.
        for allocs in twoMarbleSplits {
            XCTAssertEqual(allocs.first?.marble, 1,
                           "Allocations must be emitted in a legal application order")
        }
    }

    /// Forcing a redeal while hands still hold cards must not leak the
    /// 52-card budget (the leftover cards fold into the Fire Pile).
    func testForcedRedeal_conservesCardBudget() {
        let players = (0..<4).map { JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced)) }
        let engine = JackarooEngine(players: players, rules: .community, seed: 0xD1CE)
        engine.start()
        engine.dealNewHand()   // hands were full — a forced mid-hand redeal
        let s = engine.state
        let total = s.deck.count + s.firePile.count + s.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52, "A forced redeal must not lose cards")
    }

    // MARK: - jackMode — red 11 / black swap

    func testRedJack_movesElevenInCommunity_swapsInBasic() {
        func jackMoves(_ rules: JKRulesPreset) -> [JKMove] {
            var state = JKFixture.makeState(rules: rules)
            JKFixture.place(0, at: .track(10), in: &state)
            JKFixture.place(4, at: .track(50), in: &state)   // a swap target, off the +11 path
            JKFixture.setHand([redJack], for: 0, in: &state)
            return gen().moves(in: state, for: 0)
        }
        let community = jackMoves(.community)
        XCTAssertTrue(community.contains { if case let .forward(_, _, s) = $0 { return s == 11 } else { return false } },
                      "Community red Jack moves forward 11")
        XCTAssertFalse(community.contains { if case .swap = $0 { return true } else { return false } },
                       "Community red Jack does not swap")

        let basic = jackMoves(.jawakerBasic)
        XCTAssertTrue(basic.contains { if case .swap = $0 { return true } else { return false } },
                      "Basic Jack (any suit) swaps")
    }

    func testBlackJack_swapsInCommunity() {
        var state = JKFixture.makeState(rules: .community)
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.place(4, at: .track(50), in: &state)
        JKFixture.setHand([blackJack], for: 0, in: &state)
        let moves = gen().moves(in: state, for: 0)
        XCTAssertTrue(moves.contains { if case .swap = $0 { return true } else { return false } },
                      "Community black Jack swaps")
        XCTAssertFalse(moves.contains { if case let .forward(_, _, s) = $0 { return s == 11 } else { return false } },
                       "Community black Jack never moves 11")
    }

    // MARK: - queenMode — red queen discard

    func testRedQueen_offersDiscardInCommunityOnly() {
        func queenMoves(_ rules: JKRulesPreset, suit: JKCard) -> [JKMove] {
            var state = JKFixture.makeState(rules: rules)
            JKFixture.place(0, at: .track(10), in: &state)
            JKFixture.setHand([suit], for: 0, in: &state)
            state.players[1].hand = [JKCard(suit: .clubs, rank: .two)]   // a victim with a card
            return gen().moves(in: state, for: 0)
        }
        func hasDiscard(_ moves: [JKMove]) -> Bool {
            moves.contains { if case .redQueenDiscard = $0 { return true } else { return false } }
        }
        XCTAssertTrue(hasDiscard(queenMoves(.community, suit: redQueen)),
                      "Community red Queen forces a discard")
        XCTAssertFalse(hasDiscard(queenMoves(.community, suit: blackQueen)),
                       "Community black Queen is a plain 12")
        XCTAssertFalse(hasDiscard(queenMoves(.jawakerBasic, suit: redQueen)),
                       "Basic Queen never forces a discard")
    }

    // MARK: - dealCycle — 4 then 5

    func testDealCycle_fourThenFive() {
        let players = (0..<4).map { JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced)) }
        let engine = JackarooEngine(players: players, rules: .community, seed: 0xD1CE)
        engine.start()
        XCTAssertTrue(engine.state.players.allSatisfy { $0.hand.count == 4 },
                      "First Community deal is 4 cards")
        engine.dealNewHand()
        XCTAssertTrue(engine.state.players.allSatisfy { $0.hand.count == 5 },
                      "Every Community deal after the first is 5 cards")
    }

    // MARK: - seatOrder — direction

    func testSeatOrder_directionPerPreset() {
        XCTAssertEqual(JKRulesPreset.jawakerBasic.direction, .cw)
        XCTAssertEqual(JKRulesPreset.community.direction, .ccw)
        XCTAssertEqual(JKFixture.makeState(rules: .community).direction, .ccw)
    }

    // MARK: - ec5 — safeEntryMode exactOnly

    func testSafeEntry_exactOnlyRequiresDeepestEmptyCell() {
        // Seat 0 gate sits at cell 98 (base 0, offset 2). A marble two
        // cells before the gate enters Safe; the deepest empty lane is 3.
        func dest(card v: Int, mode: SafeEntryMode) -> JKPosition? {
            var state = JKFixture.makeState(
                rules: JKRulesPreset(safeEntryMode: mode))
            JKFixture.place(0, at: .track(96), in: &state)
            let card = JKCard(suit: .clubs, rank: JKRank(rawValue: v)!)
            JKFixture.setHand([card], for: 0, in: &state)
            return gen().walkForward(marble: marble(0, in: state), steps: v,
                                     seat: 0, state: state, preferSafeEntry: true)?.destination
        }
        // A 6 lands exactly on lane 3 in both modes.
        XCTAssertEqual(dest(card: 6, mode: .exactOnly), .safe(lane: 3))
        XCTAssertEqual(dest(card: 6, mode: .cardValueAtMostRemaining), .safe(lane: 3))
        // A 4 would stop short (lane 1). Default allows it; exactOnly does not.
        XCTAssertEqual(dest(card: 4, mode: .cardValueAtMostRemaining), .safe(lane: 1))
        if case .safe = dest(card: 4, mode: .exactOnly) {
            XCTFail("exactOnly must reject a Safe entry short of the deepest empty cell")
        }
    }

    // MARK: - Per-preset full-game smoke

    func testEachPresetPlaysToCompletion() {
        for option in JKRulesPreset.selectableOptions {
            let players = (0..<4).map {
                JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
            }
            let engine = JackarooEngine(players: players, rules: option.preset, seed: 0x5EED &+ 1)
            engine.start()
            var n = 8000
            while engine.state.winner == nil && n > 0 { engine.stepAIIfNeeded(); n -= 1 }
            XCTAssertNotNil(engine.state.winner, "\(option.name) preset must terminate")
            XCTAssertEqual(engine.state.marbles.count, 16, "\(option.name): marble count invariant")
            let s = engine.state
            let total = s.deck.count + s.firePile.count + s.players.reduce(0) { $0 + $1.hand.count }
            XCTAssertEqual(total, 52, "\(option.name): 52-card budget invariant")
        }
    }
}
