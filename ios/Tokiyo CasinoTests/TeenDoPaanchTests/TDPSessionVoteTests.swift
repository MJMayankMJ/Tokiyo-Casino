//
//  TDPSessionVoteTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  The length is fixed before the deal. Afterwards the people at the table
//  vote on three more rounds: alone with bots you decide; two people must
//  both agree; three need two. Bots never vote.
//

import XCTest
@testable import Tokiyo_Casino

final class TDPSessionVoteTests: XCTestCase {

    /// A table that has just played its last round, with `humans` people in
    /// the first seats and bots in the rest.
    private func finishedSession(humans: Int, phase: TDPPhase = .sessionEnd) -> TDPEngine {
        let players = (0..<3).map {
            TDPPlayer(id: "s\($0)", name: "P\($0)", seat: $0, isAI: $0 >= humans)
        }
        var state = TDPGameState(tableID: "T", seed: 9, players: players)
        state.phase = phase
        state.dealerSeat = 0
        state.roundNumber = 3
        state.targetRounds = 3
        return TDPEngine(state: state)
    }

    private func vote(_ engine: TDPEngine, _ seat: TDPSeat, _ yes: Bool) -> TDPError? {
        engine.apply(.voteExtend(seat: seat, yes: yes))
    }

    private func assertExtended(_ engine: TDPEngine, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(engine.state.targetRounds, 6, "Three more rounds", file: file, line: line)
        XCTAssertEqual(engine.state.roundNumber, 4, "…and the next one is dealt straight away", file: file, line: line)
        XCTAssertEqual(engine.state.phase, .dealFirstFive, file: file, line: line)
        XCTAssertTrue(engine.state.extendVotes.isEmpty, "Votes are cleared for next time", file: file, line: line)
    }

    // MARK: Alone with bots

    func testPlayingBotsYouDecideAlone() {
        let engine = finishedSession(humans: 1)
        XCTAssertNil(vote(engine, 0, true))
        assertExtended(engine)
    }

    func testPlayingBotsSayingNoEndsIt() {
        let engine = finishedSession(humans: 1)
        XCTAssertNil(vote(engine, 0, false))
        XCTAssertEqual(engine.state.phase, .sessionEnd)
        XCTAssertTrue(TDPEngine.isExtendDeclined(engine.state))
        XCTAssertNotNil(vote(engine, 0, true), "The decision stands")
    }

    // MARK: Two people

    func testTwoPeopleMustBothAgree() {
        let engine = finishedSession(humans: 2)
        XCTAssertEqual(TDPEngine.extendVotesNeeded(engine.state), 2)
        XCTAssertNil(vote(engine, 0, true))
        XCTAssertEqual(engine.state.phase, .sessionEnd, "One yes isn't enough")
        XCTAssertFalse(TDPEngine.isExtendDeclined(engine.state))
        XCTAssertNil(vote(engine, 1, true))
        assertExtended(engine)
    }

    func testOneNoOfTwoEndsIt() {
        let engine = finishedSession(humans: 2)
        XCTAssertNil(vote(engine, 0, true))
        XCTAssertNil(vote(engine, 1, false))
        XCTAssertEqual(engine.state.phase, .sessionEnd)
        XCTAssertTrue(TDPEngine.isExtendDeclined(engine.state))
        XCTAssertEqual(engine.state.targetRounds, 3)
    }

    // MARK: Three people

    func testThreePeopleNeedTwo() {
        let engine = finishedSession(humans: 3)
        XCTAssertEqual(TDPEngine.extendVotesNeeded(engine.state), 2)
        XCTAssertNil(vote(engine, 0, false))
        XCTAssertFalse(TDPEngine.isExtendDeclined(engine.state), "One no of three can still be outvoted")
        XCTAssertNil(vote(engine, 1, true))
        XCTAssertEqual(engine.state.phase, .sessionEnd)
        XCTAssertNil(vote(engine, 2, true))
        assertExtended(engine)
    }

    func testTwoNoesOfThreeEndIt() {
        let engine = finishedSession(humans: 3)
        XCTAssertNil(vote(engine, 0, false))
        XCTAssertNil(vote(engine, 2, false))
        XCTAssertTrue(TDPEngine.isExtendDeclined(engine.state))
        XCTAssertNotNil(vote(engine, 1, true), "Too late to change the outcome")
    }

    func testAVoteCanChangeBeforeItIsDecided() {
        let engine = finishedSession(humans: 3)
        XCTAssertNil(vote(engine, 0, true))
        XCTAssertNil(vote(engine, 0, false))
        XCTAssertEqual(engine.state.extendVotes["0"], false)
    }

    // MARK: Who and when

    func testBotsDoNotVote() {
        let engine = finishedSession(humans: 2)
        XCTAssertEqual(TDPEngine.extendVoters(engine.state), [0, 1])
        XCTAssertNotNil(vote(engine, 2, true), "Seat 2 is a bot")
    }

    func testNoVotingMidSession() {
        let engine = finishedSession(humans: 2, phase: .roundEnd)
        XCTAssertNotNil(vote(engine, 0, true))
    }

    func testTheWireCarriesTheVote() {
        let engine = finishedSession(humans: 1)
        let action = try! XCTUnwrap(TDPIntent(kind: .voteExtend, accept: true).action(for: 0))
        XCTAssertNil(engine.apply(action))
        assertExtended(engine)
        XCTAssertNil(TDPIntent(kind: .voteExtend).action(for: 0), "A vote needs a yes or no")
    }

    func testEveryoneSeesTheTally() {
        let engine = finishedSession(humans: 2)
        _ = vote(engine, 1, true)
        let view = TDPViewBuilder.view(from: engine.state, for: 0, isHost: true)
        let tally = try! XCTUnwrap(view.extendVote)
        XCTAssertEqual(tally.ballots, [.init(seat: 0, yes: nil), .init(seat: 1, yes: true)])
        XCTAssertEqual(tally.needed, 2)
        XCTAssertFalse(tally.declined)
    }
}

// MARK: - Profile

final class PlayerProfileTests: XCTestCase {

    private let keys = ["tokiyo.profile.name", "tokiyo.profile.onboarded.v1", "tokiyo.poker.mp.displayName",
                        "tokiyo.profile.guestName"] + CardGame.allCases.map { "tokiyo.profile.cardDesign.\($0.rawValue)" }
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys { saved[key] = UserDefaults.standard.object(forKey: key) }
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    override func tearDown() {
        for key in keys { UserDefaults.standard.set(saved[key], forKey: key) }
        super.tearDown()
    }

    func testSkippingGivesAGuestName() {
        let before = PlayerProfile.name          // e.g. Home's avatar, before onboarding
        XCTAssertNil(PlayerProfile.suggestedName, "A made-up guest name never pre-fills the field")
        PlayerProfile.completeOnboarding(name: nil)
        XCTAssertTrue(PlayerProfile.hasOnboarded)
        XCTAssertTrue(PlayerProfile.name.hasPrefix("Guest "), PlayerProfile.name)
        XCTAssertEqual(PlayerProfile.name, before, "Skip keeps the guest name already shown")
    }

    func testNamesAreTrimmedAndCapped() {
        XCTAssertFalse(PlayerProfile.setName("   "), "Blank is refused")
        XCTAssertTrue(PlayerProfile.setName("  Mayank  "))
        XCTAssertEqual(PlayerProfile.name, "Mayank")
        PlayerProfile.setName("A name that is far too long for a badge")
        XCTAssertEqual(PlayerProfile.name.count, PlayerProfile.maxNameLength)
    }

    func testPokerAndProfileShareOneName() {
        UserDefaults.standard.set("Rohan", forKey: "tokiyo.poker.mp.displayName")
        XCTAssertEqual(PlayerProfile.name, "Rohan", "The name Poker already knew carries over")
        XCTAssertTrue(MultiplayerProfile.save("Meera"))
        XCTAssertEqual(PlayerProfile.name, "Meera")
        XCTAssertEqual(MultiplayerProfile.savedName, "Meera")
    }

    func testEachGameStartsWithItsOwnDeck() {
        XCTAssertEqual(PlayerProfile.cardDesign(for: .poker), .classic)
        XCTAssertEqual(PlayerProfile.cardDesign(for: .teenDoPaanch), .minimal)
    }

    func testDecksAreChosenPerGame() {
        let changed = expectation(forNotification: PlayerProfile.didChange, object: nil)
        PlayerProfile.setCardDesign(.minimal, for: .poker)
        wait(for: [changed], timeout: 1)
        XCTAssertEqual(PlayerProfile.cardDesign(for: .poker), .minimal)
        XCTAssertEqual(PlayerProfile.cardDesign(for: .teenDoPaanch), .minimal, "5-3-2 is untouched")
        PlayerProfile.setCardDesign(.classic, for: .teenDoPaanch)
        XCTAssertEqual(PlayerProfile.cardDesign(for: .poker), .minimal, "…and so is Poker")
    }

    func testCardsFollowTheirGamesChoice() {
        PlayerProfile.setCardDesign(.classic, for: .teenDoPaanch)
        XCTAssertEqual(TDPCardButton(card: nil, faceDown: true).design, .classic)
        PlayerProfile.setCardDesign(.minimal, for: .poker)
        XCTAssertEqual(CardView().design, .minimal)
        XCTAssertEqual(TDPCardButton(card: nil, faceDown: true, design: .minimal).design, .minimal,
                       "A preview can ask for either")
    }

    func testInitials() {
        XCTAssertEqual(PlayerProfile.initials(for: "Mayank Jangid"), "MJ")
        XCTAssertEqual(PlayerProfile.initials(for: "Guest 4821"), "G")
        XCTAssertEqual(PlayerProfile.initials(for: "meera"), "M")
    }
}
