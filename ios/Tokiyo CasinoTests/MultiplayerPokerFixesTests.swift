import XCTest
@testable import Tokiyo_Casino

final class MultiplayerPokerFixesTests: XCTestCase {

    private let reconnectDefaultsKey = "tokiyo.poker.mp.reconnectTokens"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: reconnectDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: reconnectDefaultsKey)
        super.tearDown()
    }

    func testGoldenTableSnapshotFixtureRoundTripsAndContainsAway() throws {
        try ProtocolGoldenFixtures.validateAll()
        XCTAssertTrue(ProtocolGoldenFixtures.tableSnapshotV1.contains("\"bigBlind\":20"))
        XCTAssertTrue(ProtocolGoldenFixtures.tableSnapshotV1.contains("\"isAway\":false"))
    }

    func testWireCodecRejectsOversizeAndUnsupportedVersion() throws {
        let oversizePayload = JoinRejectedPayload(reason: String(repeating: "x", count: PokerProtocol.maxPayloadBytes))
        let oversize = PokerMessage(
            sessionId: "s", tableId: "t", senderPeerId: "h",
            type: .joinRejected, payload: oversizePayload
        )
        XCTAssertThrowsError(try PokerWireCodec.encode(oversize))
        XCTAssertThrowsError(try PokerWireCodec.decode(Data(repeating: 1, count: PokerProtocol.maxPayloadBytes + 1)))

        let valid = PokerMessage(
            sessionId: "s", tableId: "t", senderPeerId: "h",
            type: .ping, payload: PingPayload(nonce: 1, sentAtMs: 2)
        )
        let data = try PokerWireCodec.encode(valid)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["protocolVersion"] = PokerProtocol.version + 1
        let unsupported = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(try PokerWireCodec.decode(unsupported))
    }

    func testHostRejectsStaleAndInvalidRaiseIntents() throws {
        var harness = try HostHarness(totalSeats: 2, aiFillEnabled: false)
        try harness.joinGuest(peerId: "Guest")
        XCTAssertTrue(harness.host.startGame())
        let request = try harness.latestActionRequest(to: "Guest")

        try harness.sendIntent(
            peerId: "Guest",
            action: "raise",
            raiseAmount: request.payload.minRaise,
            clientKnownSequence: request.sequence - 1
        )
        XCTAssertTrue(try harness.sentMessages(to: "Guest").containsType(.actionRejected))

        harness = try HostHarness(totalSeats: 2, aiFillEnabled: false)
        try harness.joinGuest(peerId: "Guest")
        XCTAssertTrue(harness.host.startGame())
        let underMin = try harness.latestActionRequest(to: "Guest")
        try harness.sendIntent(
            peerId: "Guest",
            action: "raise",
            raiseAmount: underMin.payload.minRaise - 1,
            clientKnownSequence: underMin.sequence
        )
        XCTAssertTrue(try harness.sentMessages(to: "Guest").containsType(.actionRejected))

        harness = try HostHarness(totalSeats: 2, aiFillEnabled: false)
        try harness.joinGuest(peerId: "Guest")
        XCTAssertTrue(harness.host.startGame())
        let overMax = try harness.latestActionRequest(to: "Guest")
        try harness.sendIntent(
            peerId: "Guest",
            action: "raise",
            raiseAmount: overMax.payload.maxRaise + 1,
            clientKnownSequence: overMax.sequence
        )
        XCTAssertTrue(try harness.sentMessages(to: "Guest").containsType(.actionRejected))

        harness = try HostHarness(totalSeats: 2, aiFillEnabled: false)
        try harness.joinGuest(peerId: "Guest")
        XCTAssertTrue(harness.host.startGame())
        let malformed = try harness.latestActionRequest(to: "Guest")
        try harness.sendIntent(
            peerId: "Guest",
            action: "call",
            raiseAmount: 10,
            clientKnownSequence: malformed.sequence
        )
        XCTAssertTrue(try harness.sentMessages(to: "Guest").containsType(.actionRejected))
    }

    func testKickingCurrentAIAdvancesTurnAndPreservesChipInvariant() throws {
        let harness = try HostHarness(totalSeats: 3, aiFillEnabled: true)
        XCTAssertTrue(harness.host.startGame())
        let gm = try XCTUnwrap(harness.host.gameManager)
        let kickedSeat = try XCTUnwrap(gm.currentPlayer?.id)
        let expectedBefore = gm.expectedTotalChips

        try harness.queuePendingJoin(peerId: "Guest", displayName: "Guest")
        harness.host.acceptPendingJoin(kickSeatId: kickedSeat)

        XCTAssertEqual(gm.expectedTotalChips, expectedBefore)
        XCTAssertNotEqual(gm.currentPlayer?.id, kickedSeat)
        XCTAssertNotNil(gm.currentPlayer)
    }

    func testOpenSeatMidGameJoinAdjustsChipInvariant() throws {
        let harness = try HostHarness(totalSeats: 3, aiFillEnabled: true, startingChips: 1000)
        XCTAssertTrue(harness.host.startGame())
        let gm = try XCTUnwrap(harness.host.gameManager)
        let expectedBefore = gm.expectedTotalChips

        harness.host.seatRegistry.seats[1] = SeatRegistry.SeatRecord(
            seatId: 1, kind: .open, displayName: "Seat 2",
            peerId: nil, reconnectToken: nil,
            isReady: false, isDisconnected: false, aiTookOver: false
        )
        gm.players[1].chips = 250

        try harness.queuePendingJoin(peerId: "Guest", displayName: "Guest")

        XCTAssertEqual(gm.expectedTotalChips, expectedBefore + 750)
    }

    func testEndTableIsIdempotentAndBlocksNewHands() throws {
        let harness = try HostHarness(totalSeats: 3, aiFillEnabled: true)
        XCTAssertTrue(harness.host.startGame())
        let handBeforeEnd = harness.host.handNumber

        harness.host.endTable(reason: "done")
        harness.host.endTable(reason: "done again")
        harness.host.beginNextHand()

        XCTAssertEqual(harness.host.handNumber, handBeforeEnd)
        XCTAssertEqual(try harness.broadcastMessages().filterType(.hostEndingTable).count, 1)
    }

    func testClientDropsStaleActionRequestAndReplaysFreshOne() throws {
        let harness = ClientHarness()
        try harness.joinAndAccept()
        let snapshot = TestPayloads.snapshot(handNumber: 1, currentPlayerSeat: 1)
        try harness.inject(.tableSnapshot, payload: snapshot, handNumber: 1, sequence: 5)
        let staleRequest = ActionRequestPayload(
            seatId: 1, validActions: ["call"], callAmount: 10,
            minRaise: 20, maxRaise: 500, currentBet: 20,
            allInTotal: 1000, deadlineSeconds: nil
        )
        try harness.inject(.actionRequest, payload: staleRequest, handNumber: 1, sequence: 4)
        XCTAssertTrue(harness.observer.actionRequests.isEmpty)

        let freshHarness = ClientHarness()
        try freshHarness.joinAndAccept()
        try freshHarness.inject(.actionRequest, payload: staleRequest, handNumber: 1, sequence: 1)
        XCTAssertEqual(freshHarness.observer.actionRequests.count, 1)

        let replayObserver = RecordingClientObserver()
        freshHarness.client.observer = replayObserver
        XCTAssertEqual(replayObserver.actionRequests.count, 1)
    }

    func testClientMergesLobbySettingsBeforeSeatUpdates() throws {
        let harness = ClientHarness()
        try harness.joinAndAccept()
        let settings = LobbySettingsChangedPayload(
            smallBlind: 25, bigBlind: 50, startingChips: 2000,
            totalSeats: 6, aiFillEnabled: false
        )
        try harness.inject(.lobbySettingsChanged, payload: settings)
        XCTAssertEqual(harness.observer.lobbies.last?.smallBlind, 25)
        XCTAssertEqual(harness.observer.lobbies.last?.bigBlind, 50)
        XCTAssertEqual(harness.observer.lobbies.last?.startingChips, 2000)

        let seats = [LobbySeatPayload(seatId: 0, displayName: "Host", kind: "host", peerId: nil, isHost: true, isReady: true)]
        try harness.inject(.seatUpdate, payload: SeatUpdatePayload(seats: seats))

        XCTAssertEqual(harness.observer.lobbies.last?.smallBlind, 25)
        XCTAssertEqual(harness.observer.lobbies.last?.bigBlind, 50)
        XCTAssertEqual(harness.observer.lobbies.last?.startingChips, 2000)
        XCTAssertEqual(harness.observer.lobbies.last?.aiFillEnabled, false)
    }

    func testReconnectTokenStoreRoundTripCapClearAndCorruptionHandling() {
        for idx in 0..<20 {
            XCTAssertTrue(ReconnectTokenStore.save(
                hostPeerId: "host-\(idx)", tableId: "table",
                token: "token-\(idx)", seatId: idx
            ))
        }
        XCTAssertNil(ReconnectTokenStore.token(forHost: "host-0", tableId: "table"))
        XCTAssertEqual(ReconnectTokenStore.token(forHost: "host-19", tableId: "table"), "token-19")

        XCTAssertTrue(ReconnectTokenStore.clear(hostPeerId: "host-19"))
        XCTAssertNil(ReconnectTokenStore.token(forHost: "host-19", tableId: "table"))

        UserDefaults.standard.set(Data("not-json".utf8), forKey: reconnectDefaultsKey)
        XCTAssertNil(ReconnectTokenStore.token(forHost: "host-18", tableId: "table"))
        XCTAssertNil(UserDefaults.standard.data(forKey: reconnectDefaultsKey))
    }
}

private struct HostHarness {
    let transport: FakeTransport
    let host: PokerHostService

    init(totalSeats: Int, aiFillEnabled: Bool, startingChips: Int = 1000) throws {
        transport = FakeTransport(localPeerId: "Host")
        host = PokerHostService(
            config: PokerHostService.Config(
                displayName: "Host", smallBlind: 10, bigBlind: 20,
                startingChips: startingChips, totalSeats: totalSeats,
                aiFillEnabled: aiFillEnabled
            ),
            transport: transport
        )
        try host.startAdvertising()
    }

    func joinGuest(peerId: String) throws {
        let before = transport.sent.count
        try queuePendingJoin(peerId: peerId, displayName: peerId)
        XCTAssertGreaterThan(transport.sent.count, before)
    }

    func queuePendingJoin(peerId: String, displayName: String) throws {
        let payload = JoinRequestPayload(displayName: displayName, clientVersion: PokerProtocol.version, reconnectToken: nil)
        let message = PokerMessage(
            sessionId: "", tableId: "", senderPeerId: peerId,
            type: .joinRequest, payload: payload
        )
        transport.injectMessage(try PokerWireCodec.encode(message), from: peerId)
    }

    func latestActionRequest(to peerId: String) throws -> (payload: ActionRequestPayload, sequence: UInt64) {
        let messages = try sentMessages(to: peerId)
        for message in messages.reversed() where message.type == .actionRequest {
            return (try message.decodePayload(ActionRequestPayload.self), try XCTUnwrap(message.header.sequence))
        }
        return XCTFailAndThrow("No actionRequest sent to \(peerId)")
    }

    func sendIntent(peerId: String, action: String, raiseAmount: Int?, clientKnownSequence: UInt64) throws {
        let payload = PlayerActionIntentPayload(
            seatId: try XCTUnwrap(host.seatRegistry.seat(forPeer: peerId)),
            action: action,
            raiseAmount: raiseAmount,
            clientKnownSequence: clientKnownSequence
        )
        let message = PokerMessage(
            sessionId: host.sessionId, tableId: host.tableId,
            senderPeerId: peerId, type: .playerActionIntent, payload: payload
        )
        transport.injectMessage(try PokerWireCodec.encode(message), from: peerId)
    }

    func sentMessages(to peerId: String) throws -> [DecodedPokerMessage] {
        try transport.sent
            .filter { $0.peerIds.contains(peerId) }
            .map { try PokerWireCodec.decode($0.data) }
    }

    func broadcastMessages() throws -> [DecodedPokerMessage] {
        try transport.broadcasts.map { try PokerWireCodec.decode($0) }
    }
}

private final class ClientHarness {
    let transport = FakeTransport(localPeerId: "Guest")
    let client: PokerClientService
    let observer = RecordingClientObserver()

    init() {
        client = PokerClientService(displayName: "Guest", transport: transport)
        client.observer = observer
    }

    func joinAndAccept() throws {
        let table = DiscoveredTable(
            peerId: "Host",
            displayName: "Host",
            advert: PokerLobbyAdvert(
                tableId: "table", displayName: "Host", hostName: "Host",
                smallBlind: 10, bigBlind: 20, totalSeats: 6,
                humansJoined: 1, aiFillEnabled: true, isStarted: false
            ),
            lastSeen: Date()
        )
        try client.join(table: table)
        transport.injectEvent(.peerConnected(peerId: "Host", displayName: "Host"))
        let lobby = TestPayloads.lobby()
        let accepted = JoinAcceptedPayload(seatId: 1, displayName: "Guest", reconnectToken: "token", lobby: lobby)
        try inject(.joinAccepted, payload: accepted)
    }

    func inject<P: Codable>(_ type: PokerMessageType, payload: P, handNumber: UInt32? = nil, sequence: UInt64? = nil) throws {
        let message = PokerMessage(
            sessionId: "session", tableId: "table",
            handNumber: handNumber, sequence: sequence,
            senderPeerId: "Host", type: type, payload: payload
        )
        transport.injectMessage(try PokerWireCodec.encode(message), from: "Host")
    }
}

private final class FakeTransport: MultiplayerTransport {
    struct Sent {
        let data: Data
        let peerIds: [String]
    }

    let localPeerId: String
    var onPeerEvent: ((TransportPeerEvent) -> Void)?
    var onMessage: ((TransportMessage, String) -> Void)?
    var sent: [Sent] = []
    var broadcasts: [Data] = []
    var adverts: [PokerLobbyAdvert] = []
    var didDisconnect = false

    init(localPeerId: String) {
        self.localPeerId = localPeerId
    }

    func startAdvertising(advert: PokerLobbyAdvert) throws {
        adverts.append(advert)
    }

    func updateAdvert(_ advert: PokerLobbyAdvert) throws {
        adverts.append(advert)
    }

    func stopAdvertising() {}
    func accept(peerId: String) throws {}
    func reject(peerId: String) {}
    func startBrowsing() throws {}
    func stopBrowsing() {}
    func invite(peerId: String, context: Data?) throws {}

    func send(_ message: TransportMessage, to peerIds: [String]) throws {
        sent.append(Sent(data: message, peerIds: peerIds))
    }

    func broadcast(_ message: TransportMessage) throws {
        broadcasts.append(message)
    }

    func disconnect() {
        didDisconnect = true
    }

    func injectMessage(_ data: Data, from peerId: String) {
        onMessage?(data, peerId)
    }

    func injectEvent(_ event: TransportPeerEvent) {
        onPeerEvent?(event)
    }
}

private final class RecordingClientObserver: PokerClientServiceObserver {
    var lobbies: [LobbySnapshotPayload] = []
    var actionRequests: [ActionRequestPayload] = []

    func client(_ service: PokerClientService, didFindTables tables: [DiscoveredTable]) {}
    func client(_ service: PokerClientService, didReceiveJoinAccepted payload: JoinAcceptedPayload) {}
    func client(_ service: PokerClientService, didReceiveJoinRejected payload: JoinRejectedPayload) {}
    func client(_ service: PokerClientService, didReceiveLobby snapshot: LobbySnapshotPayload) { lobbies.append(snapshot) }
    func client(_ service: PokerClientService, didReceiveSettings payload: LobbySettingsChangedPayload) {}
    func client(_ service: PokerClientService, didStartGame payload: StartGamePayload) {}
    func client(_ service: PokerClientService, didReceiveSnapshot snapshot: TableSnapshotPayload) {}
    func client(_ service: PokerClientService, didReceivePrivateCards payload: PrivateCardsPayload) {}
    func client(_ service: PokerClientService, didReceiveActionRequest payload: ActionRequestPayload) { actionRequests.append(payload) }
    func client(_ service: PokerClientService, didReceiveActionAccepted payload: ActionAcceptedPayload) {}
    func client(_ service: PokerClientService, didReceiveActionRejected payload: ActionRejectedPayload) {}
    func client(_ service: PokerClientService, didReceiveRoundResult payload: RoundResultPayload) {}
    func client(_ service: PokerClientService, didReceiveSessionResult payload: SessionResultPayload) {}
    func client(_ service: PokerClientService, didPause payload: PausePayload) {}
    func client(_ service: PokerClientService, didResume payload: ResumePayload) {}
    func client(_ service: PokerClientService, hostEnded reason: String) {}
    func client(_ service: PokerClientService, transportError error: Error) {}
}

private enum TestPayloads {
    static func lobby() -> LobbySnapshotPayload {
        LobbySnapshotPayload(
            tableId: "table", sessionId: "session",
            smallBlind: 10, bigBlind: 20, startingChips: 1000,
            totalSeats: 6, aiFillEnabled: true,
            seats: [
                LobbySeatPayload(seatId: 0, displayName: "Host", kind: "host", peerId: nil, isHost: true, isReady: true),
                LobbySeatPayload(seatId: 1, displayName: "Guest", kind: "remote", peerId: "Guest", isHost: false, isReady: false)
            ],
            hostPeerId: "Host"
        )
    }

    static func snapshot(handNumber: UInt32, currentPlayerSeat: Int?) -> TableSnapshotPayload {
        TableSnapshotPayload(
            phase: "preFlop",
            handNumber: handNumber,
            dealerSeat: 0,
            currentPlayerSeat: currentPlayerSeat,
            smallBlind: 10,
            bigBlind: 20,
            currentBet: 20,
            minRaise: 20,
            pot: 30,
            communityCards: [],
            players: [
                PublicPlayerStatePayload(
                    seatId: 0, displayName: "Host", kind: "human",
                    chips: 980, currentBet: 20, totalInvested: 20,
                    isFolded: false, isAllIn: false, isActive: true,
                    isDealer: true, lastAction: nil, lastActionAmount: nil,
                    hasCards: true, isDisconnected: false, isAway: false,
                    isAITakenOver: false, revealedHoleCards: nil
                ),
                PublicPlayerStatePayload(
                    seatId: 1, displayName: "Guest", kind: "human",
                    chips: 990, currentBet: 10, totalInvested: 10,
                    isFolded: false, isAllIn: false, isActive: true,
                    isDealer: false, lastAction: nil, lastActionAmount: nil,
                    hasCards: true, isDisconnected: false, isAway: false,
                    isAITakenOver: false, revealedHoleCards: nil
                )
            ],
            isPaused: false,
            pausedForSeatId: nil
        )
    }
}

private extension Array where Element == DecodedPokerMessage {
    func containsType(_ type: PokerMessageType) -> Bool {
        contains { $0.type == type }
    }

    func filterType(_ type: PokerMessageType) -> [DecodedPokerMessage] {
        filter { $0.type == type }
    }
}

private func XCTFailAndThrow<T>(_ message: String, file: StaticString = #filePath, line: UInt = #line) -> T {
    XCTFail(message, file: file, line: line)
    fatalError(message)
}
