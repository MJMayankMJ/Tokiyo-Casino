//
//  TDPMomentsTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  The two plays that get a fanfare: a first cut (trumping a suit the first
//  time it's led) and a steal (winning with Q or lower while the card just
//  above it is out in someone else's hand).
//

#if DEBUG
import XCTest
@testable import Tokiyo_Casino

final class TDPMomentsTests: XCTestCase {

    private func card(_ id: String) -> Card { Card(tdpID: id)! }
    private func play(_ seat: TDPSeat, _ id: String) -> TDPTrickPlay { TDPTrickPlay(seat: seat, card: card(id)) }

    // MARK: First cut

    func testTrumpingASuitTheFirstTimeItsLedIsAFirstCut() {
        let trick = [play(1, "KS"), play(2, "8S"), play(0, "9H")]
        XCTAssertTrue(TDPMoments.isFirstCut(play: trick[2], trick: trick, trump: .hearts, earlier: []))
    }

    func testTheSecondTimeASuitIsLedItIsJustACut() {
        let earlier = [[play(2, "AS"), play(0, "7S"), play(1, "9S")]]
        let trick = [play(1, "KS"), play(2, "8S"), play(0, "9H")]
        XCTAssertFalse(TDPMoments.isFirstCut(play: trick[2], trick: trick, trump: .hearts, earlier: earlier))
    }

    func testFollowingSuitOrTrumpLedIsNoCut() {
        let followed = [play(1, "KS"), play(0, "AS")]
        XCTAssertFalse(TDPMoments.isFirstCut(play: followed[1], trick: followed, trump: .hearts, earlier: []))
        let trumpLed = [play(1, "7H"), play(0, "AH")]
        XCTAssertFalse(TDPMoments.isFirstCut(play: trumpLed[1], trick: trumpLed, trump: .hearts, earlier: []))
    }

    // MARK: Steal

    func testAceQueenWinningWithTheQueenIsASteal() {
        let trick = [play(1, "9C"), play(2, "10C"), play(0, "QC")]
        XCTAssertEqual(TDPMoments.steal(trick: trick, winner: 0, hand: [card("AC")], earlier: []), .queen,
                       "K♣ is still out — someone chose not to, or couldn't, beat the Q")
    }

    func testKingQueenWinningWithTheQueenIsNoSurprise() {
        let trick = [play(1, "9C"), play(2, "10C"), play(0, "QC")]
        XCTAssertNil(TDPMoments.steal(trick: trick, winner: 0, hand: [card("KC")], earlier: []))
    }

    func testTheHighestCardLeftIsNoSurprise() {
        let earlier = [[play(0, "AC"), play(1, "KC"), play(2, "8C")]]
        let trick = [play(1, "9C"), play(2, "10C"), play(0, "QC")]
        XCTAssertNil(TDPMoments.steal(trick: trick, winner: 0, hand: [], earlier: earlier))
    }

    func testTheNextCardUpIsWhatCounts() {
        // K♣ is gone; A♣ is out with someone else — the Q still steals it.
        let earlier = [[play(0, "8C"), play(1, "KC"), play(2, "9C")]]
        let trick = [play(1, "10C"), play(2, "JC"), play(0, "QC")]
        XCTAssertEqual(TDPMoments.steal(trick: trick, winner: 0, hand: [], earlier: earlier), .queen)
    }

    func testOnlyQueenOrLowerAndOnlyByFollowingSuit() {
        let king = [play(1, "9C"), play(2, "10C"), play(0, "KC")]
        XCTAssertNil(TDPMoments.steal(trick: king, winner: 0, hand: [], earlier: []), "K is above Q")
        let cut = [play(1, "9C"), play(2, "10C"), play(0, "8H")]
        XCTAssertNil(TDPMoments.steal(trick: cut, winner: 0, hand: [], earlier: []), "a cut, not a steal")
    }

    func testALowTrumpCanStealWhenTrumpsAreLed() {
        let trick = [play(1, "7H"), play(2, "8H"), play(0, "10H")]
        XCTAssertEqual(TDPMoments.steal(trick: trick, winner: 0, hand: [card("AH")], earlier: []), .ten)
    }

    // MARK: Through the engine, from the debug scenarios

    private func table(_ scenario: TDPMomentScenario) -> TDPEngine {
        TDPEngine(state: scenario.makeState(playerName: "You"))
    }

    func testMomentScenariosAreLegalTables() {
        for scenario in TDPMomentScenario.allCases {
            let s = table(scenario).state
            let everyCard = s.players.flatMap(\.hand) + s.currentTrick.map(\.card) + s.roundTricks.flatMap { $0 }.map(\.card)
            XCTAssertEqual(Set(everyCard.map(\.tdpID)).count, 30, "\(scenario): all 30 cards, once each")
            XCTAssertEqual(s.currentTurnSeat, 0, "\(scenario): your play")
            XCTAssertEqual(s.players.map(\.tricksWon).reduce(0, +), s.roundTricks.count, "\(scenario)")
        }
    }

    func testTrumpingTheFirstSpadeIsAFirstCutTheHostHoldsFor() {
        let engine = table(.firstCut)
        XCTAssertTrue(TDPMoments.isFirstCut(play: TDPTrickPlay(seat: 0, card: card("JH")),
                                            trick: engine.state.currentTrick + [TDPTrickPlay(seat: 0, card: card("JH"))],
                                            trump: engine.state.trump, earlier: engine.state.roundTricks))
        XCTAssertNil(engine.apply(.playCard(seat: 0, cardID: "JH")))
        XCTAssertEqual(engine.state.phase, .trickResolve)
        XCTAssertEqual(engine.state.lastTrickWinnerSeat, 0)
        XCTAssertEqual(TDPMoments.pendingMoment(engine.state), .firstCut)
    }

    func testWinningWithTheQueenIsAStealButTheAceIsNot() {
        let queen = table(.steal)
        XCTAssertNil(queen.apply(.playCard(seat: 0, cardID: "QC")))
        XCTAssertEqual(queen.state.lastTrickWinnerSeat, 0)
        XCTAssertEqual(TDPMoments.pendingMoment(queen.state), .steal(.queen))

        let ace = table(.steal)
        XCTAssertNil(ace.apply(.playCard(seat: 0, cardID: "AC")))
        XCTAssertNil(TDPMoments.pendingMoment(ace.state))
    }

    func testBotsGetNoFanfare() {
        var state = TDPMomentScenario.firstCut.makeState(playerName: "You")
        state.players[0].isAI = true
        let engine = TDPEngine(state: state)
        XCTAssertNil(engine.apply(.playCard(seat: 0, cardID: "JH")))
        XCTAssertNil(TDPMoments.pendingMoment(engine.state))
    }

    // MARK: The round's tricks

    func testFinishedTricksAreKeptForTheRoundAndShared() {
        let engine = table(.firstCut)
        XCTAssertNil(engine.apply(.playCard(seat: 0, cardID: "JH")))
        XCTAssertEqual(engine.state.roundTricks.count, 3, "the trick on the table isn't finished yet")
        XCTAssertNil(engine.apply(.ackTrick))
        XCTAssertEqual(engine.state.roundTricks.count, 4)
        XCTAssertEqual(engine.state.roundTricks.last?.map(\.card.tdpID), ["KS", "8S", "JH"])

        let view = TDPViewBuilder.view(from: engine.state, for: 1, isHost: false)
        XCTAssertEqual(view.roundTricks.count, 4, "every player sees what was played")

        var next = engine.state
        next.resetForNewRound()
        XCTAssertTrue(next.roundTricks.isEmpty)
    }
}
#endif
