//
//  PokerClientService.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Guest-side coordinator. Owns no game rules; it forwards the host's
//  snapshots/private-cards/round-results to the local UI and ships
//  action intents back upstream. Stale authoritative messages (lower
//  sequence than the latest applied) are dropped, per PRD §4.
//

import Foundation

protocol PokerClientServiceObserver: AnyObject {
    func client(_ service: PokerClientService, didFindTables tables: [DiscoveredTable])
    func client(_ service: PokerClientService, didReceiveJoinAccepted payload: JoinAcceptedPayload)
    func client(_ service: PokerClientService, didReceiveJoinRejected payload: JoinRejectedPayload)
    func client(_ service: PokerClientService, didReceiveLobby snapshot: LobbySnapshotPayload)
    func client(_ service: PokerClientService, didReceiveSettings payload: LobbySettingsChangedPayload)
    func client(_ service: PokerClientService, didStartGame payload: StartGamePayload)
    func client(_ service: PokerClientService, didReceiveSnapshot snapshot: TableSnapshotPayload)
    func client(_ service: PokerClientService, didReceivePrivateCards payload: PrivateCardsPayload)
    func client(_ service: PokerClientService, didReceiveActionRequest payload: ActionRequestPayload)
    func client(_ service: PokerClientService, didReceiveActionAccepted payload: ActionAcceptedPayload)
    func client(_ service: PokerClientService, didReceiveActionRejected payload: ActionRejectedPayload)
    func client(_ service: PokerClientService, didReceiveRoundResult payload: RoundResultPayload)
    func client(_ service: PokerClientService, didReceiveSessionResult payload: SessionResultPayload)
    func client(_ service: PokerClientService, didPause payload: PausePayload)
    func client(_ service: PokerClientService, didResume payload: ResumePayload)
    func client(_ service: PokerClientService, hostEnded reason: String)
    func client(_ service: PokerClientService, transportError error: Error)
}

final class PokerClientService {

    enum ConnectionState {
        case idle
        case browsing
        case connectingToHost(peerId: String)
        case waitingForJoinAccept
        case inLobby
        case inGame
        case disconnected
    }

    // MARK: State

    private(set) var state: ConnectionState = .idle
    private(set) var discovered: [String: DiscoveredTable] = [:]

    private(set) var sessionId: String?
    private(set) var tableId: String?
    private(set) var seatId: Int?
    private(set) var reconnectToken: String?
    /// Highest applied authoritative sequence. Lower-numbered authoritative
    /// messages are dropped.
    private(set) var lastAppliedSequence: UInt64 = 0
    /// Highest applied hand number — defends against late deliveries of a
    /// previous hand's snapshot.
    private(set) var lastAppliedHandNumber: UInt32 = 0

    /// Local display name. Sent inside `joinRequest`.
    let displayName: String

    private let transport: MultiplayerTransport

    /// Latest authoritative state — kept so a freshly-attached observer
    /// (the `NetworkGameViewController` swapping in over the lobby) can
    /// be replayed immediately rather than waiting for the next message.
    /// Without this, the first `tableSnapshot` and `privateCards` events
    /// of a hand can arrive at the lobby (whose handlers do nothing) and
    /// the network table renders blank until the next street.
    private var lastSnapshot: TableSnapshotPayload?
    private var lastLobby: LobbySnapshotPayload?
    private var lastPrivateCards: PrivateCardsPayload?
    private var lastActionRequest: ActionRequestPayload?

    weak var observer: PokerClientServiceObserver? {
        didSet {
            guard let newObs = observer else { return }
            if let old = oldValue, old === newObs { return }
            replayCurrentState(to: newObs)
        }
    }

    /// Peer id of the host we're connected to (assigned when invite is
    /// accepted). All `send(...)` calls target this peer.
    private var hostPeerId: String?

    init(displayName: String, transport: MultiplayerTransport) {
        self.displayName = displayName
        self.transport = transport
        wireTransport()
    }

    private func wireTransport() {
        transport.onPeerEvent = { [weak self] event in
            self?.handlePeerEvent(event)
        }
        transport.onMessage = { [weak self] data, peerId in
            self?.handleIncoming(data: data, fromPeer: peerId)
        }
    }

    // MARK: Browsing

    func startBrowsing() throws {
        state = .browsing
        try transport.startBrowsing()
    }

    func stopBrowsing() {
        transport.stopBrowsing()
        discovered.removeAll()
    }

    func tablesSnapshot() -> [DiscoveredTable] {
        Array(discovered.values).sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: Join

    func join(table: DiscoveredTable) throws {
        state = .connectingToHost(peerId: table.peerId)
        hostPeerId = table.peerId
        // If we have a saved reconnect token for this host+table from
        // an earlier session (e.g. force-killed and reopened), reuse
        // it so we land on the same seat instead of grabbing a new one.
        if let saved = ReconnectTokenStore.token(forHost: table.peerId,
                                                 tableId: table.advert.tableId) {
            reconnectToken = saved
        }
        try transport.invite(peerId: table.peerId, context: nil)
        // The actual `joinRequest` payload is sent after the MPC session
        // reaches `.peerConnected` for the host (see handlePeerEvent).
    }

    /// Reconnect against a previously-known host using a saved token.
    /// V1 friends-mode: the user must be in range of the same host peer.
    func reconnect(toPeerId peerId: String, token: String) throws {
        reconnectToken = token
        state = .connectingToHost(peerId: peerId)
        hostPeerId = peerId
        try transport.invite(peerId: peerId, context: nil)
    }

    // MARK: Actions

    func sendActionIntent(_ action: PlayerAction) {
        guard let host = hostPeerId, let seatId else { return }
        let name = SnapshotBuilder.encodeActionName(action)
        let raise: Int? = {
            if case let .raise(amount) = action { return amount } else { return nil }
        }()
        let payload = PlayerActionIntentPayload(
            seatId: seatId,
            action: name,
            raiseAmount: raise,
            clientKnownSequence: lastAppliedSequence
        )
        send(type: .playerActionIntent, payload: payload, to: [host])
    }

    func leaveTable() {
        // Friends-mode disconnect: the host treats explicit "Leave"
        // and a transient transport drop identically — both flow
        // through `peerDisconnected` → `markSeatAwayMidGame`. We
        // intentionally do NOT send a `peerLeft` message: MPC's
        // reliable send can be dropped from the queue when we tear
        // down the session in the next line, so it isn't a dependable
        // signal. One code path, fewer invariants.
        transport.disconnect()
        state = .disconnected
    }

    // MARK: Peer events

    private func handlePeerEvent(_ event: TransportPeerEvent) {
        switch event {
        case .foundPeer(let peerId, let displayName, let info):
            if let advert = PokerLobbyAdvert(discoveryInfo: info, tableId: peerId,
                                             displayName: displayName) {
                discovered[peerId] = DiscoveredTable(peerId: peerId,
                                                     displayName: displayName,
                                                     advert: advert,
                                                     lastSeen: Date())
                observer?.client(self, didFindTables: tablesSnapshot())
            }

        case .lostPeer(let peerId):
            discovered.removeValue(forKey: peerId)
            observer?.client(self, didFindTables: tablesSnapshot())

        case .peerConnected(let peerId, _):
            // We only care about the host's connection.
            if peerId == hostPeerId {
                state = .waitingForJoinAccept
                // Send our join/reconnect intent now that the session is open.
                let payload = JoinRequestPayload(
                    displayName: displayName,
                    clientVersion: PokerProtocol.version,
                    reconnectToken: reconnectToken
                )
                send(type: .joinRequest, payload: payload, to: [peerId])
            }

        case .peerDisconnected(let peerId, _):
            if peerId == hostPeerId {
                state = .disconnected
                observer?.client(self, hostEnded: "Host disconnected.")
            }

        case .transportError(let err):
            observer?.client(self, transportError: err)

        case .receivedInvitation, .peerConnecting:
            break
        }
    }

    // MARK: Incoming

    private func handleIncoming(data: Data, fromPeer peerId: String) {
        let decoded: DecodedPokerMessage
        do { decoded = try PokerWireCodec.decode(data) }
        catch {
            #if DEBUG
            print("Client: decode failure from \(peerId): \(error)")
            #endif
            return
        }

        // Drop stale authoritative messages with a lower sequence.
        if let seq = decoded.header.sequence,
           [.tableSnapshot, .actionAccepted, .privateCards].contains(decoded.type) {
            if seq <= lastAppliedSequence && lastAppliedSequence > 0 {
                return
            }
            lastAppliedSequence = seq
        }
        if let hand = decoded.header.handNumber {
            // Snapshots tied to an older hand are also dropped.
            if hand < lastAppliedHandNumber && decoded.type == .tableSnapshot {
                return
            }
            lastAppliedHandNumber = max(lastAppliedHandNumber, hand)
        }

        switch decoded.type {
        case .joinAccepted:
            if let p: JoinAcceptedPayload = try? decoded.decodePayload() {
                seatId = p.seatId
                sessionId = p.lobby.sessionId
                tableId = p.lobby.tableId
                reconnectToken = p.reconnectToken
                // Persist so a force-kill + relaunch can still reclaim
                // this seat (see ReconnectTokenStore in
                // MultiplayerEntryViewController.swift).
                if let host = hostPeerId {
                    ReconnectTokenStore.save(
                        hostPeerId: host,
                        tableId: p.lobby.tableId,
                        token: p.reconnectToken,
                        seatId: p.seatId
                    )
                }
                state = .inLobby
                lastLobby = p.lobby
                observer?.client(self, didReceiveJoinAccepted: p)
                observer?.client(self, didReceiveLobby: p.lobby)
            }

        case .joinRejected:
            if let p: JoinRejectedPayload = try? decoded.decodePayload() {
                state = .disconnected
                observer?.client(self, didReceiveJoinRejected: p)
                transport.disconnect()
            }

        case .seatUpdate:
            if let p: SeatUpdatePayload = try? decoded.decodePayload(),
               let session = sessionId, let table = tableId {
                // Preserve the blinds/buy-in we learned in joinAccepted /
                // lobbySettingsChanged — seatUpdate is a seats-only diff.
                let prev = lastLobby
                let snap = LobbySnapshotPayload(
                    tableId: table, sessionId: session,
                    smallBlind: prev?.smallBlind ?? 0,
                    bigBlind: prev?.bigBlind ?? 0,
                    startingChips: prev?.startingChips ?? 0,
                    totalSeats: p.seats.count,
                    aiFillEnabled: prev?.aiFillEnabled ?? true,
                    seats: p.seats,
                    hostPeerId: hostPeerId ?? ""
                )
                lastLobby = snap
                observer?.client(self, didReceiveLobby: snap)
            }

        case .lobbySettingsChanged:
            if let p: LobbySettingsChangedPayload = try? decoded.decodePayload() {
                observer?.client(self, didReceiveSettings: p)
            }

        case .startGame:
            if let p: StartGamePayload = try? decoded.decodePayload() {
                state = .inGame
                observer?.client(self, didStartGame: p)
            }

        case .tableSnapshot:
            if let p: TableSnapshotPayload = try? decoded.decodePayload() {
                state = .inGame
                lastSnapshot = p
                // Clear stale per-hand caches when a new hand arrives.
                if let priv = lastPrivateCards, priv.handNumber != p.handNumber {
                    lastPrivateCards = nil
                }
                if p.currentPlayerSeat != seatId {
                    lastActionRequest = nil
                }
                observer?.client(self, didReceiveSnapshot: p)
            }

        case .privateCards:
            if let p: PrivateCardsPayload = try? decoded.decodePayload() {
                lastPrivateCards = p
                observer?.client(self, didReceivePrivateCards: p)
            }

        case .actionRequest:
            if let p: ActionRequestPayload = try? decoded.decodePayload() {
                lastActionRequest = p
                observer?.client(self, didReceiveActionRequest: p)
            }

        case .actionAccepted:
            if let p: ActionAcceptedPayload = try? decoded.decodePayload() {
                observer?.client(self, didReceiveActionAccepted: p)
            }

        case .actionRejected:
            if let p: ActionRejectedPayload = try? decoded.decodePayload() {
                observer?.client(self, didReceiveActionRejected: p)
            }

        case .roundResult:
            if let p: RoundResultPayload = try? decoded.decodePayload() {
                observer?.client(self, didReceiveRoundResult: p)
            }

        case .sessionResult:
            if let p: SessionResultPayload = try? decoded.decodePayload() {
                observer?.client(self, didReceiveSessionResult: p)
            }

        case .pause:
            if let p: PausePayload = try? decoded.decodePayload() {
                observer?.client(self, didPause: p)
            }

        case .resume:
            if let p: ResumePayload = try? decoded.decodePayload() {
                observer?.client(self, didResume: p)
            }

        case .reconnectAccepted:
            if let p: ReconnectAcceptedPayload = try? decoded.decodePayload() {
                seatId = p.seatId
                if let lobby = p.lobby {
                    state = .inLobby
                    observer?.client(self, didReceiveLobby: lobby)
                } else {
                    state = .inGame
                }
            }

        case .hostEndingTable:
            if let p: HostEndingTablePayload = try? decoded.decodePayload() {
                state = .disconnected
                // Drop the saved reconnect token — this table is gone.
                if let host = hostPeerId { ReconnectTokenStore.clear(hostPeerId: host) }
                observer?.client(self, hostEnded: p.reason)
                transport.disconnect()
            }

        case .ping:
            if let p: PingPayload = try? decoded.decodePayload() {
                send(type: .pong, payload: PongPayload(nonce: p.nonce, sentAtMs: p.sentAtMs),
                     to: [peerId])
            }

        case .pong, .joinRequest, .peerLeft, .readyChanged, .playerActionIntent, .reconnectRequest:
            // Client doesn't act on these — they originate from this side
            // or are unused in v1.
            break
        }
    }

    // MARK: Replay

    /// Replays cached state at a freshly-attached observer so the UI
    /// reflects the current table immediately. Without this, the first
    /// few messages of a hand (snapshot, private cards, action request)
    /// can land on the lobby's empty handlers and the table renders
    /// blank.
    private func replayCurrentState(to observer: PokerClientServiceObserver) {
        if let lobby = lastLobby {
            observer.client(self, didReceiveLobby: lobby)
        }
        if let snap = lastSnapshot {
            observer.client(self, didReceiveSnapshot: snap)
        }
        if let priv = lastPrivateCards,
           let snap = lastSnapshot,
           priv.handNumber == snap.handNumber {
            observer.client(self, didReceivePrivateCards: priv)
        }
        if let req = lastActionRequest, req.seatId == seatId {
            observer.client(self, didReceiveActionRequest: req)
        }
    }

    // MARK: Send helpers

    private func send<P: Codable>(type: PokerMessageType, payload: P, to peerIds: [String]) {
        let envelope = PokerMessage(
            sessionId: sessionId ?? "",
            tableId: tableId ?? "",
            handNumber: nil,
            sequence: nil,
            senderPeerId: transport.localPeerId,
            type: type,
            payload: payload
        )
        do {
            let data = try PokerWireCodec.encode(envelope)
            try transport.send(data, to: peerIds)
        } catch {
            #if DEBUG
            print("Client send \(type) failed: \(error)")
            #endif
        }
    }
}
