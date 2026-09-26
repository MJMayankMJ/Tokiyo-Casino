//
//  TDPSettleTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  The settle-up rules: give up tricks (targets shift for this round only,
//  never twice in a row to the same player) or give cards (arranged by
//  hand when a person pulls, returned cards slipped in at random).
//

import XCTest
@testable import Tokiyo_Casino

final class TDPSettleTests: XCTestCase {

    // MARK: Fixtures

    /// A round-2 table at the last deal. Dealer is seat 0, so this round the
    /// selector (5) is seat 1, the third (3) seat 2, the dealer (2) seat 0.
    private func settlingEngine(deltas: [String: Int],
                                humans: Set<TDPSeat> = [0],
                                lastConcessions: [TDPConcession] = [],
                                earlier: [TDPRoundScore] = []) -> TDPEngine {
        var rng = TDPRNG(seed: 55)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        let players = (0..<3).map {
            TDPPlayer(id: "p\($0)", name: ["Aa", "Bb", "Cc"][$0], seat: $0, isAI: !humans.contains($0))
        }
        var state = TDPGameState(tableID: "settle", seed: 55, players: players)
        state.dealerSeat = 0
        state.phase = .dealTwo
        state.roundNumber = 2
        state.trump = .spades
        state.trumpMethod = .choose
        for i in 0..<3 { state.players[i].hand = Array(deck[(i * 8)..<((i + 1) * 8)]) }
        state.deck = Array(deck[24..<30])
        let quotas = ["0": 2, "1": 5, "2": 3]
        var last = TDPRoundScore(round: earlier.count + 1, dealerSeat: 2, trump: .hearts, trumpMethod: .choose,
                                 tricks: quotas.mapValues { $0 }.merging(deltas) { $0 + $1 },
                                 quotas: quotas, delta: deltas)
        last.concessions = lastConcessions
        state.roundHistory = earlier + [last]
        let engine = TDPEngine(state: state)
        XCTAssertNil(engine.apply(.dealTwo))
        return engine
    }

    private func handSizes(_ engine: TDPEngine) -> [Int] {
        engine.state.players.sorted { $0.seat < $1.seat }.map(\.hand.count)
    }

    // MARK: Choosing

    func testADebtStopsAtSettleBeforeAnyCardMoves() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0])
        XCTAssertEqual(engine.state.phase, .settle)
        XCTAssertEqual(TDPViewBuilder.prompt(state: engine.state, seat: 0), .settleUp, "The debtor decides")
        XCTAssertEqual(TDPViewBuilder.prompt(state: engine.state, seat: 1), .none, "The creditor waits")
        XCTAssertEqual(handSizes(engine), [10, 10, 10])
    }

    func testNoDebtSkipsSettlingEntirely() {
        let engine = settlingEngine(deltas: ["0": 0, "1": 0, "2": 0])
        XCTAssertEqual(engine.state.phase, .play)
    }

    func testGivingUpTricksShiftsThisRoundsTargetsAndMovesNoCards() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0])
        let handsBefore = engine.state.players.map(\.hand)
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))

        XCTAssertEqual(engine.state.phase, .play, "No pull when tricks are given up")
        XCTAssertEqual(engine.state.players.map(\.hand), handsBefore, "No card moves")
        XCTAssertEqual(engine.state.quota(at: 0), 3, "Dealer's 2 rises by the 1 owed")
        XCTAssertEqual(engine.state.quota(at: 1), 4, "Selector's 5 falls by the same 1")
        XCTAssertEqual(engine.state.quota(at: 2), 3, "The third player is untouched")
        XCTAssertEqual((0..<3).map { engine.state.quota(at: $0) }.reduce(0, +), 10,
                       "Targets must still sum to the ten tricks")
        XCTAssertEqual(engine.state.concessions, [TDPConcession(debtor: 0, creditor: 1, amount: 1)])
    }

    func testRoundRecordUsesTheShiftedTargetsAndStaysZeroSum() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))

        // Play the round out with the AI.
        var steps = 0
        while engine.state.phase != .roundEnd && engine.state.phase != .sessionEnd && steps < 500 {
            steps += 1
            engine.flushAutomatic()
            for seat in 0..<3 {
                if let action = TDPAIEngine.nextAction(state: engine.state, seat: seat) {
                    XCTAssertNil(engine.apply(action))
                    break
                }
            }
        }
        let record = try! XCTUnwrap(engine.state.roundHistory.last)
        XCTAssertEqual(record.quotas["0"], 3)
        XCTAssertEqual(record.quotas["1"], 4)
        XCTAssertEqual(record.delta.values.reduce(0, +), 0)
        XCTAssertEqual(record.concessions, [TDPConcession(debtor: 0, creditor: 1, amount: 1)])
        XCTAssertEqual(record.tricks.values.reduce(0, +), 10)
    }

    func testTargetsResetNextRound() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))
        var state = engine.state
        state.resetForNewRound()
        XCTAssertTrue(state.targetAdjust.isEmpty)
        XCTAssertTrue(state.concessions.isEmpty)
    }

    // MARK: Not twice in a row

    func testCannotGiveUpTricksToTheSameCreditorTwiceInARow() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0],
                                    lastConcessions: [TDPConcession(debtor: 0, creditor: 1, amount: 2)])
        XCTAssertTrue(TDPEngine.isGiveTricksLocked(engine.state, debtor: 0, creditor: 1))
        XCTAssertNotNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])),
                        "Second consecutive give-up to the same player must be refused")
        XCTAssertEqual(engine.state.phase, .settle)
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertEqual(engine.state.phase, .khichai)
    }

    func testGivingUpTricksToADifferentCreditorIsFine() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0],
                                    lastConcessions: [TDPConcession(debtor: 0, creditor: 2, amount: 1)])
        XCTAssertFalse(TDPEngine.isGiveTricksLocked(engine.state, debtor: 0, creditor: 1))
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))
    }

    func testTheLockOnlyCoversConsecutiveRounds() {
        // Gave tricks two rounds ago, nothing last round: a fresh debt.
        var older = TDPRoundScore(round: 1, dealerSeat: 1, trump: .clubs, trumpMethod: .choose,
                                  tricks: ["0": 2, "1": 5, "2": 3], quotas: ["0": 2, "1": 5, "2": 3],
                                  delta: ["0": 0, "1": 0, "2": 0])
        older.concessions = [TDPConcession(debtor: 0, creditor: 1, amount: 1)]
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0], earlier: [older])
        XCTAssertFalse(TDPEngine.isGiveTricksLocked(engine.state, debtor: 0, creditor: 1))
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))
    }

    // MARK: Several creditors

    func testEachCreditorGetsItsOwnChoice() {
        // Seat 0 owes seat 1 two and seat 2 one.
        let engine = settlingEngine(deltas: ["0": -3, "1": 2, "2": 1])
        XCTAssertNotNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])),
                        "Every debt needs a choice")
        XCTAssertNotNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks, 2: .giveCards, 3: .giveCards])),
                        "No choices for players you don't owe")
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks, 2: .giveCards])))

        XCTAssertEqual(engine.state.quota(at: 0), 4, "2 + the 2 given up to seat 1")
        XCTAssertEqual(engine.state.quota(at: 1), 3)
        XCTAssertEqual(engine.state.quota(at: 2), 3, "Seat 2 chose cards, so its target stands")
        XCTAssertEqual(engine.state.phase, .khichai)
        XCTAssertEqual(engine.state.khichaiCurrent?.creditorSeat, 2)
        XCTAssertTrue(engine.state.khichaiQueue.isEmpty, "Only seat 2's single card is pulled")
    }

    func testOnlyTheDebtorMaySettleAndOnlyOnce() {
        let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0])
        XCTAssertNotNil(engine.apply(.settle(seat: 1, choices: [0: .giveTricks])))
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertNotNil(engine.apply(.settle(seat: 0, choices: [1: .giveTricks])))
    }

    // MARK: Arranging

    func testArrangingWindowOpensOnlyWhenAPersonPullsFromAPerson() {
        let people = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(people.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertEqual(people.state.khichaiCurrent?.arranging, true)
        XCTAssertEqual(TDPViewBuilder.prompt(state: people.state, seat: 0), .arrangeCards)
        XCTAssertNotNil(people.apply(.khichaiDraw(seat: 1, fanIndex: 0)), "Nobody pulls while arranging")

        let botPulls = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0])
        XCTAssertNil(botPulls.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertEqual(botPulls.state.khichaiCurrent?.arranging, false,
                       "A bot picks blind at random, so no window")

        let botGives = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [1])
        XCTAssertEqual(botGives.state.phase, .settle)
        let choice = TDPAIEngine.nextAction(state: botGives.state, seat: 0)
        XCTAssertNotNil(choice)
        XCTAssertNil(botGives.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertEqual(botGives.state.khichaiCurrent?.arranging, false, "A bot debtor shuffles instantly")
    }

    func testTheArrangedOrderIsWhatThePullerPicksFrom() {
        let engine = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        let hand = engine.state.player(at: 0)!.hand
        let order = hand.map(\.tdpID).reversed().map { $0 }
        XCTAssertNil(engine.apply(.khichaiArrange(seat: 0, order: order, done: true)))
        XCTAssertEqual(engine.state.khichaiCurrent?.arranging, false)

        XCTAssertNil(engine.apply(.khichaiDraw(seat: 1, fanIndex: 0)))
        XCTAssertEqual(engine.state.khichaiCurrent?.drawnCard?.tdpID, order[0],
                       "Position 0 is the debtor's first card in their own order")
    }

    func testArrangeRejectsAnythingButAPermutationOfYourOwnHand() {
        let engine = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        let ids = engine.state.player(at: 0)!.hand.map(\.tdpID)
        XCTAssertNotNil(engine.apply(.khichaiArrange(seat: 0, order: Array(ids.dropLast()), done: false)))
        XCTAssertNotNil(engine.apply(.khichaiArrange(seat: 0, order: ids.dropLast() + [ids[0]], done: false)))
        let someoneElses = engine.state.player(at: 1)!.hand[0].tdpID
        XCTAssertNotNil(engine.apply(.khichaiArrange(seat: 0, order: ids.dropLast() + [someoneElses], done: false)))
        XCTAssertNotNil(engine.apply(.khichaiArrange(seat: 1, order: ids, done: false)), "Only the debtor arranges")
        XCTAssertNil(engine.apply(.khichaiArrange(seat: 0, order: ids.reversed(), done: false)))
        XCTAssertEqual(engine.state.khichaiCurrent?.arranging, true, "Not done yet — the window stays open")
    }

    func testTheWindowClosesOnTimeout() {
        let engine = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertNil(engine.apply(.khichaiArrangeTimeout))
        XCTAssertEqual(engine.state.khichaiCurrent?.arranging, false)
        XCTAssertNotNil(engine.apply(.khichaiArrangeTimeout), "Nothing left to time out")
        XCTAssertNil(engine.apply(.khichaiDraw(seat: 1, fanIndex: 3)))
    }

    func testReturnedCardIsSlippedInAndTheOrderIsNotReopened() {
        let engine = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertNil(engine.apply(.khichaiArrangeTimeout))

        XCTAssertNil(engine.apply(.khichaiDraw(seat: 1, fanIndex: 2)))
        let drawn = engine.state.khichaiCurrent!.drawnCard!
        XCTAssertFalse(engine.state.arrangements["0"]!.contains(drawn.tdpID), "Pulled card leaves the order")
        let giveBack = TDPKhichai.legalReturns(hand: engine.state.player(at: 1)!.hand, drawn: drawn).first!
        XCTAssertNil(engine.apply(.khichaiReturn(seat: 1, cardID: giveBack.tdpID)))

        let order = engine.state.arrangements["0"]!
        let hand = engine.state.player(at: 0)!.hand
        XCTAssertEqual(order.count, 10)
        XCTAssertEqual(Set(order), Set(hand.map(\.tdpID)), "The order always matches the debtor's hand")
        XCTAssertTrue(order.contains(giveBack.tdpID))

        // Second pull of two: same debtor, so no new arranging window.
        XCTAssertEqual(engine.state.khichaiCurrent?.debtorSeat, 0)
        XCTAssertEqual(engine.state.khichaiCurrent?.arranging, false)
        XCTAssertNil(engine.apply(.khichaiDraw(seat: 1, fanIndex: 0)))
        XCTAssertEqual(engine.state.khichaiCurrent?.drawnCard?.tdpID, order[0])
    }

    func testReturnedCardPositionVariesSoItCannotBeTracked() {
        var positions: Set<Int> = []
        for seed in UInt32(1)...40 {
            let engine = settlingEngine(deltas: ["0": -1, "1": 1, "2": 0], humans: [0, 1])
            var state = engine.state
            state.rng = TDPRNG(seed: seed)
            let reseeded = TDPEngine(state: state)
            XCTAssertNil(reseeded.apply(.settle(seat: 0, choices: [1: .giveCards])))
            XCTAssertNil(reseeded.apply(.khichaiArrangeTimeout))
            XCTAssertNil(reseeded.apply(.khichaiDraw(seat: 1, fanIndex: 0)))
            let drawn = reseeded.state.khichaiCurrent!.drawnCard!
            let giveBack = TDPKhichai.legalReturns(hand: reseeded.state.player(at: 1)!.hand, drawn: drawn).first!
            XCTAssertNil(reseeded.apply(.khichaiReturn(seat: 1, cardID: giveBack.tdpID)))
            positions.insert(reseeded.state.arrangements["0"]!.firstIndex(of: giveBack.tdpID)!)
        }
        XCTAssertGreaterThan(positions.count, 5, "The returned card must land in varied positions")
    }

    // MARK: Privacy

    func testTheArrangedOrderGoesOnlyToTheDebtor() {
        let engine = settlingEngine(deltas: ["0": -2, "1": 2, "2": 0], humans: [0, 1])
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        let debtor = TDPViewBuilder.view(from: engine.state, for: 0, isHost: true, arrangeSecondsLeft: 7)
        let creditor = TDPViewBuilder.view(from: engine.state, for: 1, isHost: false, arrangeSecondsLeft: 7)
        let observer = TDPViewBuilder.view(from: engine.state, for: 2, isHost: false, arrangeSecondsLeft: 7)

        XCTAssertEqual(debtor.myArrangement?.count, 10)
        XCTAssertNil(creditor.myArrangement, "The puller must never learn the order")
        XCTAssertNil(observer.myArrangement)
        XCTAssertEqual(creditor.khichai?.isArranging, true)
        XCTAssertEqual(creditor.khichai?.arrangeSecondsLeft, 7, "Everyone sees the same clock")
        XCTAssertEqual(creditor.khichai?.pullTotal, 2)
    }

    func testSettleViewShowsOnlyYourOwnDebtsAndTheLock() {
        let engine = settlingEngine(deltas: ["0": -3, "1": 2, "2": 1],
                                    lastConcessions: [TDPConcession(debtor: 0, creditor: 1, amount: 1)])
        let mine = TDPViewBuilder.view(from: engine.state, for: 0, isHost: true).settlement
        XCTAssertEqual(mine?.mine.count, 2)
        XCTAssertEqual(mine?.mine.first { $0.creditorSeat == 1 }?.giveTricksLocked, true)
        XCTAssertEqual(mine?.mine.first { $0.creditorSeat == 2 }?.giveTricksLocked, false)
        XCTAssertEqual(mine?.waitingOn, [0])
        let theirs = TDPViewBuilder.view(from: engine.state, for: 1, isHost: false).settlement
        XCTAssertEqual(theirs?.mine.count, 0)
        XCTAssertEqual(theirs?.waitingOn, [0])
    }

    // MARK: Wire

    func testSettleAndArrangeIntentsMapToEngineActions() {
        let settle = TDPIntent(kind: .settle, settlements: [
            TDPSettleChoice(creditorSeat: 1, method: .giveTricks),
            TDPSettleChoice(creditorSeat: 2, method: .giveCards)
        ])
        XCTAssertEqual(settle.action(for: 0), .settle(seat: 0, choices: [1: .giveTricks, 2: .giveCards]))

        let duplicate = TDPIntent(kind: .settle, settlements: [
            TDPSettleChoice(creditorSeat: 1, method: .giveTricks),
            TDPSettleChoice(creditorSeat: 1, method: .giveCards)
        ])
        XCTAssertNil(duplicate.action(for: 0), "Conflicting choices for one creditor are malformed")

        let arrange = TDPIntent(kind: .arrange, order: ["AS", "KS"], done: true)
        XCTAssertEqual(arrange.action(for: 2), .khichaiArrange(seat: 2, order: ["AS", "KS"], done: true))
        XCTAssertNil(TDPIntent(kind: .arrange).action(for: 2), "An arrange intent needs an order")
    }

    // MARK: AI

    func testTheAIUsesBothWaysToSettleAndNeverBreaksTheRules() {
        var methods: Set<TDPSettleMethod> = []
        var sawPull = false
        for seed in UInt32(300)...420 {
            let engine = TDPEngine(tableID: "ai", seed: seed, players: [
                TDPPlayer(id: "p0", name: "Aa", seat: 0),
                TDPPlayer(id: "p1", name: "Bb", seat: 1, isAI: true),
                TDPPlayer(id: "p2", name: "Cc", seat: 2, isAI: true)
            ])
            engine.apply(.setTargetRounds(seat: 0, rounds: 6))
            for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }
            var steps = 0
            while engine.state.phase != .sessionEnd && steps < 20_000 {
                steps += 1
                engine.flushAutomatic()
                if engine.state.phase == .khichai { sawPull = true }
                if engine.state.phase == .roundEnd {
                    XCTAssertEqual(engine.state.roundHistory.last?.delta.values.reduce(0, +), 0)
                    engine.apply(.beginNextRound)
                    continue
                }
                var acted = false
                for seat in 0..<3 {
                    guard let action = TDPAIEngine.nextAction(state: engine.state, seat: seat) else { continue }
                    if case .settle(_, let choices) = action { methods.formUnion(choices.values) }
                    XCTAssertNil(engine.apply(action), "AI broke a rule in \(engine.state.phase)")
                    acted = true
                    break
                }
                if !acted { engine.flushAutomatic() }
            }
            XCTAssertEqual(engine.state.phase, .sessionEnd, "seed \(seed) stalled")
            if methods.count == 2 && sawPull { break }
        }
        XCTAssertEqual(methods, [.giveTricks, .giveCards], "The AI should use both ways to settle")
        XCTAssertTrue(sawPull, "Cards should still be pulled in ordinary play")
    }
}
