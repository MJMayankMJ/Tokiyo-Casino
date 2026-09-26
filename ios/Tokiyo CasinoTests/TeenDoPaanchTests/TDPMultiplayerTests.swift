//
//  TDPMultiplayerTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  Runs a real host↔guest session over an in-memory loopback so the
//  friends protocol is exercised end to end without two devices — and,
//  crucially, so the redaction guarantees are asserted rather than assumed.
//

import XCTest
@testable import Tokiyo_Casino

// MARK: - Loopback

/// Wires two transports directly together. Delivery is synchronous, which
/// makes the tests deterministic; ordering still matches the real reliable
/// MPC channel.
final class TDPLoopbackTransport: TDPTransport {

    let localPeerId: String
    var onPeerEvent: ((TDPPeerEvent) -> Void)?
    var onMessage: ((Data, String) -> Void)?

    weak var peer: TDPLoopbackTransport?
    private(set) var isConnected = false
    /// Every payload this transport has ever emitted, for leak inspection.
    private(set) var sentPayloads: [Data] = []

    init(localPeerId: String) {
        self.localPeerId = localPeerId
    }

    var connectedPeerIds: [String] { isConnected ? [peer?.localPeerId].compactMap { $0 } : [] }

    static func pair(host: String, guest: String) -> (host: TDPLoopbackTransport, guest: TDPLoopbackTransport) {
        let a = TDPLoopbackTransport(localPeerId: host)
        let b = TDPLoopbackTransport(localPeerId: guest)
        a.peer = b
        b.peer = a
        return (a, b)
    }

    func startAdvertising(advert: TDPLobbyAdvert) {
        peer?.onPeerEvent?(.foundPeer(peerId: localPeerId, info: advert.discoveryInfo))
    }
    func updateAdvert(_ advert: TDPLobbyAdvert) { startAdvertising(advert: advert) }
    func stopAdvertising() {}
    func startBrowsing() {}
    func stopBrowsing() {}

    func invite(peerId: String, context: Data?) {
        peer?.onPeerEvent?(.receivedInvitation(peerId: localPeerId, context: context))
    }

    func accept(peerId: String) {
        isConnected = true
        peer?.isConnected = true
        peer?.onPeerEvent?(.peerConnected(peerId: localPeerId))
        onPeerEvent?(.peerConnected(peerId: peerId))
    }

    func reject(peerId: String) {}

    func send(_ data: Data, to peerIds: [String]) {
        sentPayloads.append(data)
        peer?.onMessage?(data, localPeerId)
    }

    func broadcast(_ data: Data) { send(data, to: []) }

    func disconnect() {
        isConnected = false
        peer?.isConnected = false
    }
}

// MARK: - Tests

final class TDPMultiplayerTests: XCTestCase {

    private func makeSession() -> (host: TDPHostService,
                                   client: TDPClientService,
                                   hostLink: TDPLoopbackTransport,
                                   guestLink: TDPLoopbackTransport) {
        let links = TDPLoopbackTransport.pair(host: "HostPhone", guest: "GuestPhone")
        let host = TDPHostService(mode: .friends, hostName: "Mayank", targetRounds: 3, seed: 77)
        // Run instantly in tests; the pacing exists for the UI, not the rules.
        host.aiThinkTime = 0
        host.dealPace = 0
        host.trickHold = 0
        host.startHosting(transport: links.host)

        let client = TDPClientService(displayName: "Guest")
        client.startBrowsing(transport: links.guest)
        return (host, client, links.host, links.guest)
    }

    // MARK: Wire

    func testEnvelopeRoundTripsAndRejectsAForeignVersion() throws {
        let intent = TDPIntent(kind: .playCard, cardID: "AS")
        let message = TDPMessage(tableId: "t1", senderPeerId: "p1", type: .intent, payload: intent)
        let data = try TDPWireCodec.encode(message)

        let decoded = try TDPWireCodec.decode(data)
        XCTAssertEqual(decoded.type, .intent)
        let back: TDPIntent = try decoded.decode()
        XCTAssertEqual(back.kind, .playCard)
        XCTAssertEqual(back.cardID, "AS")

        // A host on a different major version must be unreadable, not
        // silently misinterpreted.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["protocolVersion"] = TDPProtocol.version + 1
        let foreign = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try TDPWireCodec.decode(foreign))
    }

    func testAdvertRejectsMismatchedProtocolVersion() {
        var info = TDPLobbyAdvert(tableId: "t", hostName: "H", humansJoined: 1,
                                  targetRounds: 3, isStarted: false).discoveryInfo
        XCTAssertNotNil(TDPLobbyAdvert(discoveryInfo: info))
        info["v"] = "\(TDPProtocol.version + 1)"
        XCTAssertNil(TDPLobbyAdvert(discoveryInfo: info),
                     "An incompatible table must not appear in the join list")
    }

    // MARK: Join

    func testGuestDiscoversJoinsAndIsSeated() {
        let session = makeSession()
        let spy = ClientSpy()
        session.client.delegate = spy

        // Advertise → discover.
        session.hostLink.startAdvertising(advert: TDPLobbyAdvert(
            tableId: session.host.engine.state.tableID, hostName: "Mayank",
            humansJoined: 1, targetRounds: 3, isStarted: false))
        XCTAssertEqual(spy.tables.count, 1)

        session.client.join(spy.tables[0])
        XCTAssertEqual(session.client.seat, 1, "The guest takes the first free seat")
        XCTAssertEqual(spy.lobby?.seats.count, 3)
        XCTAssertEqual(spy.lobby?.seats[1].kind, "remote")
        XCTAssertEqual(spy.lobby?.seats[2].kind, "open", "The third seat stays open until start")
    }

    // MARK: Hidden information

    func testGuestNeverReceivesAnotherSeatsCards() throws {
        let session = makeSession()
        let spy = ClientSpy()
        session.client.delegate = spy

        session.hostLink.startAdvertising(advert: TDPLobbyAdvert(
            tableId: session.host.engine.state.tableID, hostName: "Mayank",
            humansJoined: 1, targetRounds: 3, isStarted: false))
        session.client.join(spy.tables[0])
        session.host.startGame()

        // Advance only as far as the completed deal. Checking after the
        // round would be vacuous: by then every hand is empty and every
        // card has been legitimately published as a played trick.
        driveUntilDealt(session, spy: spy)

        let guestSeat = try! XCTUnwrap(session.client.seat)
        let dealt = spy.views.last { $0.myHand.count == 10 }
        XCTAssertNotNil(dealt, "The guest must have been dealt a full hand")

        for view in spy.views {
            // A seat view carries a count, never cards.
            XCTAssertEqual(view.seats.first { $0.seat == view.mySeat }?.handCount,
                           view.myHand.count)
            // Only the trump selector learns the highest-of-three card.
            if view.myPrivateTrumpCard != nil {
                let selector = view.seats.first { $0.role == TDPRole.trumpSelector.rawValue }
                XCTAssertEqual(selector?.seat, view.mySeat)
            }
        }

        // Every card still held by another seat must be absent from every
        // byte the host has put on the wire.
        let opponentCards = session.host.engine.state.players
            .filter { $0.seat != guestSeat }
            .flatMap(\.hand)
            .map(\.tdpID)
        XCTAssertEqual(opponentCards.count, 20,
                       "Guard against a vacuous pass — both opponents should hold 10 cards here")

        let wire = session.hostLink.sentPayloads
            .map { String(data: $0, encoding: .utf8) ?? "" }
            .joined()
        for cardID in opponentCards {
            XCTAssertFalse(wire.contains("\"\(cardID)\""),
                           "\(cardID) belongs to another seat and must never reach the guest")
        }

        // Sanity: the guest's own cards *are* on the wire, so the check
        // above is testing redaction and not an empty payload.
        let mine = try XCTUnwrap(dealt).myHand.map(\.tdpID)
        XCTAssertTrue(mine.allSatisfy { wire.contains("\"\($0)\"") },
                      "The guest's own hand must reach them")
    }

    /// Runs the host far enough to finish the 5-3-2 deal, answering only
    /// the trump prompt, and stops before any card is played.
    private func driveUntilDealt(_ session: (host: TDPHostService, client: TDPClientService,
                                             hostLink: TDPLoopbackTransport, guestLink: TDPLoopbackTransport),
                                 spy: ClientSpy) {
        for _ in 0..<200 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
            if session.host.engine.state.phase == .play { return }
            guard let view = spy.views.last else { continue }
            if view.prompt == .chooseTrump {
                session.client.send(TDPIntent(kind: .trumpSuit, suit: .spades))
            }
        }
    }

    func testKhichaiDrawnCardGoesOnlyToTheCreditor() {
        // Build a state where seat 0 is owed a trick by seat 1.
        let players = [
            TDPPlayer(id: "s0", name: "A", seat: 0),
            TDPPlayer(id: "s1", name: "B", seat: 1),
            TDPPlayer(id: "s2", name: "C", seat: 2, isAI: true)
        ]
        var state = TDPGameState(tableID: "t", seed: 21, players: players)
        state.dealerSeat = 2
        state.phase = .khichai
        state.trump = .spades
        var rng = TDPRNG(seed: 3)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        state.players[0].hand = TDPDeck.sortHand(Array(deck[0..<10]))
        state.players[1].hand = TDPDeck.sortHand(Array(deck[10..<20]))
        state.players[2].hand = TDPDeck.sortHand(Array(deck[20..<30]))
        let drawn = state.players[1].hand[4]
        state.khichaiCurrent = TDPKhichaiStep(creditorSeat: 0, debtorSeat: 1,
                                              drawnCard: drawn,
                                              fanOrder: Array(0..<10))

        let creditorView = TDPViewBuilder.view(from: state, for: 0, isHost: true)
        let debtorView = TDPViewBuilder.view(from: state, for: 1, isHost: false)
        let observerView = TDPViewBuilder.view(from: state, for: 2, isHost: false)

        XCTAssertEqual(creditorView.khichai?.drawnCard, drawn, "The creditor sees what they pulled")
        XCTAssertNotNil(creditorView.khichai?.legalReturnIDs)

        XCTAssertNil(debtorView.khichai?.drawnCard, "The debtor is not told which card left")
        XCTAssertNil(debtorView.khichai?.legalReturnIDs)
        XCTAssertNil(observerView.khichai?.drawnCard, "The third player learns nothing")
        XCTAssertNil(observerView.khichai?.legalReturnIDs)

        // Everyone still sees that a pull is happening, and between whom.
        XCTAssertEqual(observerView.khichai?.creditorSeat, 0)
        XCTAssertEqual(observerView.khichai?.debtorSeat, 1)
        XCTAssertEqual(observerView.khichai?.fanCount, 10)
    }

    func testFanIndexRevealsNothingAboutTheCardBehindIt() {
        // The fan is a shuffled permutation, so the same index maps to
        // different cards across deals — an index carries no information.
        var seen: Set<String> = []
        var rng = TDPRNG(seed: 5)
        for _ in 0..<200 {
            let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
            let hand = TDPDeck.sortHand(Array(deck[0..<10]))
            let fan = TDPKhichai.makeFanOrder(count: 10, rng: &rng)
            guard case .success(let card) = TDPKhichai.resolveDraw(
                debtorHand: hand, fanOrder: fan, fanIndex: 0, rng: &rng
            ) else { return XCTFail("draw failed") }
            seen.insert(card.tdpID)
        }
        XCTAssertGreaterThan(seen.count, 15,
                             "Fan position 0 must not map to a predictable card")
    }

    // MARK: Authority

    func testHostRejectsAnIllegalCardFromAGuest() {
        let session = makeSession()
        let spy = ClientSpy()
        session.client.delegate = spy
        session.hostLink.startAdvertising(advert: TDPLobbyAdvert(
            tableId: session.host.engine.state.tableID, hostName: "Mayank",
            humansJoined: 1, targetRounds: 3, isStarted: false))
        session.client.join(spy.tables[0])
        session.host.startGame()
        settle(session, spy: spy)

        guard let view = spy.views.last, view.phase == .play else { return }
        // Ask to play a card the guest does not hold.
        let notInHand = TDPDeck.build().first { card in
            !view.myHand.contains(card)
        }
        guard let notInHand else { return }
        let before = spy.rejections.count
        session.client.send(TDPIntent(kind: .playCard, cardID: notInHand.tdpID))
        XCTAssertGreaterThan(spy.rejections.count, before,
                             "The host must refuse a card the guest does not hold")
    }

    func testAGuestCannotActForAnotherSeat() {
        let session = makeSession()
        let spy = ClientSpy()
        session.client.delegate = spy
        session.hostLink.startAdvertising(advert: TDPLobbyAdvert(
            tableId: session.host.engine.state.tableID, hostName: "Mayank",
            humansJoined: 1, targetRounds: 3, isStarted: false))
        session.client.join(spy.tables[0])
        session.host.startGame()
        settle(session, spy: spy)

        // The intent has no seat field at all — the host derives it from
        // its own registry — so there is nothing for a client to forge.
        let intent = TDPIntent(kind: .trumpSuit, suit: .spades)
        let guestSeat = session.client.seat
        let selector = session.host.engine.state.trumpSelectorSeat
        if selector != guestSeat {
            let before = spy.rejections.count
            session.client.send(intent)
            XCTAssertGreaterThan(spy.rejections.count, before,
                                 "Only the trump selector may choose trump")
        }
    }

    // MARK: Helpers

    /// Lets the host's synchronous work settle.
    private func settle(_ session: (host: TDPHostService, client: TDPClientService,
                                    hostLink: TDPLoopbackTransport, guestLink: TDPLoopbackTransport),
                        spy: ClientSpy) {
        let deadline = Date().addingTimeInterval(2)
        while spy.views.isEmpty && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
    }

    /// Plays the guest's turns legally until the round ends, letting the
    /// host drive its own local seat and the AI.
    private func drive(_ session: (host: TDPHostService, client: TDPClientService,
                                   hostLink: TDPLoopbackTransport, guestLink: TDPLoopbackTransport),
                       spy: ClientSpy,
                       maxSteps: Int) {
        for _ in 0..<maxSteps {
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
            guard let view = spy.views.last else { continue }
            switch view.prompt {
            case .chooseTrump:
                session.client.send(TDPIntent(kind: .trumpSuit, suit: .spades))
            case .khichaiDraw:
                session.client.send(TDPIntent(kind: .khichaiDraw))
            case .khichaiReturn:
                guard let cardID = view.khichai?.legalReturnIDs?.first else { continue }
                session.client.send(TDPIntent(kind: .khichaiReturn, cardID: cardID))
            case .playCard:
                guard let cardID = view.myLegalCardIDs.first else { continue }
                session.client.send(TDPIntent(kind: .playCard, cardID: cardID))
            case .roundEnd:
                return
            default:
                // The host also plays its own seat locally.
                let hostSeat = 0
                if session.host.engine.state.currentTurnSeat == hostSeat,
                   let card = TDPLegalMoves.legalCards(session.host.engine.state, seat: hostSeat).first {
                    session.host.submit(TDPIntent(kind: .playCard, cardID: card.tdpID), from: hostSeat)
                }
            }
        }
    }
}

// MARK: - Spy

private final class ClientSpy: TDPClientServiceDelegate {
    var tables: [TDPDiscoveredTable] = []
    var lobby: TDPLobbySnapshot?
    var views: [TDPClientView] = []
    var rejections: [String] = []
    var joinedSeat: TDPSeat?

    func client(_ service: TDPClientService, didUpdateTables tables: [TDPDiscoveredTable]) {
        self.tables = tables
    }
    func client(_ service: TDPClientService, didJoinSeat seat: TDPSeat) { joinedSeat = seat }
    func client(_ service: TDPClientService, didUpdateLobby snapshot: TDPLobbySnapshot) { lobby = snapshot }
    func client(_ service: TDPClientService, didUpdateView view: TDPClientView) { views.append(view) }
    func client(_ service: TDPClientService, didRejectIntent reason: String) { rejections.append(reason) }
    func client(_ service: TDPClientService, didFailWith reason: String) { rejections.append(reason) }
}
