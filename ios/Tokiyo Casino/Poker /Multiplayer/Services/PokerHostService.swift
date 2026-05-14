//
//  PokerHostService.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Host-authoritative coordinator. Owns the `GameManager`, maps peers to
//  seats, validates action intents, broadcasts public snapshots, and
//  sends private hole cards to the right peer. The host's own UI
//  observes this service through `PokerHostServiceObserver` exactly the
//  same way clients observe `PokerClientService` — one rendering layer.
//

import Foundation

/// View-controller-facing surface for the host.
protocol PokerHostServiceObserver: AnyObject {
    func host(_ service: PokerHostService, didUpdateLobby snapshot: LobbySnapshotPayload)
    func host(_ service: PokerHostService, didUpdateSnapshot snapshot: TableSnapshotPayload)
    func host(_ service: PokerHostService, didReceivePrivateCards payload: PrivateCardsPayload)
    func host(_ service: PokerHostService, didCompleteRound payload: RoundResultPayload)
    func host(_ service: PokerHostService, didEndSession payload: SessionResultPayload)
    func host(_ service: PokerHostService, didRequestAction payload: ActionRequestPayload)
    func host(_ service: PokerHostService, didFinishWithReason reason: String)
}

final class PokerHostService {

    // MARK: Config

    struct Config {
        var displayName: String
        var smallBlind: Int
        var bigBlind: Int
        var startingChips: Int
        var totalSeats: Int
        var aiFillEnabled: Bool
    }

    // MARK: State

    let sessionId: String = UUID().uuidString
    let tableId: String = UUID().uuidString

    private(set) var config: Config
    private(set) var seatRegistry = SeatRegistry()
    private(set) var gameManager: GameManager?
    private(set) var handNumber: UInt32 = 0
    private(set) var hasStarted: Bool = false

    private let transport: MultiplayerTransport
    private var sequence: UInt64 = 0
    private var reconnectTimers: [Int: Timer] = [:]

    /// Coalescing buffer for per-side-pot winner notifications.
    private var pendingWinners: [(player: Player, amount: Int, handDescription: String)] = []
    private var pendingWinnersFlush: DispatchWorkItem?

    weak var observer: PokerHostServiceObserver?

    /// The host's own seat id. Conventionally 0 so the host appears at
    /// the bottom of the felt (matching the existing solo UX).
    let hostSeatId: Int = 0

    // MARK: Init

    init(config: Config, transport: MultiplayerTransport) {
        self.config = config
        self.transport = transport
        seatRegistry.reset(
            totalSeats: config.totalSeats,
            hostSeatId: hostSeatId,
            hostName: config.displayName
        )
        wireTransport()
        installWinnerObserver()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func wireTransport() {
        transport.onPeerEvent = { [weak self] event in
            self?.handlePeerEvent(event)
        }
        transport.onMessage = { [weak self] data, peerId in
            self?.handleIncoming(data: data, fromPeer: peerId)
        }
    }

    private func installWinnerObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowWinnerAlert(_:)),
            name: NSNotification.Name("ShowWinnerAlert"),
            object: nil
        )
    }

    // MARK: Lobby control

    func startAdvertising() throws {
        let advert = currentAdvert()
        try transport.startAdvertising(advert: advert)
        broadcastLobbySnapshot()
    }

    func updateSettings(_ block: (inout Config) -> Void) {
        var copy = config
        block(&copy)
        let occupied = seatRegistry.seats.filter { $0.kind != .open }.count
        copy.totalSeats = max(occupied, min(copy.totalSeats, PokerProtocol.maxTotalSeats))
        config = copy
        seatRegistry.setSettings(totalSeats: copy.totalSeats)
        try? transport.updateAdvert(currentAdvert())
        broadcastLobbySettings()
        broadcastLobbySnapshot()
    }

    private func currentAdvert() -> PokerLobbyAdvert {
        PokerLobbyAdvert(
            tableId: tableId,
            displayName: config.displayName,
            hostName: config.displayName,
            smallBlind: config.smallBlind,
            bigBlind: config.bigBlind,
            totalSeats: config.totalSeats,
            humansJoined: seatRegistry.seats.filter { $0.kind == .host || $0.kind == .remote }.count,
            aiFillEnabled: config.aiFillEnabled,
            isStarted: hasStarted
        )
    }

    // MARK: Start game

    @discardableResult
    func startGame() -> Bool {
        guard !hasStarted else { return true }

        // Fill open seats with AI (if enabled), otherwise compact roster.
        if config.aiFillEnabled {
            let personalities = AIPersonality.allCases
            var pIdx = 0
            for (idx, seat) in seatRegistry.seats.enumerated() where seat.kind == .open {
                let personality = personalities[pIdx % personalities.count]
                pIdx += 1
                seatRegistry.swapToAI(
                    seatId: idx,
                    displayName: "\(personality.avatar) \(personality.name)"
                )
                // swapToAI marks aiTookOver=true (intended for disconnects);
                // reset that for AI-fill seats.
                seatRegistry.seats[idx].aiTookOver = false
            }
        } else {
            let occupied = seatRegistry.seats.filter { $0.kind != .open }
            seatRegistry.seats = occupied.enumerated().map { (i, rec) in
                SeatRegistry.SeatRecord(
                    seatId: i, kind: rec.kind, displayName: rec.displayName,
                    peerId: rec.peerId, reconnectToken: rec.reconnectToken,
                    isReady: rec.isReady, isDisconnected: rec.isDisconnected,
                    aiTookOver: rec.aiTookOver
                )
            }
        }

        let personalities = AIPersonality.allCases
        var aiIdx = 0
        let roster: [Player] = seatRegistry.seats.map { rec in
            switch rec.kind {
            case .host, .remote:
                return Player(id: rec.seatId, name: rec.displayName,
                              type: .human, chips: config.startingChips)
            case .ai, .open:
                let personality = personalities[aiIdx % personalities.count]
                aiIdx += 1
                return Player(id: rec.seatId, name: rec.displayName,
                              type: .ai(personality: personality),
                              chips: config.startingChips)
            }
        }

        guard roster.count >= 2 else { return false }

        let gm = GameManager(
            seats: roster,
            smallBlind: config.smallBlind,
            bigBlind: config.bigBlind,
            startingChips: config.startingChips
        )
        gm.delegate = self
        self.gameManager = gm
        hasStarted = true

        try? transport.updateAdvert(currentAdvert())
        broadcast(type: .startGame, payload: StartGamePayload(firstHandNumber: 1))

        beginNextHand()
        return true
    }

    func beginNextHand() {
        guard let gm = gameManager else { return }

        // End the session if only one player has chips.
        let withChips = gm.players.filter { $0.chips > 0 }
        if withChips.count < 2 {
            let payload = SessionResultPayload(
                reason: "Only one player has chips remaining.",
                standings: gm.players.map { p in
                    SessionStandingPayload(
                        seatId: gm.players.firstIndex(where: { $0.id == p.id }) ?? p.id,
                        displayName: p.name,
                        chips: p.chips,
                        netDelta: p.chips - config.startingChips,
                        handsPlayed: p.handsPlayed,
                        handsWon: p.handsWon
                    )
                }
            )
            broadcast(type: .sessionResult, payload: payload)
            observer?.host(self, didEndSession: payload)
            return
        }

        handNumber &+= 1
        gm.startNewHand()
        sendPrivateCardsToAllSeats()
        broadcastSnapshot()
    }

    // MARK: Snapshots / private cards

    func broadcastSnapshot(revealedSeats: Set<Int> = [],
                           isPaused: Bool = false,
                           pausedForSeatId: Int? = nil) {
        guard let gm = gameManager else { return }
        let snapshot = SnapshotBuilder.build(
            gameManager: gm,
            handNumber: handNumber,
            playerKindBySeat: seatRegistry.playerKindBySeatId(),
            disconnectedSeats: seatRegistry.disconnectedSeats(),
            aiTakenOverSeats: seatRegistry.aiTakenOverSeats(),
            revealedSeats: revealedSeats,
            isPaused: isPaused,
            pausedForSeatId: pausedForSeatId
        )
        broadcast(type: .tableSnapshot, payload: snapshot, withHandSequence: true)
        observer?.host(self, didUpdateSnapshot: snapshot)

        // Send an action request to whichever seat has the current turn.
        if let currentSeat = snapshot.currentPlayerSeat,
           let seatRec = seatRegistry.record(forSeat: currentSeat),
           let player = gm.players.first(where: { $0.id == currentSeat }) {
            let valid = gm.getValidActions(for: player)
            let callAmount = max(0, gm.currentBet - player.currentBet)
            let maxRaise = max(0, player.chips - callAmount)
            let req = ActionRequestPayload(
                seatId: currentSeat,
                validActions: valid.map { SnapshotBuilder.encodeActionName($0) },
                callAmount: callAmount,
                minRaise: gm.minRaise,
                maxRaise: maxRaise,
                currentBet: gm.currentBet,
                allInTotal: player.currentBet + player.chips,
                deadlineSeconds: nil
            )
            switch seatRec.kind {
            case .host:
                observer?.host(self, didRequestAction: req)
            case .remote:
                if let peer = seatRec.peerId {
                    send(type: .actionRequest, payload: req, to: [peer], withHandSequence: true)
                }
            case .ai, .open:
                break
            }
        }
    }

    private func sendPrivateCardsToAllSeats() {
        guard let gm = gameManager else { return }
        for player in gm.players {
            guard !player.holeCards.isEmpty else { continue }
            let seatId = gm.players.firstIndex(where: { $0.id == player.id }) ?? player.id
            let payload = PrivateCardsPayload(
                seatId: seatId, handNumber: handNumber,
                cards: player.holeCards.map { $0.dto }
            )
            guard let rec = seatRegistry.record(forSeat: seatId) else { continue }
            switch rec.kind {
            case .host:
                observer?.host(self, didReceivePrivateCards: payload)
            case .remote:
                if let peer = rec.peerId {
                    send(type: .privateCards, payload: payload, to: [peer], withHandSequence: true)
                }
            case .ai, .open:
                continue
            }
        }
    }

    // MARK: Incoming

    private func handlePeerEvent(_ event: TransportPeerEvent) {
        switch event {
        case .receivedInvitation(let peerId, _, _):
            // Friends mode: auto-accept the MPC invitation. Actual seating
            // gate happens once we receive a `joinRequest` payload.
            try? transport.accept(peerId: peerId)
        case .peerDisconnected(let peerId, _):
            handlePeerDisconnect(peerId: peerId)
        case .peerConnected, .peerConnecting, .foundPeer, .lostPeer, .transportError:
            break
        }
    }

    private func handleIncoming(data: Data, fromPeer peerId: String) {
        let decoded: DecodedPokerMessage
        do { decoded = try PokerWireCodec.decode(data) }
        catch {
            #if DEBUG
            print("Host: decode failure from \(peerId): \(error)")
            #endif
            return
        }

        switch decoded.type {
        case .joinRequest:
            handleJoinRequest(decoded: decoded, fromPeer: peerId)
        case .playerActionIntent:
            handleActionIntent(decoded: decoded, fromPeer: peerId)
        case .reconnectRequest:
            handleReconnectRequest(decoded: decoded, fromPeer: peerId)
        case .ping:
            handlePing(decoded: decoded, fromPeer: peerId)
        default:
            // Other types are host-originated; ignore.
            break
        }
    }

    private func handleJoinRequest(decoded: DecodedPokerMessage, fromPeer peerId: String) {
        guard let payload: JoinRequestPayload = try? decoded.decodePayload() else { return }

        if let token = payload.reconnectToken,
           let seatId = seatRegistry.seat(forToken: token) {
            seatRegistry.markReconnected(seatId: seatId, peerId: peerId)
            seatRegistry.seats[seatId].displayName = payload.displayName
            cancelReconnectTimer(seatId: seatId)
            let accepted = JoinAcceptedPayload(
                seatId: seatId,
                displayName: payload.displayName,
                reconnectToken: token,
                lobby: lobbySnapshot()
            )
            send(type: .joinAccepted, payload: accepted, to: [peerId])
            broadcastLobbySnapshot()
            try? transport.updateAdvert(currentAdvert())
            if hasStarted { resyncSeat(seatId: seatId) }
            return
        }

        if hasStarted {
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Table already in progress."),
                 to: [peerId])
            return
        }
        guard let seatId = seatRegistry.assign(remotePeerId: peerId,
                                               displayName: payload.displayName) else {
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Table is full."),
                 to: [peerId])
            return
        }

        let token = seatRegistry.record(forSeat: seatId)?.reconnectToken ?? UUID().uuidString
        let accepted = JoinAcceptedPayload(
            seatId: seatId,
            displayName: payload.displayName,
            reconnectToken: token,
            lobby: lobbySnapshot()
        )
        send(type: .joinAccepted, payload: accepted, to: [peerId])
        broadcastLobbySnapshot()
        try? transport.updateAdvert(currentAdvert())
    }

    private func handleActionIntent(decoded: DecodedPokerMessage, fromPeer peerId: String) {
        guard let gm = gameManager,
              let payload: PlayerActionIntentPayload = try? decoded.decodePayload() else { return }

        guard let seat = seatRegistry.seat(forPeer: peerId), seat == payload.seatId else {
            sendActionRejected(seatId: payload.seatId, action: payload.action,
                               reason: "Seat mismatch.", to: peerId)
            return
        }
        guard let player = gm.players.first(where: { $0.id == payload.seatId }) else {
            sendActionRejected(seatId: payload.seatId, action: payload.action,
                               reason: "Unknown seat.", to: peerId)
            return
        }
        guard player.id == gm.currentPlayer?.id else {
            sendActionRejected(seatId: payload.seatId, action: payload.action,
                               reason: "Not your turn.", to: peerId)
            return
        }
        guard let action = SnapshotBuilder.decodeAction(name: payload.action,
                                                        raiseAmount: payload.raiseAmount) else {
            sendActionRejected(seatId: payload.seatId, action: payload.action,
                               reason: "Invalid action.", to: peerId)
            return
        }

        let valid = gm.getValidActions(for: player)
        guard SnapshotBuilder.actionsMatch(action, anyOf: valid) else {
            sendActionRejected(seatId: payload.seatId, action: payload.action,
                               reason: "Action not currently legal.", to: peerId)
            return
        }

        sequence &+= 1
        send(type: .actionAccepted, payload: ActionAcceptedPayload(
            seatId: payload.seatId,
            action: payload.action,
            raiseAmount: payload.raiseAmount,
            appliedSequence: sequence
        ), to: [peerId])

        gm.processPlayerAction(action, for: player)
    }

    private func sendActionRejected(seatId: Int, action: String, reason: String, to peerId: String) {
        send(type: .actionRejected,
             payload: ActionRejectedPayload(seatId: seatId, attemptedAction: action, reason: reason),
             to: [peerId])
    }

    private func handleReconnectRequest(decoded: DecodedPokerMessage, fromPeer peerId: String) {
        guard let payload: ReconnectRequestPayload = try? decoded.decodePayload() else { return }
        if let seatId = seatRegistry.seat(forToken: payload.reconnectToken) {
            seatRegistry.markReconnected(seatId: seatId, peerId: peerId)
            seatRegistry.seats[seatId].displayName = payload.displayName
            cancelReconnectTimer(seatId: seatId)
            let payloadOut = ReconnectAcceptedPayload(
                seatId: seatId,
                lobby: hasStarted ? nil : lobbySnapshot(),
                inGame: hasStarted
            )
            send(type: .reconnectAccepted, payload: payloadOut, to: [peerId])
            broadcastLobbySnapshot()
            if hasStarted {
                resyncSeat(seatId: seatId)
                broadcast(type: .resume, payload: ResumePayload(reason: "Player reconnected."))
                broadcastSnapshot()
            }
        } else {
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Reconnect token not recognized."),
                 to: [peerId])
        }
    }

    private func handlePing(decoded: DecodedPokerMessage, fromPeer peerId: String) {
        guard let p: PingPayload = try? decoded.decodePayload() else { return }
        send(type: .pong, payload: PongPayload(nonce: p.nonce, sentAtMs: p.sentAtMs), to: [peerId])
    }

    private func resyncSeat(seatId: Int) {
        guard let gm = gameManager,
              let rec = seatRegistry.record(forSeat: seatId),
              let peerId = rec.peerId,
              let player = gm.players.first(where: { $0.id == seatId }) else { return }

        if !player.holeCards.isEmpty {
            let payload = PrivateCardsPayload(seatId: seatId, handNumber: handNumber,
                                              cards: player.holeCards.map { $0.dto })
            send(type: .privateCards, payload: payload, to: [peerId], withHandSequence: true)
        }

        let snapshot = SnapshotBuilder.build(
            gameManager: gm,
            handNumber: handNumber,
            playerKindBySeat: seatRegistry.playerKindBySeatId(),
            disconnectedSeats: seatRegistry.disconnectedSeats(),
            aiTakenOverSeats: seatRegistry.aiTakenOverSeats()
        )
        send(type: .tableSnapshot, payload: snapshot, to: [peerId], withHandSequence: true)
    }

    // MARK: Disconnect handling

    private func handlePeerDisconnect(peerId: String) {
        guard let seatId = seatRegistry.seat(forPeer: peerId) else { return }
        seatRegistry.markDisconnected(seatId: seatId)
        broadcastLobbySnapshot()

        if !hasStarted {
            // Pre-game: open the seat back up.
            seatRegistry.seats[seatId] = SeatRegistry.SeatRecord(
                seatId: seatId, kind: .open,
                displayName: "Seat \(seatId + 1)",
                peerId: nil, reconnectToken: nil,
                isReady: false, isDisconnected: false, aiTookOver: false
            )
            broadcastLobbySnapshot()
            try? transport.updateAdvert(currentAdvert())
            return
        }

        // No-pause path: disconnected player is already all-in, the hand
        // can finish without them needing to act.
        if let gm = gameManager,
           let player = gm.players.first(where: { $0.id == seatId }),
           player.isAllIn {
            broadcastSnapshot()
            startReconnectTimer(seatId: seatId)
            return
        }

        let isTheirTurn = (gameManager?.currentPlayer?.id == seatId)
        broadcastSnapshot(isPaused: isTheirTurn, pausedForSeatId: isTheirTurn ? seatId : nil)
        if isTheirTurn {
            broadcast(type: .pause,
                      payload: PausePayload(reason: "Waiting for player to reconnect.",
                                            pausedForSeatId: seatId))
        }
        startReconnectTimer(seatId: seatId)
    }

    private func startReconnectTimer(seatId: Int) {
        cancelReconnectTimer(seatId: seatId)
        let timer = Timer.scheduledTimer(withTimeInterval: PokerProtocol.reconnectGraceSeconds,
                                         repeats: false) { [weak self] _ in
            self?.swapDisconnectedSeatToAI(seatId: seatId)
        }
        reconnectTimers[seatId] = timer
    }

    private func cancelReconnectTimer(seatId: Int) {
        reconnectTimers[seatId]?.invalidate()
        reconnectTimers[seatId] = nil
    }

    private func swapDisconnectedSeatToAI(seatId: Int) {
        guard let rec = seatRegistry.record(forSeat: seatId), rec.isDisconnected else { return }
        let personality = AIPersonality.allCases[seatId % AIPersonality.allCases.count]
        let aiName = "\(personality.avatar) \(personality.name)"
        seatRegistry.swapToAI(seatId: seatId, displayName: aiName)

        if let gm = gameManager,
           let idx = gm.players.firstIndex(where: { $0.id == seatId }) {
            let old = gm.players[idx]
            let replacement = Player(id: old.id, name: aiName,
                                     type: .ai(personality: personality),
                                     chips: old.chips)
            replacement.holeCards = old.holeCards
            replacement.currentBet = old.currentBet
            replacement.totalInvested = old.totalInvested
            replacement.hasActed = old.hasActed
            replacement.isFolded = old.isFolded
            replacement.isAllIn = old.isAllIn
            replacement.isActive = old.isActive
            replacement.lastAction = old.lastAction
            gm.players[idx] = replacement
        }

        broadcast(type: .resume, payload: ResumePayload(reason: "AI is taking over the seat."))
        broadcastSnapshot()

        if let gm = gameManager, gm.currentPlayer?.id == seatId {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.gameManager?.processAITurn()
            }
        }
    }

    // MARK: Public — local input from host's own UI

    func submitHostAction(_ action: PlayerAction) {
        guard let gm = gameManager,
              let current = gm.currentPlayer,
              current.id == hostSeatId else { return }
        gm.processPlayerAction(action, for: current)
    }

    func endTable(reason: String) {
        broadcast(type: .hostEndingTable, payload: HostEndingTablePayload(reason: reason))
        transport.disconnect()
        observer?.host(self, didFinishWithReason: reason)
    }

    // MARK: Round result coalescer

    @objc private func handleShowWinnerAlert(_ note: Notification) {
        guard let info = note.userInfo,
              let player = info["player"] as? Player,
              let amount = info["amount"] as? Int,
              let desc = info["handDescription"] as? String,
              let gm = gameManager,
              gm.players.contains(where: { $0.id == player.id }) else {
            return
        }
        pendingWinners.append((player, amount, desc))
        pendingWinnersFlush?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flushPendingRoundResult() }
        pendingWinnersFlush = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func flushPendingRoundResult() {
        guard let gm = gameManager else { return }
        let entries = pendingWinners
        pendingWinners.removeAll()
        pendingWinnersFlush = nil
        guard !entries.isEmpty else { return }

        let revealed: [SeatedHolePayload] = gm.players.enumerated().compactMap { idx, p in
            guard !p.isFolded, p.holeCards.count == 2 else { return nil }
            return SeatedHolePayload(seatId: idx, cards: p.holeCards.map { $0.dto })
        }
        let payload = RoundResultPayload(
            handNumber: handNumber,
            totalPot: entries.reduce(0) { $0 + $1.amount },
            winners: entries.map { info in
                RoundWinnerPayload(
                    seatId: gm.players.firstIndex(where: { $0.id == info.player.id }) ?? info.player.id,
                    displayName: info.player.name,
                    amount: info.amount,
                    handDescription: info.handDescription
                )
            },
            communityCards: gm.communityCards.map { $0.dto },
            revealedHoleCards: revealed
        )

        broadcast(type: .roundResult, payload: payload)
        observer?.host(self, didCompleteRound: payload)

        // Auto-advance to the next hand after the banner displays.
        let displayDuration: TimeInterval = entries.count > 1 ? 3.5 : 2.8
        let postBannerGap: TimeInterval = 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration + postBannerGap) { [weak self] in
            self?.beginNextHand()
        }
    }

    // MARK: Send helpers

    private func broadcast<P: Codable>(type: PokerMessageType, payload: P,
                                       withHandSequence: Bool = false) {
        let envelope = PokerMessage(
            sessionId: sessionId,
            tableId: tableId,
            handNumber: withHandSequence ? handNumber : nil,
            sequence: withHandSequence ? nextSequence() : nil,
            senderPeerId: transport.localPeerId,
            type: type,
            payload: payload
        )
        do {
            let data = try PokerWireCodec.encode(envelope)
            try transport.broadcast(data)
        } catch {
            #if DEBUG
            print("Host broadcast \(type) failed: \(error)")
            #endif
        }
    }

    private func send<P: Codable>(type: PokerMessageType, payload: P,
                                  to peerIds: [String],
                                  withHandSequence: Bool = false) {
        let envelope = PokerMessage(
            sessionId: sessionId,
            tableId: tableId,
            handNumber: withHandSequence ? handNumber : nil,
            sequence: withHandSequence ? nextSequence() : nil,
            senderPeerId: transport.localPeerId,
            type: type,
            payload: payload
        )
        do {
            let data = try PokerWireCodec.encode(envelope)
            try transport.send(data, to: peerIds)
        } catch {
            #if DEBUG
            print("Host send \(type) failed: \(error)")
            #endif
        }
    }

    private func nextSequence() -> UInt64 {
        sequence &+= 1
        return sequence
    }

    private func lobbySnapshot() -> LobbySnapshotPayload {
        LobbySnapshotPayload(
            tableId: tableId,
            sessionId: sessionId,
            smallBlind: config.smallBlind,
            bigBlind: config.bigBlind,
            startingChips: config.startingChips,
            totalSeats: config.totalSeats,
            aiFillEnabled: config.aiFillEnabled,
            seats: seatRegistry.lobbySeatPayloads(),
            hostPeerId: transport.localPeerId
        )
    }

    private func broadcastLobbySnapshot() {
        let snap = lobbySnapshot()
        broadcast(type: .seatUpdate, payload: SeatUpdatePayload(seats: snap.seats))
        observer?.host(self, didUpdateLobby: snap)
    }

    private func broadcastLobbySettings() {
        broadcast(type: .lobbySettingsChanged, payload: LobbySettingsChangedPayload(
            smallBlind: config.smallBlind,
            bigBlind: config.bigBlind,
            startingChips: config.startingChips,
            totalSeats: config.totalSeats,
            aiFillEnabled: config.aiFillEnabled
        ))
    }
}

// MARK: - Action matching helper

extension SnapshotBuilder {
    /// `getValidActions(for:)` returns canonical entries (raise carries
    /// only the *minimum* raise amount). For intent validation we match
    /// kind-only — the actual chip amount is clamped inside
    /// `executeAction → player.bet(amount:)`.
    static func actionsMatch(_ proposed: PlayerAction, anyOf valid: [PlayerAction]) -> Bool {
        let kind: String
        switch proposed {
        case .fold: kind = "fold"
        case .check: kind = "check"
        case .call: kind = "call"
        case .raise: kind = "raise"
        case .allIn: kind = "allIn"
        }
        return valid.contains { existing in
            switch (existing, kind) {
            case (.fold, "fold"), (.check, "check"), (.call, "call"),
                 (.raise, "raise"), (.allIn, "allIn"):
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - GameManagerDelegate

extension PokerHostService: GameManagerDelegate {
    func gameDidStart() { broadcastSnapshot() }
    func gamePhaseDidChange(_ phase: GamePhase) { broadcastSnapshot() }
    func playerDidAct(_ player: Player, action: PlayerAction) { broadcastSnapshot() }
    func playerDidWin(_ player: Player, amount: Int, handDescription: String) { broadcastSnapshot() }
    func gameDidEnd() {
        guard let gm = gameManager else { return }
        let revealedSeats: Set<Int> = Set(
            gm.players.enumerated().compactMap { idx, p in
                p.isFolded ? nil : idx
            }
        )
        broadcastSnapshot(revealedSeats: revealedSeats)
    }
    func cardsDealt() { sendPrivateCardsToAllSeats(); broadcastSnapshot() }
    func potDidUpdate(_ amount: Int) { broadcastSnapshot() }
    func currentPlayerChanged(_ player: Player) { broadcastSnapshot() }
}
