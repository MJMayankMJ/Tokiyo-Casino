//
//  TDPEngineTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//

import XCTest
@testable import Tokiyo_Casino

final class TDPEngineTests: XCTestCase {

    // MARK: Helpers

    private func makePlayers() -> [TDPPlayer] {
        [
            TDPPlayer(id: "p0", name: "Aa", seat: 0),
            TDPPlayer(id: "p1", name: "Bb", seat: 1, isAI: true),
            TDPPlayer(id: "p2", name: "Cc", seat: 2, isAI: true)
        ]
    }

    private func makeEngine(seed: UInt32 = 42) -> TDPEngine {
        TDPEngine(tableID: "T", seed: seed, players: makePlayers())
    }

    /// Runs a complete session with every seat driven by the AI.
    @discardableResult
    private func runAISession(seed: UInt32,
                              rounds: Int = 3,
                              difficulty: TDPAIDifficulty = .medium) -> TDPEngine {
        let engine = makeEngine(seed: seed)
        engine.apply(.setTargetRounds(seat: 0, rounds: rounds))
        for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }

        var guard_ = 0
        while engine.state.phase != .sessionEnd && guard_ < 20_000 {
            guard_ += 1
            engine.flushAutomatic()
            if engine.state.phase == .roundEnd {
                engine.apply(.beginNextRound)
                continue
            }
            if engine.state.phase == .sessionEnd { break }
            var acted = false
            for seat in 0..<3 {
                if let action = TDPAIEngine.nextAction(state: engine.state,
                                                       seat: seat,
                                                       difficulty: difficulty) {
                    let error = engine.apply(action)
                    XCTAssertNil(error, "AI produced an illegal action: \(String(describing: error)) in \(engine.state.phase)")
                    acted = true
                    break
                }
            }
            if !acted { engine.flushAutomatic() }
            if !acted && engine.state.phase == .play {
                XCTFail("Stuck in play with no actor. turn=\(String(describing: engine.state.currentTurnSeat))")
                break
            }
        }
        XCTAssertLessThan(guard_, 20_000, "Session did not terminate")
        return engine
    }

    // MARK: Pack

    func testPackIs30CardsWithOnlyRedAndSpadeSevens() {
        let deck = TDPDeck.build()
        XCTAssertEqual(deck.count, 30)
        XCTAssertEqual(Set(deck.map(\.tdpID)).count, 30, "No duplicates")

        let sevens = deck.filter { $0.rank == .seven }
        XCTAssertEqual(Set(sevens.map(\.suit)), [.hearts, .spades])

        XCTAssertFalse(deck.contains { $0.rank.rawValue < 7 }, "No card below a 7")
        XCTAssertEqual(deck.filter { $0.suit == .spades }.count, 8)
        XCTAssertEqual(deck.filter { $0.suit == .hearts }.count, 8)
        XCTAssertEqual(deck.filter { $0.suit == .diamonds }.count, 7)
        XCTAssertEqual(deck.filter { $0.suit == .clubs }.count, 7)
    }

    func testCardWireRoundTrip() {
        for card in TDPDeck.build() {
            XCTAssertEqual(Card(tdpID: card.tdpID), card, "Round trip failed for \(card.tdpID)")
        }
        let data = try! JSONEncoder().encode(TDPDeck.build())
        let decoded = try! JSONDecoder().decode([Card].self, from: data)
        XCTAssertEqual(decoded, TDPDeck.build())
    }

    // MARK: Roles

    func testQuotasAndRotation() {
        for dealer in 0..<3 {
            XCTAssertEqual(TDPRoles.quota(seat: dealer, dealerSeat: dealer), 2)
            XCTAssertEqual(TDPRoles.quota(seat: TDPRoles.nextSeat(dealer), dealerSeat: dealer), 5)
            XCTAssertEqual(TDPRoles.quota(seat: TDPRoles.prevSeat(dealer), dealerSeat: dealer), 3)

            let total = (0..<3).map { TDPRoles.quota(seat: $0, dealerSeat: dealer) }.reduce(0, +)
            XCTAssertEqual(total, 10, "Quotas must sum to the trick count")
        }
        // Three rotations return the deal to where it started.
        var seat = 0
        for _ in 0..<3 { seat = TDPRoles.rotateDealer(seat) }
        XCTAssertEqual(seat, 0)
    }

    // MARK: Dealing

    func testDealGivesTenCardsEachAndExhaustsThePack() {
        let engine = makeEngine()
        for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }
        engine.flushAutomatic()                                  // resolve dealer draw + deal 5
        XCTAssertEqual(engine.state.phase, .trumpSelect)
        for player in engine.state.players {
            XCTAssertEqual(player.hand.count, 5)
        }
        let selector = engine.state.trumpSelectorSeat!
        engine.apply(.selectTrumpSuit(seat: selector, suit: .spades))
        engine.flushAutomatic()

        for player in engine.state.players {
            XCTAssertEqual(player.hand.count, 10, "Every seat holds 10 after the 5-3-2 deal")
        }
        let all = engine.state.players.flatMap(\.hand)
        XCTAssertEqual(Set(all.map(\.tdpID)).count, 30, "All 30 cards dealt, none duplicated")
    }

    func testSeventhCardTrumpUsesMiddleOfBatchOfThree() {
        let engine = makeEngine(seed: 7)
        for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }
        engine.flushAutomatic()
        let selector = engine.state.trumpSelectorSeat!
        engine.apply(.selectTrumpSeventh(seat: selector))
        engine.flushAutomatic()

        let revealed = engine.state.revealedTrumpCard
        XCTAssertNotNil(revealed, "The seventh card must be made public")
        XCTAssertEqual(engine.state.trump, revealed?.suit)
        XCTAssertTrue(engine.state.player(at: selector)!.hand.contains(revealed!),
                      "The opened card stays in the selector's hand")
    }

    func testHighestOfThreeKeepsTheCardPrivate() {
        let engine = makeEngine(seed: 11)
        for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }
        engine.flushAutomatic()
        let selector = engine.state.trumpSelectorSeat!
        engine.apply(.selectTrumpHighestOfThree(seat: selector))
        engine.flushAutomatic()

        XCTAssertNil(engine.state.revealedTrumpCard, "Nothing is turned up under highest-of-three")
        XCTAssertNotNil(engine.state.privateTrumpCard)
        XCTAssertEqual(engine.state.trump, engine.state.privateTrumpCard?.suit)
    }

    // MARK: Legal moves

    func testMustFollowSuitAndAllowsAnyOpeningLead() {
        let engine = makeEngine(seed: 3)
        for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }
        engine.flushAutomatic()
        let selector = engine.state.trumpSelectorSeat!
        engine.apply(.selectTrumpSuit(seat: selector, suit: .hearts))
        engine.flushAutomatic()
        XCTAssertEqual(engine.state.phase, .play)

        // Traditional 5-3-2 allows any opening lead, including trump.
        let hand = engine.state.player(at: selector)!.hand
        XCTAssertEqual(Set(TDPLegalMoves.legalCards(engine.state, seat: selector)), Set(hand))

        // Lead a legal card, then the next seat must follow suit if able.
        let lead = hand.first(where: { $0.suit == .hearts }) ?? hand[0]
        XCTAssertNil(engine.apply(.playCard(seat: selector, cardID: lead.tdpID)))

        let follower = TDPRoles.nextSeat(selector)
        let followerHand = engine.state.player(at: follower)!.hand
        if followerHand.contains(where: { $0.suit == lead.suit }) {
            let legal = TDPLegalMoves.legalCards(engine.state, seat: follower)
            XCTAssertTrue(legal.allSatisfy { $0.suit == lead.suit }, "Must follow the led suit")
            if let offSuit = followerHand.first(where: { $0.suit != lead.suit }) {
                XCTAssertNotNil(engine.apply(.playCard(seat: follower, cardID: offSuit.tdpID)))
            }
        }
    }

    func testTrickWinnerRules() {
        let plays: [TDPTrickPlay] = [
            .init(seat: 0, card: Card(suit: .hearts, rank: .king)),
            .init(seat: 1, card: Card(suit: .hearts, rank: .ace)),
            .init(seat: 2, card: Card(suit: .clubs, rank: .ace))     // discard, cannot win
        ]
        XCTAssertEqual(TDPLegalMoves.trickWinner(plays: plays, trump: .spades, leadSuit: .hearts), 1)

        let trumped: [TDPTrickPlay] = [
            .init(seat: 0, card: Card(suit: .hearts, rank: .ace)),
            .init(seat: 1, card: Card(suit: .spades, rank: .seven)),  // lowest trump beats an ace
            .init(seat: 2, card: Card(suit: .hearts, rank: .king))
        ]
        XCTAssertEqual(TDPLegalMoves.trickWinner(plays: trumped, trump: .spades, leadSuit: .hearts), 1)
    }

    // MARK: Scoring

    func testDeltasAndCumulativeTrickScoresStayConsistent() {
        for seed in UInt32(1)...1_000 {
            let engine = runAISession(seed: seed, rounds: 3)
            for round in engine.state.roundHistory {
                XCTAssertEqual(round.delta.values.reduce(0, +), 0,
                               "Round \(round.round) of seed \(seed) is not zero-sum")
                XCTAssertEqual(round.tricks.values.reduce(0, +), 10,
                               "Every round must distribute exactly 10 tricks")
            }
            XCTAssertEqual(engine.state.scores.values.reduce(0, +), 30,
                           "Three rounds must award all 30 trick points")
            for player in engine.state.players {
                let expected = engine.state.roundHistory.reduce(0) {
                    $0 + ($1.tricks[String(player.seat)] ?? 0)
                }
                XCTAssertEqual(engine.state.score(at: player.seat), expected)
            }
        }
    }

    func testDebtPairingBalances() {
        let players = makePlayers()
        let deltas = ["0": 3, "1": -1, "2": -2]
        let debts = TDPScoring.computeDebts(players: players, deltas: deltas, dealerSeat: 2)
        XCTAssertEqual(debts.reduce(0) { $0 + $1.amount }, 3)
        XCTAssertEqual(Set(debts.map(\.to)), [0])
        XCTAssertEqual(Set(debts.map(\.from)), [1, 2])
    }

    func testPullOrderingIsRoleRelativeNotAbsoluteSeatOrder() {
        let players = makePlayers()

        // Dealer 1 => selector 2, third 0. Creditors pull in that role order.
        let twoCreditors = TDPScoring.computeDebts(
            players: players,
            deltas: ["0": 2, "1": -3, "2": 1],
            dealerSeat: 1
        )
        XCTAssertEqual(twoCreditors.map(\.to), [2, 0])

        // Debtors are drained dealer first, then third, then selector.
        let twoDebtors = TDPScoring.computeDebts(
            players: players,
            deltas: ["0": -2, "1": -1, "2": 3],
            dealerSeat: 1
        )
        XCTAssertEqual(twoDebtors.map(\.from), [1, 0])
    }

    // MARK: Khichai

    func testKhichaiPreservesCardCountsAndEnforcesClassicReturnRules() {
        var rng = TDPRNG(seed: 5)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        let creditorHand = TDPDeck.sortHand(Array(deck[0..<10]))
        let debtorHand = TDPDeck.sortHand(Array(deck[10..<20]))

        let fan = TDPKhichai.makeFanOrder(count: debtorHand.count, rng: &rng)
        XCTAssertEqual(Set(fan), Set(0..<10), "The fan is a permutation of the hand")

        guard case .success(let drawn) = TDPKhichai.resolveDraw(
            debtorHand: debtorHand, fanOrder: fan, fanIndex: 0, rng: &rng
        ) else { return XCTFail("Draw failed") }

        // Creditor is holding 11 at the point of decision.
        let hands = TDPKhichai.Hands(
            creditor: creditorHand + [drawn],
            debtor: debtorHand.filter { $0.tdpID != drawn.tdpID }
        )
        let returning = TDPKhichai.legalReturns(hand: hands.creditor, drawn: drawn).first!

        guard case .success(let after) = TDPKhichai.applyReturn(
            hands: hands, drawn: drawn, returnCardID: returning.tdpID
        ) else { return XCTFail("Decision failed") }

        XCTAssertEqual(after.creditor.count, 10)
        XCTAssertEqual(after.debtor.count, 10)
        XCTAssertTrue(after.creditor.contains(drawn), "Kept card stays")
        XCTAssertTrue(after.debtor.contains(returning), "Returned card lands with the debtor")
        XCTAssertEqual(Set((after.creditor + after.debtor).map(\.tdpID)).count, 20, "No card lost or cloned")

    }

    func testDrawnCardCannotBeReturned() {
        var rng = TDPRNG(seed: 9)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        let creditor = Array(deck[0..<10])
        let debtor = Array(deck[10..<20])
        let drawn = debtor[3]

        let hands = TDPKhichai.Hands(creditor: creditor + [drawn],
                                     debtor: debtor.filter { $0.tdpID != drawn.tdpID })
        guard case .failure = TDPKhichai.applyReturn(
            hands: hands, drawn: drawn, returnCardID: drawn.tdpID
        ) else { return XCTFail("R1 must reject returning the card just pulled") }
    }

    func testRetainTwoRestrictionAlwaysLeavesALegalReturn() {
        // Pigeonhole: 11 cards over 4 suits always leaves a legal return.
        var rng = TDPRNG(seed: 99)
        for _ in 0..<2_000 {
            let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
            let hand = Array(deck[0..<11])
            let drawn = hand[rng.int(upperBound: hand.count)]
            let legal = TDPKhichai.legalReturns(hand: hand, drawn: drawn)
            XCTAssertFalse(legal.isEmpty)
            for card in legal {
                XCTAssertNotEqual(card.tdpID, drawn.tdpID, "R1: cannot return the drawn card")
                let remaining = hand.filter { $0.suit == card.suit && $0.tdpID != card.tdpID }.count
                XCTAssertGreaterThanOrEqual(remaining, 2, "R2: must keep two of the returned suit")
            }
        }
    }

    func testInvalidFanPermutationIsRejected() {
        var rng = TDPRNG(seed: 17)
        let hand = Array(TDPDeck.build().prefix(10))
        let invalidFan = Array(repeating: 0, count: 10)
        guard case .failure = TDPKhichai.resolveDraw(
            debtorHand: hand, fanOrder: invalidFan, fanIndex: nil, rng: &rng
        ) else { return XCTFail("A corrupt fan must fail instead of indexing unsafe state") }
    }

    func testKhichaiUsesPreviousRoundDeltaAndDoesNotRewriteScore() {
        var rng = TDPRNG(seed: 55)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        var state = TDPGameState(tableID: "classic", seed: 55, players: makePlayers())
        state.dealerSeat = 0
        state.phase = .dealTwo
        state.roundNumber = 2
        state.trump = .spades
        state.trumpMethod = .choose
        state.players[0].hand = Array(deck[0..<8])
        state.players[1].hand = Array(deck[8..<16])
        state.players[2].hand = Array(deck[16..<24])
        state.deck = Array(deck[24..<30])
        state.scores = ["0": 9, "1": 0, "2": 1] // deliberately conflicts with last delta
        state.roundHistory = [TDPRoundScore(
            round: 1,
            dealerSeat: 2,
            trump: .hearts,
            trumpMethod: .choose,
            tricks: ["0": 2, "1": 6, "2": 2],
            quotas: ["0": 3, "1": 5, "2": 2],
            delta: ["0": -1, "1": 1, "2": 0]
        )]

        let engine = TDPEngine(state: state)
        XCTAssertNil(engine.apply(.dealTwo))
        XCTAssertEqual(engine.state.phase, .khichai)
        XCTAssertEqual(engine.state.khichaiCurrent?.creditorSeat, 1)
        XCTAssertEqual(engine.state.khichaiCurrent?.debtorSeat, 0)

        let scoresBefore = engine.state.scores
        XCTAssertNil(engine.apply(.khichaiDraw(seat: 1, fanIndex: 0)))
        let creditor = engine.state.player(at: 1)!
        let drawn = engine.state.khichaiCurrent!.drawnCard!
        let returning = TDPKhichai.legalReturns(hand: creditor.hand, drawn: drawn).first!
        XCTAssertNil(engine.apply(.khichaiReturn(seat: 1, cardID: returning.tdpID)))
        XCTAssertEqual(engine.state.phase, .play)
        XCTAssertEqual(engine.state.scores, scoresBefore, "Classic khichai changes cards, not score")
    }

    func testDealerTieRefillsDrawPack() {
        var state = TDPGameState(tableID: "tie", seed: 1, players: makePlayers())
        state.phase = .dealerDraw
        state.dealerDrawGroup = [0, 1]
        state.dealerDrawPending = []
        state.deck = []
        state.players[0].drawnCard = Card(suit: .spades, rank: .ace)
        state.players[1].drawnCard = Card(suit: .hearts, rank: .ace)

        let engine = TDPEngine(state: state)
        XCTAssertNil(engine.apply(.resolveDealerDraw))
        XCTAssertEqual(engine.state.dealerDrawPending, [0, 1])
        XCTAssertEqual(engine.state.deck.count, TDPDeck.size)
    }

    // MARK: Full session

    func testFullAISessionCompletesAndConservesCards() {
        let engine = runAISession(seed: 2026, rounds: 3)
        XCTAssertEqual(engine.state.phase, .sessionEnd)
        XCTAssertEqual(engine.state.roundHistory.count, 3)
        for player in engine.state.players {
            XCTAssertTrue(player.hand.isEmpty, "Every card is played by the end of a round")
        }
    }

    func testEasyAIIsReplayableForTheSameSeed() {
        let first = runAISession(seed: 808, difficulty: .easy)
        let second = runAISession(seed: 808, difficulty: .easy)
        XCTAssertEqual(first.state.roundHistory, second.state.roundHistory)
        XCTAssertEqual(first.state.scores, second.state.scores)
    }

    func testCardConservationThroughEveryRound() {
        for seed in UInt32(100)...115 {
            let engine = makeEngine(seed: seed)
            engine.apply(.setTargetRounds(seat: 0, rounds: 3))
            for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }

            var steps = 0
            while engine.state.phase != .sessionEnd && steps < 20_000 {
                steps += 1
                engine.flushAutomatic()
                if engine.state.phase == .roundEnd { engine.apply(.beginNextRound); continue }
                if engine.state.phase == .sessionEnd { break }

                // Once dealt, the cards in hand plus the cards on the table
                // plus the cards already taken must always be 30.
                if engine.state.phase == .play || engine.state.phase == .khichai {
                    let inHands = engine.state.players.reduce(0) { $0 + $1.hand.count }
                    let onTable = engine.state.currentTrick.count
                    let played = engine.state.trickNumber * 3
                    XCTAssertEqual(inHands + onTable + played, 30,
                                   "Card conservation broke on seed \(seed) in \(engine.state.phase)")
                }

                var acted = false
                for seat in 0..<3 {
                    if let action = TDPAIEngine.nextAction(state: engine.state, seat: seat) {
                        XCTAssertNil(engine.apply(action))
                        acted = true
                        break
                    }
                }
                if !acted { engine.flushAutomatic() }
            }
            XCTAssertEqual(engine.state.phase, .sessionEnd, "seed \(seed) did not finish")
        }
    }

    func testKhichaiActuallyOccursDuringNormalPlay() {
        // The settlement and pull paths are only reachable once someone is
        // behind, so assert they genuinely fire in ordinary AI play rather
        // than trusting the unit tests around them.
        var phasesSeen: Set<TDPPhase> = []
        for seed in UInt32(200)...400 {
            let engine = makeEngine(seed: seed)
            engine.apply(.setTargetRounds(seat: 0, rounds: 6))
            for seat in 0..<3 { engine.apply(.setReady(seat: seat, ready: true)) }

            var steps = 0
            while engine.state.phase != .sessionEnd && steps < 20_000 {
                steps += 1
                // Record after every mutation, not once per loop — a phase
                // can be entered and left inside a single iteration.
                phasesSeen.insert(engine.state.phase)
                engine.flushAutomatic()
                phasesSeen.insert(engine.state.phase)

                if engine.state.phase == .roundEnd { engine.apply(.beginNextRound); continue }
                if engine.state.phase == .sessionEnd { break }

                var acted = false
                for seat in 0..<3 {
                    guard let action = TDPAIEngine.nextAction(state: engine.state, seat: seat) else { continue }
                    XCTAssertNil(engine.apply(action))
                    phasesSeen.insert(engine.state.phase)
                    acted = true
                    break
                }
                if !acted { engine.flushAutomatic() }
            }
            if phasesSeen.contains(.khichai) { break }
        }

        XCTAssertTrue(phasesSeen.contains(.khichai),
                      "The khichai pull should occur in ordinary play. Saw: \(phasesSeen)")
    }

    func testSessionOnlyEndsOnMultiplesOfThree() {
        let engine = makeEngine(seed: 4)
        XCTAssertNotNil(engine.apply(.setTargetRounds(seat: 0, rounds: 4)), "4 is not a multiple of 3")
        XCTAssertNil(engine.apply(.setTargetRounds(seat: 0, rounds: 6)))
        XCTAssertEqual(engine.state.targetRounds, 6)
    }
}
