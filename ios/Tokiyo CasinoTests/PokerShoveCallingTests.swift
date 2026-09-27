//
//  PokerShoveCallingTests.swift
//  Tokiyo CasinoTests
//
//  The table used to fold ~85% of hands to every preflop shove — AK half the
//  time, even AA now and then — and never noticed a player shoving every hand.
//  These pin the fix: a shove is priced with pot odds against the shover's
//  range, the tracker reads how wide each seat shoves, premium hands never
//  fold, and preflop position is counted from the button.
//

import XCTest
@testable import Tokiyo_Casino

final class PokerShoveCallingTests: XCTestCase {

    private func c(_ r: Rank, _ s: Suit) -> Card { Card(suit: s, rank: r) }

    /// Seeded generator so every decision here is reproducible.
    private struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func isFold(_ action: PlayerAction) -> Bool {
        if case .fold = action { return true }
        return false
    }

    /// Blind battle: seat 0 shoved 1000 from the small blind; the bot (seat 1)
    /// is in the big blind with 980 behind. Calling needs ~49% equity.
    private func facingShove(_ hand: [Card], read: Double?) -> (Player, GameState) {
        let shover = Player(id: 0, name: "You", type: .human, chips: 0)
        shover.currentBet = 1000
        shover.totalInvested = 1000
        shover.isAllIn = true
        let bot = Player(id: 1, name: "Bot", type: .ai(personality: .balanced), chips: 980)
        bot.currentBet = 20
        bot.totalInvested = 20
        bot.holeCards = hand
        let state = GameState(
            pot: 1020, currentBet: 1000, minRaise: 980, communityCards: [],
            activePlayers: [shover, bot], dealerIndex: 0, wasRaisedPreflop: true,
            position: .middle,
            bettor: read.map { BettorRead(seat: 0, shoveRange: $0, raiseRange: $0) }
        )
        return (bot, state)
    }

    /// Seat 0 opened to 60; the bot is in the big blind with 980 behind — a
    /// normal raise, so the opening chart decides.
    private func facingRaise(_ hand: [Card]) -> (Player, GameState) {
        let raiser = Player(id: 0, name: "You", type: .human, chips: 940)
        raiser.currentBet = 60
        raiser.totalInvested = 60
        let bot = Player(id: 1, name: "Bot", type: .ai(personality: .balanced), chips: 980)
        bot.currentBet = 20
        bot.totalInvested = 20
        bot.holeCards = hand
        let state = GameState(
            pot: 90, currentBet: 60, minRaise: 40, communityCards: [],
            activePlayers: [raiser, bot], dealerIndex: 0, wasRaisedPreflop: true,
            position: .middle
        )
        return (bot, state)
    }

    private func expertPro() -> AIProfile { Difficulty.expert.apply(to: .solverInspired) }

    private func folds(_ hand: [Card], read: Double?, profile: AIProfile, trials: Int, seed: UInt64) -> Int {
        var rng = SplitMix64(state: seed)
        let (bot, state) = facingShove(hand, read: read)
        return (0..<trials).filter { _ in
            isFold(AIEngine.decide(for: bot, gameState: state, profile: profile, rng: &rng))
        }.count
    }

    // MARK: - Calling a shove

    func testShoverWhoShovesAnyTwoCardsGetsCalledWide() {
        // Against any two cards these all have ~58–64% equity for a 49% price.
        let calls: [(String, [Card])] = [
            ("A9o", [c(.ace, .spades), c(.nine, .hearts)]),
            ("K9o", [c(.king, .spades), c(.nine, .hearts)]),
            ("AJo", [c(.ace, .clubs), c(.jack, .diamonds)]),
            ("55", [c(.five, .spades), c(.five, .hearts)]),
            ("KTs", [c(.king, .hearts), c(.ten, .hearts)]),
        ]
        for (name, hand) in calls {
            XCTAssertEqual(folds(hand, read: 1.0, profile: expertPro(), trials: 5, seed: 1), 0,
                           "\(name) should call a shove from a player who shoves any two cards")
        }
        XCTAssertEqual(folds([c(.seven, .spades), c(.two, .hearts)], read: 1.0, profile: expertPro(), trials: 5, seed: 2), 5,
                       "72o is still a fold, even against any two cards")
    }

    func testTightShoverOnlyGetsCalledByBigHands() {
        // Top 3% ≈ big pairs only.
        XCTAssertEqual(folds([c(.ace, .spades), c(.ace, .hearts)], read: 0.03, profile: expertPro(), trials: 5, seed: 3), 0)
        XCTAssertEqual(folds([c(.ace, .spades), c(.nine, .hearts)], read: 0.03, profile: expertPro(), trials: 5, seed: 4), 5,
                       "A9o is crushed by a big-pairs-only shove")
        XCTAssertEqual(folds([c(.seven, .spades), c(.seven, .hearts)], read: 0.03, profile: expertPro(), trials: 5, seed: 5), 5,
                       "77 is crushed by a big-pairs-only shove")
    }

    func testBigPairsNeverFoldToAShoveFromAnUnknownPlayer() {
        // Every style, at Easy (25% random mistakes, noisy 200-sample equity)
        // and Expert, with no read on the shover yet.
        let hands: [(String, [Card])] = [
            ("AA", [c(.ace, .spades), c(.ace, .hearts)]),
            ("KK", [c(.king, .spades), c(.king, .hearts)]),
            ("QQ", [c(.queen, .spades), c(.queen, .hearts)]),
        ]
        let styles: [AIProfile] = [.nit, .tag, .lag, .callingStation, .maniac, .solverInspired]
        // Easy is the risky tier (mistakes + noise), so it gets the trials;
        // Expert makes no mistakes, so a few confirm it.
        for (tier, trials) in [(Difficulty.easy, 40), (.expert, 3)] {
            for (i, style) in styles.enumerated() {
                for (name, hand) in hands {
                    XCTAssertEqual(folds(hand, read: nil, profile: tier.apply(to: style), trials: trials, seed: UInt64(i + 10)), 0,
                                   "\(name) folded to a shove (\(tier), style \(i))")
                }
            }
        }
    }

    func testPremiumsNeverFoldToANormalRaiseEvenWithMistakes() {
        let premiums: [(String, [Card])] = [
            ("AA", [c(.ace, .spades), c(.ace, .hearts)]),
            ("TT", [c(.ten, .spades), c(.ten, .hearts)]),
            ("AKo", [c(.ace, .spades), c(.king, .hearts)]),
            ("AKs", [c(.ace, .spades), c(.king, .spades)]),
            ("AQs", [c(.ace, .clubs), c(.queen, .clubs)]),
        ]
        let styles: [AIProfile] = [.nit, .tag, .lag, .callingStation, .maniac, .solverInspired]
        var rng = SplitMix64(state: 99)
        for style in styles {
            let easy = Difficulty.easy.apply(to: style)   // 25% random mistakes
            for (name, hand) in premiums {
                let (bot, state) = facingRaise(hand)
                for _ in 0..<60 {
                    XCTAssertFalse(isFold(AIEngine.decide(for: bot, gameState: state, profile: easy, rng: &rng)),
                                   "\(name) folded to a single raise")
                }
            }
        }
    }

    func testShoveSpotsAreDetected() {
        let (bot, state) = facingShove([c(.two, .spades), c(.two, .hearts)], read: nil)
        XCTAssertTrue(AIEngine.facesShove(player: bot, gameState: state, callAmount: 980))
        let (bot2, state2) = facingRaise([c(.two, .spades), c(.two, .hearts)])
        XCTAssertFalse(AIEngine.facesShove(player: bot2, gameState: state2, callAmount: 40),
                       "a normal raise stays on the opening chart")
        // Calling a third of the stack is a shove decision even without an all-in.
        XCTAssertTrue(AIEngine.facesShove(player: bot2, gameState: state2, callAmount: 330))
    }

    func testShortStackFacingAnOpenReadsTheRaiserNotTheShover() {
        // 100 behind, so calling 40 commits over a third of it — but the raiser
        // only opened. It raises a lot and never shoves: read its raising range.
        let raiser = Player(id: 0, name: "You", type: .human, chips: 940)
        raiser.currentBet = 60
        raiser.totalInvested = 60
        let bot = Player(id: 1, name: "Bot", type: .ai(personality: .balanced), chips: 100)
        bot.currentBet = 20
        bot.totalInvested = 20
        bot.holeCards = [c(.ace, .spades), c(.nine, .hearts)]
        let state = GameState(
            pot: 90, currentBet: 60, minRaise: 40, communityCards: [],
            activePlayers: [raiser, bot], dealerIndex: 0, wasRaisedPreflop: true,
            position: .middle,
            bettor: BettorRead(seat: 0, shoveRange: 0.015, raiseRange: 0.6)
        )
        XCTAssertTrue(AIEngine.facesShove(player: bot, gameState: state, callAmount: 40))
        var rng = SplitMix64(state: 21)
        for _ in 0..<5 {
            XCTAssertFalse(isFold(AIEngine.decide(for: bot, gameState: state, profile: expertPro(), rng: &rng)),
                           "an open from a loose raiser isn't an aces-only shove")
        }
    }

    func testPotOddsPriceOnlyTheChipsWeCanCall() {
        // Normal: 100 to call into 300 → 25%.
        XCTAssertEqual(AIEngine.potOdds(callAmount: 100, pot: 300, chips: 1000), 0.25, accuracy: 1e-9)
        // A 1000 shove into 1030 with only 300 behind: we risk 300 to win the
        // 330 already in plus the 300 the shover matches.
        XCTAssertEqual(AIEngine.potOdds(callAmount: 1000, pot: 1030, chips: 300), 300.0 / 630.0, accuracy: 1e-9)
    }

    // MARK: - Equity against a range

    func testTightRangeIsSampledExactly() {
        // A 6-combo range is exactly AA, so KK has ~18% — the old rejection
        // sampler fell back to random hands and read this far higher.
        var rng = SplitMix64(state: 7)
        let kk = [c(.king, .spades), c(.king, .hearts)]
        let eq = EquityCalculator.equity(hole: kk, board: [], opponentRanges: [0.001], iterations: 4000, rng: &rng)
        XCTAssertEqual(eq, 0.18, accuracy: 0.03)
        // And an any-two range is unchanged: AA vs a random hand ≈ 85%.
        let aa = [c(.ace, .spades), c(.ace, .hearts)]
        let eqAA = EquityCalculator.equity(hole: aa, board: [], opponentRanges: [1.0], iterations: 4000, rng: &rng)
        XCTAssertEqual(eqAA, 0.85, accuracy: 0.03)
    }

    // MARK: - Reading the shover

    func testAllInRaisePreflopCountsAsAShoveOncePerHand() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .allIn, callAmount: 10, raisedBet: true)
        t.recordAction(seat: 1, action: .raise(500), callAmount: 980, raisedBet: true, isShove: true)
        t.recordAction(seat: 0, action: .allIn, callAmount: 0, raisedBet: true)   // same hand, counted once
        XCTAssertEqual(t.rawStats(for: 0).preflopShoves, 1)
        XCTAssertEqual(t.rawStats(for: 1).preflopShoves, 1, "a stack-committing raise is a shove")
    }

    func testAllInCallAndPostflopShoveAreNotPreflopShoves() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .allIn, callAmount: 40, raisedBet: false)   // all-in that only calls
        XCTAssertEqual(t.rawStats(for: 1).preflopShoves, 0)

        t.handStarted(button: 1, seats: [0, 1])
        t.streetBegan(.flop)
        t.recordAction(seat: 0, action: .allIn, callAmount: 0, raisedBet: true)
        XCTAssertEqual(t.rawStats(for: 0).preflopShoves, 0)
    }

    func testShoveRangeReadsAnEveryHandShoverAsWideQuickly() {
        var s = OpponentStats()
        XCTAssertEqual(OpponentModel(stats: s, prior: .populationBaseline).shoveRange, 0.2, accuracy: 1e-9,
                       "no data: the baseline prior")
        s.handsDealt = 10
        s.preflopShoves = 10
        XCTAssertGreaterThan(OpponentModel(stats: s, prior: .populationBaseline).shoveRange, 0.6,
                             "ten shoves in ten hands reads as a wide shover")
        s.handsDealt = 40
        s.preflopShoves = 1
        XCTAssertLessThan(OpponentModel(stats: s, prior: .populationBaseline).shoveRange, 0.06,
                          "one shove in forty hands reads as a tight one")
    }

    func testBotSeesTheReadOnAPlayerWhoKeepsShoving() {
        let gm = GameManager(playerCount: 3, startingChips: 1000)
        gm.applyAIConfigToAISeats()
        for _ in 0..<10 {
            gm.handHistory.handStarted(button: 0, seats: [0, 1, 2])
            gm.handHistory.recordAction(seat: 0, action: .allIn, callAmount: 20, raisedBet: true)
        }

        // A live hand: the human shoves, and a bot now faces it.
        gm.resetForNewHand()
        gm.dealHoleCards()
        gm.postBlinds()
        gm.currentPhase = .preFlop
        gm.handHistory.handStarted(button: gm.dealerIndex, seats: [0, 1, 2])
        let human = gm.players[0]
        gm.currentPlayerIndex = gm.activePlayers.firstIndex { $0.id == human.id }!
        gm.processPlayerAction(.allIn, for: human)

        XCTAssertEqual(gm.handHistory.rawStats(for: 0).preflopShoves, 11)
        let bot = gm.players.first { !$0.isHuman && $0.currentBet < gm.currentBet }!
        let (_, state) = gm.aiDecisionInputs(for: bot)
        XCTAssertEqual(state.bettor?.seat, 0)
        XCTAssertGreaterThan(state.bettor?.shoveRange ?? 0, 0.6)
    }

    // MARK: - Position

    func testPositionCountsFromTheButton() {
        // 6-handed, in order after the button: SB, BB, UTG, MP, CO, BTN.
        let sixMax: [Position] = [.middle, .middle, .early, .middle, .late, .late]
        XCTAssertEqual((0..<6).map { AIEngine.position(placeAfterButton: $0, seatsDealtIn: 6) }, sixMax)
        // 5-handed: SB, BB, UTG, CO, BTN.
        XCTAssertEqual((0..<5).map { AIEngine.position(placeAfterButton: $0, seatsDealtIn: 5) },
                       [.middle, .middle, .middle, .late, .late])
        // Heads-up: big blind, then the button.
        XCTAssertEqual((0..<2).map { AIEngine.position(placeAfterButton: $0, seatsDealtIn: 2) }, [.middle, .late])
    }

    func testButtonSeatPlaysFromLatePosition() {
        let gm = GameManager(playerCount: 6, startingChips: 1000)
        gm.resetForNewHand()
        gm.dealHoleCards()
        let seat = { (stepsAfterButton: Int) in gm.players[(gm.dealerIndex + stepsAfterButton) % 6] }
        XCTAssertEqual(gm.preflopPosition(of: seat(0)), .late, "button")
        XCTAssertEqual(gm.preflopPosition(of: seat(1)), .middle, "small blind")
        XCTAssertEqual(gm.preflopPosition(of: seat(3)), .early, "under the gun")
        XCTAssertEqual(gm.preflopPosition(of: seat(5)), .late, "cutoff")
    }
}
