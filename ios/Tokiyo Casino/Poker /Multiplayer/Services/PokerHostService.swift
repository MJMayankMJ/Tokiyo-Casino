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

/// Pending mid-game join request that needs the host's decision to
/// kick an AI bot before the new player can be seated. Surfaced to the
/// host VC via `host(_:didRequestAIKickFor:)`.
struct PendingHostJoin {
    let peerId: String
    let displayName: String
    /// AI seats the host can choose to remove. Same set the prompt UI
    /// renders as "Kick 🦈 Shark" / "Kick 🐠 Fish" / etc.
    let kickableSeats: [(seatId: Int, displayName: String)]
    /// How many rejections the host has used this session. After two
    /// rejections the host will not be prompted again for this game —
    /// further mid-game joins are auto-rejected with "table full".
    let rejectionsUsed: Int
}

/// Reason the host service has paused the action between hands.
enum HostPauseReason {
    case loneHumanNoAI       // host alone, no AI bots — prompt with Wait/Leave
    case everyoneLeft        // even host has nobody and no AI — same prompt
}

/// View-controller-facing surface for the host.
protocol PokerHostServiceObserver: AnyObject {
    func host(_ service: PokerHostService, didUpdateLobby snapshot: LobbySnapshotPayload)
    func host(_ service: PokerHostService, didUpdateSnapshot snapshot: TableSnapshotPayload)
    func host(_ service: PokerHostService, didReceivePrivateCards payload: PrivateCardsPayload)
    func host(_ service: PokerHostService, didCompleteRound payload: RoundResultPayload)
    func host(_ service: PokerHostService, didEndSession payload: SessionResultPayload)
    func host(_ service: PokerHostService, didRequestAction payload: ActionRequestPayload)
    /// A new pending join is now at the head of the queue and the
    /// banner should display it. Fired both for the very first
    /// pending join and any time the head changes.
    func host(_ service: PokerHostService, didRequestAIKickFor join: PendingHostJoin)
    /// The pending-join queue is now empty (host accepted/rejected
    /// the last one, or it expired/was disconnected). The banner
    /// should hide.
    func hostDidClearPendingJoins(_ service: PokerHostService)
    /// Game has paused between hands because the host is alone at the
    /// table with no AI bots — the host VC should show the big "Wait /
    /// Leave" prompt.
    func host(_ service: PokerHostService, didPauseForReason reason: HostPauseReason)
    /// Pause cleared (someone rejoined). The host VC can dismiss the
    /// lone-human prompt; the next hand will be dealt automatically.
    func hostDidResume(_ service: PokerHostService)
    func host(_ service: PokerHostService, didFinishWithReason reason: String)
}

extension PokerHostServiceObserver {
    // Default no-op for compatibility with the lobby's empty observer
    // implementation — only NetworkGameViewController needs to handle
    // these.
    func host(_ service: PokerHostService, didRequestAIKickFor join: PendingHostJoin) {}
    func hostDidClearPendingJoins(_ service: PokerHostService) {}
    func host(_ service: PokerHostService, didPauseForReason reason: HostPauseReason) {}
    func hostDidResume(_ service: PokerHostService) {}
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

    /// Mid-game joins waiting for the host to either kick an AI or
    /// reject. Processed FIFO — the host VC is only prompted for the
    /// head of the queue, and the next prompt fires after they
    /// accept/reject the current one.
    private var pendingJoins: [PendingHostJoin] = []
    /// Mapping of peerId → JoinRequestPayload for the head pending join,
    /// retained so we can finalise the seating once the host decides.
    private var pendingJoinPayloads: [String: JoinRequestPayload] = [:]
    /// Hard cap of 2 (PRD: "this prompt should happen only twice; if
    /// the table owner rejects twice, don't ask in that game").
    private var aiKickRejectionsUsed: Int = 0
    /// True while the table is paused between hands waiting for a
    /// human to rejoin. The next hand only gets dealt once this clears.
    private var isPausedBetweenHands: Bool = false

    /// Per-seat timers that recycle a long-away remote seat back to
    /// `.open` so new joiners can claim it. Started when a remote
    /// seat is marked disconnected; cancelled when the original
    /// player reconnects.
    private var staleSeatTimers: [Int: Timer] = [:]
    /// Per-pending-join expiry timer (60s, see issue 4).
    private var pendingJoinExpiryTimers: [String: Timer] = [:]

    /// Coalescing buffer for per-side-pot winner notifications.
    private var pendingWinners: [(player: Player, amount: Int, handDescription: String)] = []
    private var pendingWinnersFlush: DispatchWorkItem?

    /// Latest broadcast snapshot. Cached so a freshly-attached observer
    /// (e.g. the `NetworkGameViewController` swapping in after the
    /// `HostLobbyViewController`) can replay the current table state
    /// instead of waiting for the next action to fire one. Fixes the
    /// "cards don't appear until your turn" race where the initial
    /// `cardsDealt` callback fired while the lobby was still the
    /// observer.
    private var lastSnapshot: TableSnapshotPayload?
    /// Latest lobby snapshot, for the same replay reason.
    private var lastLobbySnapshot: LobbySnapshotPayload?
    /// Latest pending action request for the host's local seat (nil if
    /// it's not the host's turn). Replayed on observer attach.
    private var lastHostActionRequest: ActionRequestPayload?
    /// Most recently dealt hole cards for the host's own seat, by hand.
    private var hostPrivateCards: PrivateCardsPayload?

    weak var observer: PokerHostServiceObserver? {
        didSet {
            // Only replay when a real observer is attaching; ignore
            // detachments (nil) and self-reassignments.
            guard let newObs = observer else { return }
            if let old = oldValue, old === newObs { return }
            replayCurrentState(to: newObs)
        }
    }

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

        // Pause check — "friends mode" rule: if the host is alone at
        // the table with no AI bots, hold here for the lone-human
        // prompt instead of auto-dealing. The host can Wait (we stay
        // paused until someone rejoins) or Leave (they tear the table
        // down).
        let connectedHumanSeats = seatRegistry.seats.filter {
            ($0.kind == .host || $0.kind == .remote) && !$0.isDisconnected
        }.count
        let aiSeatCount = seatRegistry.seats.filter { $0.kind == .ai }.count
        if connectedHumanSeats <= 1 && aiSeatCount == 0 {
            isPausedBetweenHands = true
            let reason: HostPauseReason =
                (connectedHumanSeats == 0) ? .everyoneLeft : .loneHumanNoAI
            broadcast(type: .pause, payload: PausePayload(
                reason: "Waiting for someone to join.",
                pausedForSeatId: nil
            ))
            observer?.host(self, didPauseForReason: reason)
            return
        }
        isPausedBetweenHands = false

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
            awaySeats: seatRegistry.awaySeats(),
            revealedSeats: revealedSeats,
            isPaused: isPaused,
            pausedForSeatId: pausedForSeatId
        )
        lastSnapshot = snapshot
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
                lastHostActionRequest = req
                observer?.host(self, didRequestAction: req)
            case .remote:
                lastHostActionRequest = nil
                if let peer = seatRec.peerId {
                    send(type: .actionRequest, payload: req, to: [peer], withHandSequence: true)
                }
            case .ai, .open:
                lastHostActionRequest = nil
            }
        } else {
            lastHostActionRequest = nil
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
                hostPrivateCards = payload
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

    /// Resync a freshly-attached observer with the most recent state.
    /// Order matters: lobby → snapshot → private cards → action
    /// request, so the UI builds up correctly even if it joined mid-hand.
    private func replayCurrentState(to observer: PokerHostServiceObserver) {
        if let lobby = lastLobbySnapshot {
            observer.host(self, didUpdateLobby: lobby)
        }
        if let snap = lastSnapshot {
            observer.host(self, didUpdateSnapshot: snap)
        }
        if let cards = hostPrivateCards, cards.handNumber == handNumber {
            observer.host(self, didReceivePrivateCards: cards)
        }
        if let req = lastHostActionRequest {
            observer.host(self, didRequestAction: req)
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
            // Drop any kick-AI prompt that was queued for a peer who
            // disconnected before the host decided — otherwise the
            // host gets prompted about a ghost.
            dropPendingJoin(peerId: peerId)
            handlePeerDisconnect(peerId: peerId)
        case .peerConnected, .peerConnecting, .foundPeer, .lostPeer, .transportError:
            break
        }
    }

    /// Remove a pending kick-AI request keyed by peer id and tear down
    /// its 60s expiry timer. If the dropped entry was the one
    /// currently showing in the host's banner, advance to the next
    /// queued request (if any).
    private func dropPendingJoin(peerId: String) {
        guard pendingJoins.contains(where: { $0.peerId == peerId }) else { return }
        let wasHead = pendingJoins.first?.peerId == peerId
        pendingJoins.removeAll { $0.peerId == peerId }
        pendingJoinPayloads.removeValue(forKey: peerId)
        pendingJoinExpiryTimers[peerId]?.invalidate()
        pendingJoinExpiryTimers[peerId] = nil
        if wasHead {
            promptNextPendingJoin()
        }
    }

    /// 60s ceiling on a pending kick-AI request. If the host hasn't
    /// decided within that window the request expires (joiner is
    /// rejected; rejection counter is NOT incremented because the
    /// host didn't actively refuse).
    private func startPendingJoinExpiry(peerId: String) {
        pendingJoinExpiryTimers[peerId]?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let self else { return }
            guard self.pendingJoins.contains(where: { $0.peerId == peerId }) else { return }
            let wasHead = self.pendingJoins.first?.peerId == peerId
            self.pendingJoins.removeAll { $0.peerId == peerId }
            self.pendingJoinPayloads.removeValue(forKey: peerId)
            self.pendingJoinExpiryTimers[peerId] = nil
            self.send(type: .joinRejected,
                      payload: JoinRejectedPayload(reason: "Join request expired."),
                      to: [peerId])
            if wasHead { self.promptNextPendingJoin() }
        }
        pendingJoinExpiryTimers[peerId] = timer
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
        case .peerLeft:
            // peerLeft is reserved on the wire but no longer emitted.
            // Explicit and transient departures both flow through the
            // transport-level peerDisconnected event for a single,
            // dependable code path.
            break
        default:
            // Other types are host-originated; ignore.
            break
        }
    }

    /// New JoinRequest handler. Supports both pre-game lobby joins and
    /// mid-game joins. Mid-game routing:
    ///   1. Reconnect token matches an existing seat → restore.
    ///   2. There's an open seat → seat them immediately (away for the
    ///      current hand, dealt in next hand).
    ///   3. All seats are taken but some are AI → queue a prompt for
    ///      the host to optionally kick one AI. The host gets at most
    ///      two rejections per session.
    ///   4. No AI to kick → table full, reject.
    private func handleJoinRequest(decoded: DecodedPokerMessage, fromPeer peerId: String) {
        guard let payload: JoinRequestPayload = try? decoded.decodePayload() else { return }

        // Reconnect path — also used as "rejoin after explicit leave".
        if let token = payload.reconnectToken,
           let seatId = seatRegistry.seat(forToken: token) {
            seatRegistry.markReconnected(seatId: seatId, peerId: peerId)
            seatRegistry.seats[seatId].displayName = payload.displayName
            cancelStaleSeatReaper(seatId: seatId)
            // Clear the away flag on the GameManager player as well so
            // they're dealt in on the next hand.
            if let gm = gameManager,
               let idx = gm.players.firstIndex(where: { $0.id == seatId }) {
                gm.players[idx].isAway = false
            }
            let accepted = JoinAcceptedPayload(
                seatId: seatId,
                displayName: payload.displayName,
                reconnectToken: token,
                lobby: lobbySnapshot()
            )
            send(type: .joinAccepted, payload: accepted, to: [peerId])
            broadcastLobbySnapshot()
            try? transport.updateAdvert(currentAdvert())
            if hasStarted {
                resyncSeat(seatId: seatId)
                // If we were paused for lack of humans, the rejoin
                // unblocks the next hand. Defer the deal by one
                // runloop tick so the joinAccepted + snapshot resync
                // messages we just queued land on the rejoiner's UI
                // before the new-hand snapshot does.
                if isPausedBetweenHands {
                    isPausedBetweenHands = false
                    broadcast(type: .resume,
                              payload: ResumePayload(reason: "Player rejoined."))
                    observer?.hostDidResume(self)
                    DispatchQueue.main.async { [weak self] in
                        self?.beginNextHand()
                    }
                }
            }
            return
        }

        // Pre-game: take any open seat.
        if !hasStarted {
            guard let seatId = seatRegistry.assign(remotePeerId: peerId,
                                                   displayName: payload.displayName) else {
                send(type: .joinRejected,
                     payload: JoinRejectedPayload(reason: "Table is full."),
                     to: [peerId])
                return
            }
            let token = seatRegistry.record(forSeat: seatId)?.reconnectToken ?? UUID().uuidString
            send(type: .joinAccepted, payload: JoinAcceptedPayload(
                seatId: seatId,
                displayName: payload.displayName,
                reconnectToken: token,
                lobby: lobbySnapshot()
            ), to: [peerId])
            broadcastLobbySnapshot()
            try? transport.updateAdvert(currentAdvert())
            return
        }

        // Mid-game routing.
        if let seatId = seatRegistry.firstOpenSeat() {
            // Path 2: free seat. Seat them as away for the current hand.
            seatMidGameJoiner(peerId: peerId,
                              displayName: payload.displayName,
                              intoSeatId: seatId,
                              kickedAI: false)
            return
        }
        let kickable = seatRegistry.aiSeats()
        guard !kickable.isEmpty else {
            // Path 4: no AI to kick — really full.
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Table is full."),
                 to: [peerId])
            return
        }
        if aiKickRejectionsUsed >= 2 {
            // Path 3, gated: host already rejected twice this session.
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(
                     reason: "Table is full and the host isn't taking new players."),
                 to: [peerId])
            return
        }

        // Queue for the host to decide. Drop earlier pending joins
        // from the same peer to avoid duplicates.
        pendingJoins.removeAll { $0.peerId == peerId }
        pendingJoinPayloads[peerId] = payload
        let pending = PendingHostJoin(
            peerId: peerId,
            displayName: payload.displayName,
            kickableSeats: kickable.map { (seatId: $0.seatId, displayName: $0.displayName) },
            rejectionsUsed: aiKickRejectionsUsed
        )
        pendingJoins.append(pending)
        startPendingJoinExpiry(peerId: peerId)
        if pendingJoins.count == 1 {
            observer?.host(self, didRequestAIKickFor: pending)
        }
    }

    // MARK: Mid-game seating helpers

    /// Place a joiner at an existing seat.
    ///
    /// **Chip-stack policy** (explicit product decision):
    ///   - `kickedAI == true`  → joiner inherits the kicked AI's
    ///     current chip count. Total chips in play stay constant, so
    ///     the host's mid-game balance is preserved.
    ///   - `kickedAI == false` (taking an open seat) → joiner gets a
    ///     fresh `config.startingChips` buy-in. This MATCHES real-
    ///     table behaviour (new player buys in at the table minimum),
    ///     but it does inflate total chips in play by one buy-in per
    ///     mid-joiner. This is intentional, not a leak.
    private func seatMidGameJoiner(peerId: String,
                                   displayName: String,
                                   intoSeatId seatId: Int,
                                   kickedAI: Bool) {
        let token = UUID().uuidString
        // Update the seat registry record in place.
        var rec = seatRegistry.seats[seatId]
        rec.kind = .remote
        rec.peerId = peerId
        rec.displayName = displayName
        rec.reconnectToken = token
        rec.isReady = false
        rec.isDisconnected = false
        rec.aiTookOver = false
        seatRegistry.seats[seatId] = rec

        // Mirror onto the GameManager.
        if let gm = gameManager {
            if let idx = gm.players.firstIndex(where: { $0.id == seatId }) {
                let old = gm.players[idx]
                let startingChips = kickedAI ? old.chips : config.startingChips
                let replacement = Player(id: seatId, name: displayName,
                                         type: .human, chips: startingChips)
                // Skip the current hand — mid-joiners wait for next deal.
                replacement.isAway = true
                replacement.isFolded = true
                replacement.isActive = false
                gm.players[idx] = replacement
            } else {
                // Snapshot/gameManager out of sync (shouldn't happen) — append.
                let p = Player(id: seatId, name: displayName, type: .human,
                               chips: config.startingChips)
                p.isAway = true; p.isFolded = true; p.isActive = false
                gm.players.append(p)
            }
        }

        // Reply to the joining peer.
        send(type: .joinAccepted, payload: JoinAcceptedPayload(
            seatId: seatId,
            displayName: displayName,
            reconnectToken: token,
            lobby: lobbySnapshot()
        ), to: [peerId])

        broadcastLobbySnapshot()
        broadcastSnapshot()
        try? transport.updateAdvert(currentAdvert())
    }

    /// Host decision: accept the head pending join and kick the named
    /// AI seat to make room.
    func acceptPendingJoin(kickSeatId: Int) {
        guard let pending = pendingJoins.first else { return }
        pendingJoins.removeFirst()
        pendingJoinExpiryTimers[pending.peerId]?.invalidate()
        pendingJoinExpiryTimers[pending.peerId] = nil
        guard let _ = pendingJoinPayloads.removeValue(forKey: pending.peerId) else { return }

        // Make sure the chosen seat is actually still an AI.
        guard seatRegistry.record(forSeat: kickSeatId)?.kind == .ai else {
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Seat no longer available."),
                 to: [pending.peerId])
            promptNextPendingJoin()
            return
        }
        seatMidGameJoiner(peerId: pending.peerId,
                          displayName: pending.displayName,
                          intoSeatId: kickSeatId,
                          kickedAI: true)
        promptNextPendingJoin()
    }

    /// Host decision: reject the head pending join. Increments the
    /// rejection counter; after two rejections per session, future
    /// mid-game joins with no open seat auto-reject without prompting.
    func rejectPendingJoin() {
        guard let pending = pendingJoins.first else { return }
        pendingJoins.removeFirst()
        pendingJoinExpiryTimers[pending.peerId]?.invalidate()
        pendingJoinExpiryTimers[pending.peerId] = nil
        pendingJoinPayloads.removeValue(forKey: pending.peerId)
        aiKickRejectionsUsed += 1
        send(type: .joinRejected,
             payload: JoinRejectedPayload(
                 reason: "The host can't take new players right now."),
             to: [pending.peerId])
        promptNextPendingJoin()
    }

    private func promptNextPendingJoin() {
        guard let next = pendingJoins.first else {
            // Queue drained — let the host VC drop its banner.
            observer?.hostDidClearPendingJoins(self)
            return
        }
        // Refresh kickable seats — they may have changed if the host
        // just accepted/kicked one.
        let kickable = seatRegistry.aiSeats()
        if kickable.isEmpty {
            // Nothing left to kick — auto-reject the rest.
            pendingJoins.removeFirst()
            pendingJoinExpiryTimers[next.peerId]?.invalidate()
            pendingJoinExpiryTimers[next.peerId] = nil
            pendingJoinPayloads.removeValue(forKey: next.peerId)
            send(type: .joinRejected,
                 payload: JoinRejectedPayload(reason: "Table is full."),
                 to: [next.peerId])
            promptNextPendingJoin()
            return
        }
        let refreshed = PendingHostJoin(
            peerId: next.peerId,
            displayName: next.displayName,
            kickableSeats: kickable.map { (seatId: $0.seatId, displayName: $0.displayName) },
            rejectionsUsed: aiKickRejectionsUsed
        )
        pendingJoins[0] = refreshed
        observer?.host(self, didRequestAIKickFor: refreshed)
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
            cancelStaleSeatReaper(seatId: seatId)
            // Clear the GameManager away flag so they're dealt in on
            // the next hand.
            if let gm = gameManager,
               let idx = gm.players.firstIndex(where: { $0.id == seatId }) {
                gm.players[idx].isAway = false
            }
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
                if isPausedBetweenHands {
                    isPausedBetweenHands = false
                    observer?.hostDidResume(self)
                    // Defer so the rejoiner's UI processes the
                    // reconnectAccepted + resync snapshot before the
                    // brand-new hand starts streaming snapshots.
                    DispatchQueue.main.async { [weak self] in
                        self?.beginNextHand()
                    }
                }
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
            awaySeats: seatRegistry.awaySeats()
        )
        send(type: .tableSnapshot, payload: snapshot, to: [peerId], withHandSequence: true)
    }

    // MARK: Disconnect handling
    //
    // Friends-mode rule: a human seat is never replaced by AI. When a
    // human disconnects we mark them away (folded for the current
    // hand, dealt back in only when they rejoin via reconnect token).
    // Mid-hand we advance the action if it was their turn; between
    // hands we may pause until they return.

    private func handlePeerDisconnect(peerId: String) {
        guard let seatId = seatRegistry.seat(forPeer: peerId) else { return }
        seatRegistry.markDisconnected(seatId: seatId)

        if !hasStarted {
            // Pre-game: free the seat up so someone else can take it.
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
        markSeatAwayMidGame(seatId: seatId)
    }

    /// Mark a remote human's seat as away for the current hand and
    /// advance the action if they were the current actor. The seat is
    /// preserved (reconnect token intact) so the same peer can pick
    /// up where they left off. After `staleAwaySeatSeconds`, an
    /// orphan reaper opens the seat up for new joiners.
    private func markSeatAwayMidGame(seatId: Int) {
        guard let gm = gameManager,
              let idx = gm.players.firstIndex(where: { $0.id == seatId }) else {
            broadcastLobbySnapshot()
            return
        }
        let p = gm.players[idx]
        p.isAway = true
        p.isFolded = true
        p.isActive = false
        // If they were the current player, force the turn forward —
        // otherwise GameManager would sit waiting for input forever.
        let wasCurrent = (gm.currentPlayer?.id == seatId)
        broadcastLobbySnapshot()
        broadcastSnapshot()
        scheduleStaleSeatReaper(seatId: seatId)
        if wasCurrent {
            if gm.shouldEndBettingRound() {
                gm.endBettingRound()
            } else {
                gm.moveToNextPlayer(after: p)
                gm.processNextTurn()
            }
        }
    }

    /// Start (or restart) the orphan-seat timer for a remote seat.
    /// Fires after `staleAwaySeatSeconds`; if the seat is still away
    /// at that point, it's recycled to `.open` so the next mid-game
    /// joiner can claim it directly without needing a kick-AI prompt.
    private func scheduleStaleSeatReaper(seatId: Int) {
        cancelStaleSeatReaper(seatId: seatId)
        let timer = Timer.scheduledTimer(
            withTimeInterval: PokerProtocol.staleAwaySeatSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.recycleStaleSeat(seatId: seatId)
        }
        staleSeatTimers[seatId] = timer
    }

    private func cancelStaleSeatReaper(seatId: Int) {
        staleSeatTimers[seatId]?.invalidate()
        staleSeatTimers[seatId] = nil
    }

    /// Reaper fired: if the seat is still away (player never came
    /// back), open it up. The original reconnect token is invalidated
    /// — if the original player returns later they'll be onboarded as
    /// a fresh joiner.
    private func recycleStaleSeat(seatId: Int) {
        cancelStaleSeatReaper(seatId: seatId)
        guard let rec = seatRegistry.record(forSeat: seatId),
              rec.kind == .remote, rec.isDisconnected else { return }
        // Drop the seat back to .open. The GameManager player object
        // stays in place but is marked away+folded so it's skipped
        // until a new joiner replaces it via seatMidGameJoiner.
        seatRegistry.seats[seatId] = SeatRegistry.SeatRecord(
            seatId: seatId, kind: .open,
            displayName: "Seat \(seatId + 1)",
            peerId: nil, reconnectToken: nil,
            isReady: false, isDisconnected: false, aiTookOver: false
        )
        broadcastLobbySnapshot()
        broadcastSnapshot()
        try? transport.updateAdvert(currentAdvert())
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

    /// Counts how many human seats are currently connected (not away).
    /// Exposed so the host VC can decide whether to render the lone-
    /// human banner / prompt without redoing the same calc.
    var connectedHumanCount: Int {
        seatRegistry.seats.filter {
            ($0.kind == .host || $0.kind == .remote) && !$0.isDisconnected
        }.count
    }

    var aiSeatCount: Int {
        seatRegistry.seats.filter { $0.kind == .ai }.count
    }

    /// True while `beginNextHand` is holding for someone to rejoin.
    var isAwaitingRejoin: Bool { isPausedBetweenHands }

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
        lastLobbySnapshot = snap
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
