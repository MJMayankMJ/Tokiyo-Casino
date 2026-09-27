//
//  PokerMomentsTests.swift
//  Tokiyo CasinoTests
//
//  The hands that get a fanfare (`PokerMoments`): monster hands, the
//  Hammer, comebacks on the last cards, hero calls and knockouts.
//

#if DEBUG
import XCTest
@testable import Tokiyo_Casino

final class PokerMomentsTests: XCTestCase {

    private func cards(_ list: String) -> [Card] { PokerMomentSample.cards(list) }

    private func hand(_ hole: String, _ board: String, won: Bool = true, against others: [String] = [],
                      calledRiver: Bool = false, knockedOut: [Int] = []) -> PokerHandRecord {
        PokerHandRecord(hole: cards(hole), board: cards(board), won: won,
                        shownDown: others.enumerated().map { PokerShownHand(seat: $0.offset + 1, cards: cards($0.element)) },
                        calledRiver: calledRiver, knockedOut: knockedOut)
    }

    // MARK: Monster hands

    func testMonsterHandsNeedOneOfYourCards() {
        XCTAssertEqual(PokerMoments.monster(hole: cards("AS KS"), board: cards("QS JS 10S 4D 9C")), .royalFlush)
        XCTAssertEqual(PokerMoments.monster(hole: cards("9H 2C"), board: cards("8H 7H 6H 5H KD")), .straightFlush)
        XCTAssertEqual(PokerMoments.monster(hole: cards("9C 3D"), board: cards("9H 9S 9D 4C 2H")), .fourOfAKind)
        XCTAssertNil(PokerMoments.monster(hole: cards("AD 3C"), board: cards("9H 9S 9D 9C 2H")),
                     "quads on the board are everyone's — your ace only kicks")
        XCTAssertNil(PokerMoments.monster(hole: cards("2C 3D"), board: cards("QS JS 10S AS KS")),
                     "a royal on the board is everyone's")
        XCTAssertNil(PokerMoments.monster(hole: cards("AC AD"), board: cards("AH KS KD 4C 2H")), "a full house")
    }

    func testTheRarestThingLeads() {
        // 7-2 that makes quads is quads.
        XCTAssertEqual(PokerMoments.moments(for: hand("7D 2C", "7S 7H 7C KD 3S")), [.fourOfAKind])
        XCTAssertEqual(PokerMoments.moments(for: hand("AS KS", "QS JS 10S 4D 9C", knockedOut: [1])),
                       [.royalFlush, .knockout(count: 1)], "a knockout plays after the headline")
    }

    func testNothingForAHandYouLost() {
        XCTAssertEqual(PokerMoments.moments(for: hand("AS KS", "QS JS 10S 4D 9C", won: false)), [])
    }

    // MARK: The Hammer

    func testTheHammerIsSevenTwoOffsuit() {
        XCTAssertEqual(PokerMoments.moments(for: hand("7D 2C", "AS KH 9C")), [.hammer], "won when everyone folded")
        XCTAssertEqual(PokerMoments.moments(for: hand("2S 7H", "7S KH 9C 5D 3S", against: ["QC JC"])), [.hammer])
        XCTAssertEqual(PokerMoments.moments(for: hand("7D 2D", "AS KH 9C")), [], "suited isn't the hammer")
    }

    // MARK: Comebacks

    func testEightOutsOnTheRiverIsAMiracle() {
        // Open-ended against aces on the turn; the nine comes.
        let moments = PokerMoments.moments(for: hand("8H 7H", "5H 6C KD 2S 9D", against: ["AS AC"]))
        XCTAssertEqual(moments, [.riverMiracle(odds: 8.0 / 44.0)])
    }

    func testRunningHeartsAgainstASetIsRunnerRunner() {
        let moments = PokerMoments.moments(for: hand("AH 5H", "QC 7H 2S 9H 3H", against: ["7S 7C"]))
        guard case .runnerRunner(let odds)? = moments.first else { return XCTFail("\(moments)") }
        XCTAssertLessThan(odds, 0.06)
        XCTAssertGreaterThan(odds, 0.03)
    }

    func testAGoodDrawHittingIsNoMiracle() {
        // Flush draw and open-ender against one pair: 15 outs, a third of
        // the time — not a miracle.
        let odds = PokerMoments.odds(hole: cards("9H 8H"), board: cards("7H 6H KC 2D"), against: [cards("KS QD")])
        XCTAssertGreaterThan(odds, PokerMoments.riverMiracleOdds)
        XCTAssertEqual(PokerMoments.moments(for: hand("9H 8H", "7H 6H KC 2D 5S", against: ["KS QD"])), [])
    }

    func testAheadOnTheTurnIsNoComeback() {
        XCTAssertNil(PokerMoments.comeback(hole: cards("AS AD"), board: cards("9C 5H 2D JS 3C"), against: [cards("KS KD")]))
    }

    func testOddsCountEveryRiver() {
        // A two-outer: queens against kings, and only the last two queens
        // save you — 2 of the 44 cards left.
        let odds = PokerMoments.odds(hole: cards("QS QH"), board: cards("8C 7D 2S 4H"), against: [cards("KD KH")])
        XCTAssertEqual(odds, 2.0 / 44.0, accuracy: 1e-9)
    }

    // MARK: Hero call

    func testCallingTheRiverWithAceHighAndWinningIsAHeroCall() {
        XCTAssertEqual(PokerMoments.moments(for: hand("AC QD", "KS 7S 2D 4C 3H", against: ["JS 10S"], calledRiver: true)),
                       [.heroCall])
        XCTAssertEqual(PokerMoments.moments(for: hand("AC QD", "KS 7S 2D 4C 3H", against: ["JS 10S"])), [],
                       "you didn't call a bet on the river")
        XCTAssertEqual(PokerMoments.moments(for: hand("KC 7D", "KS 7S 2D 4C 3H", against: ["JS 10S"], calledRiver: true)),
                       [], "two pair is a value call, not a hero call")
    }

    // MARK: Knockouts

    func testKnockoutsCountThePlayersOut() {
        XCTAssertEqual(PokerMoments.moments(for: hand("AS AD", "9C 5H 2D JS 3C", against: ["KS KD", "QS QD"],
                                                     knockedOut: [1, 2])),
                       [.knockout(count: 2)])
    }

    // MARK: From the table

    func testTheRecordReadsTheFinishedHand() {
        let table = GameManager(playerCount: 4)
        let you = table.players[0], caught = table.players[1], out = table.players[2], folded = table.players[3]
        you.holeCards = cards("AC QD")
        caught.holeCards = cards("JS 10S")
        out.holeCards = cards("QC JD")
        folded.holeCards = cards("KH KD")
        folded.isFolded = true
        table.communityCards = cards("KS 7S 2D 4C 3H")
        table.handHistory.handStarted(button: 0, seats: [0, 1, 2, 3])
        table.handHistory.streetBegan(.river)
        table.handHistory.recordAction(seat: 1, action: .raise(100), callAmount: 0, raisedBet: true)
        table.handHistory.recordAction(seat: 0, action: .call, callAmount: 100, raisedBet: false)
        caught.chips = 400
        out.chips = 0
        you.win(amount: 900)

        let record = PokerHandRecord(finishedAt: table, by: you)
        XCTAssertTrue(record.won)
        XCTAssertEqual(record.shownDown.map(\.seat), [1, 2], "the folded kings stay hidden")
        XCTAssertTrue(record.calledRiver)
        XCTAssertEqual(record.knockedOut, [2])
        XCTAssertEqual(PokerMoments.moments(for: record), [.heroCall, .knockout(count: 1)],
                       "ace-high called the river, caught the bluff and took the other player's last chip")
    }

    func testEveryoneFoldingShowsNothingDown() {
        let table = GameManager(playerCount: 3)
        let you = table.players[0]
        you.holeCards = cards("7D 2C")
        table.players[1].holeCards = cards("AS AD")
        table.players[1].isFolded = true
        table.players[2].holeCards = cards("KS KD")
        table.players[2].isFolded = true
        table.communityCards = cards("QS 9H 4C")
        you.win(amount: 60)

        let record = PokerHandRecord(finishedAt: table, by: you)
        XCTAssertEqual(record.shownDown, [])
        XCTAssertEqual(PokerMoments.moments(for: record), [.hammer])
        XCTAssertEqual(PokerMoments.hold(at: table), PokerMoments.showdownLeadIn + PokerMoment.hammer.duration,
                       "a friends' table waits for it")
    }

    func testTheLastRiverMoveCounts() {
        let history = HandHistoryTracker()
        history.handStarted(button: 0, seats: [0, 1])
        history.streetBegan(.river)
        history.recordAction(seat: 0, action: .call, callAmount: 50, raisedBet: false)
        history.recordAction(seat: 0, action: .raise(200), callAmount: 50, raisedBet: true)
        XCTAssertEqual(history.lastAction(of: 0, on: .river), .aggressive)
        history.handStarted(button: 1, seats: [0, 1])
        XCTAssertNil(history.lastAction(of: 0, on: .river), "a new hand starts clean")
    }

    // MARK: Debug samples

    func testEverySampleMakesItsMoment() {
        let expected: [PokerMomentSample: (PokerMoment) -> Bool] = [
            .royalFlush: { $0 == .royalFlush },
            .straightFlush: { $0 == .straightFlush },
            .fourOfAKind: { $0 == .fourOfAKind },
            .runnerRunner: { if case .runnerRunner = $0 { return true }; return false },
            .riverMiracle: { if case .riverMiracle = $0 { return true }; return false },
            .heroCall: { $0 == .heroCall },
            .hammer: { $0 == .hammer },
            .knockout: { $0 == .knockout(count: 1) },
            .doubleKnockout: { $0 == .knockout(count: 2) }
        ]
        for sample in PokerMomentSample.allCases {
            let hand = sample.hand(against: [1, 2])
            XCTAssertEqual(Set(hand.hole + hand.board + hand.shownDown.flatMap(\.cards)).count,
                           hand.hole.count + hand.board.count + hand.shownDown.count * 2, "\(sample): no card twice")
            let moments = PokerMoments.moments(for: hand)
            XCTAssertEqual(moments.count, 1, "\(sample): \(moments)")
            XCTAssertTrue(moments.first.map { expected[sample]?($0) ?? false } ?? false, "\(sample): \(moments)")
        }
    }
}
#endif
