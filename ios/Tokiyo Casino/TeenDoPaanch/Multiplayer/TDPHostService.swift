//
//  TDPHostService.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The authority. Owns the only `TDPEngine`, seats players, drives the AI,
//  and publishes redacted views.
//
//  The same service backs all three modes — practice, pass-and-play and
//  friends — so the rules run through exactly one code path. `transport`
//  is simply nil when nobody is playing over the network.
//

import Foundation

protocol TDPHostServiceDelegate: AnyObject {
    /// A fresh view for a seat this device controls.
    func host(_ service: TDPHostService, didUpdateLocalView view: TDPClientView, seat: TDPSeat)
    /// Every local seat has its new view. On a shared device this is when
    /// to decide whose hand to show — deciding per seat mid-pass could flash
    /// the wrong player's cards.
    func hostDidPublish(_ service: TDPHostService)
    func host(_ service: TDPHostService, didUpdateLobby snapshot: TDPLobbySnapshot)
    func host(_ service: TDPHostService, didReject error: TDPError)
    func host(_ service: TDPHostService, didEndWith reason: String)
}

extension TDPHostServiceDelegate {
    func hostDidPublish(_ service: TDPHostService) {}
    func host(_ service: TDPHostService, didUpdateLobby snapshot: TDPLobbySnapshot) {}
    func host(_ service: TDPHostService, didReject error: TDPError) {}
    func host(_ service: TDPHostService, didEndWith reason: String) {}
}

final class TDPHostService {

    enum Mode {
        /// One local human, the rest AI.
        case practice
        /// Every seat is a local human passing the device.
        case passAndPlay(humanSeats: Int)
        /// Local human at seat 0, remote guests fill in, AI takes the rest.
        case friends
    }

    // MARK: Config

    weak var delegate: TDPHostServiceDelegate?

    let mode: Mode
    private(set) var engine: TDPEngine
    private(set) var localSeats: Set<TDPSeat>
    var difficulty: TDPAIDifficulty = .medium

    /// Pacing so the table is watchable rather than instant.
    var aiThinkTime: TimeInterval = 0.7
    var dealPace: TimeInterval = 0.35
    var trickHold: TimeInterval = 1.1
    /// Extra time on the table for a first cut, so its burst plays out
    /// before the trick is swept. (A steal celebrates as the trick is taken,
    /// so it needs none.) Zero when the delays above are zero (tests).
    var momentHold: TimeInterval = 1.6
    /// A beat after a person's first cut lands, before the next card.
    var momentBeat: TimeInterval = 0.6
    /// How long a debtor gets to arrange their cards for a person pulling.
    var arrangeWindow: TimeInterval = 10

    /// Wall-clock end of the open arranging window. Held as a deadline, not
    /// a scheduled timer, because `pump()` cancels pending work on every
    /// pass — a debtor dragging a card must not restart their own clock.
    private var arrangeDeadline: Date?
    private var arrangeKey: String?

    private let tableID: String
    private var transport: TDPTransport?
    /// seat → MPC peer id, for the seats a remote guest owns.
    private var remoteSeats: [TDPSeat: String] = [:]
    private var sequence: UInt64 = 0
    private var pendingWork: [DispatchWorkItem] = []
    private var started = false

    // MARK: Init

    init(mode: Mode, hostName: String, targetRounds: Int = 3, seed: UInt32? = nil) {
        self.mode = mode
        self.tableID = UUID().uuidString

        let resolvedSeed = seed ?? UInt32.random(in: 1...UInt32.max)
        var players: [TDPPlayer] = []
        var local: Set<TDPSeat> = [0]

        switch mode {
        case .practice:
            players = [
                TDPPlayer(id: "s0", name: hostName, seat: 0),
                TDPPlayer(id: "s1", name: "Ravi", seat: 1, isAI: true),
                TDPPlayer(id: "s2", name: "Meera", seat: 2, isAI: true)
            ]
        case .passAndPlay(let humanSeats):
            let humans = max(1, min(3, humanSeats))
            let names = [hostName, "Player 2", "Player 3"]
            let aiNames = ["Ravi", "Meera"]
            for seat in 0..<TDPProtocol.totalSeats {
                if seat < humans {
                    players.append(TDPPlayer(id: "s\(seat)", name: names[seat], seat: seat))
                    local.insert(seat)
                } else {
                    players.append(TDPPlayer(id: "s\(seat)",
                                             name: aiNames[(seat - humans) % aiNames.count],
                                             seat: seat, isAI: true))
                }
            }
        case .friends:
            // Seats 1 and 2 stay open until guests join or the host starts.
            players = [TDPPlayer(id: "s0", name: hostName, seat: 0)]
        }

        let state = TDPGameState(tableID: tableID, seed: resolvedSeed, players: players)
        self.engine = TDPEngine(state: state)
        self.engine.configureTargetRounds(targetRounds)
        self.localSeats = local
    }

    deinit { cancelPending() }

    // MARK: Networking

    func startHosting(displayName: String) {
        startHosting(transport: TDPMPCTransport(displayName: displayName))
    }

    /// Injectable seam — the tests drive a loopback transport through the
    /// exact same path the radio uses.
    func startHosting(transport: TDPTransport) {
        transport.onPeerEvent = { [weak self] event in self?.handle(event) }
        transport.onMessage = { [weak self] data, peer in self?.handle(data: data, from: peer) }
        self.transport = transport
        transport.startAdvertising(advert: currentAdvert)
        publishLobby()
    }

    func stopHosting(reason: String = "The host ended the table.") {
        if let transport, !remoteSeats.isEmpty {
            broadcast(type: .hostEndingTable, payload: TDPHostEnding(reason: reason))
            transport.disconnect()
        }
        transport?.disconnect()
        transport = nil
        cancelPending()
    }

    private var currentAdvert: TDPLobbyAdvert {
        TDPLobbyAdvert(tableId: tableID,
                       hostName: engine.state.player(at: 0)?.name ?? "Host",
                       humansJoined: 1 + remoteSeats.count,
                       targetRounds: engine.state.targetRounds,
                       isStarted: started)
    }

    // MARK: Starting

    /// Fills any still-open seat with an AI and begins. Friends tables can
    /// start with 1, 2 or 3 humans — the mix is the point.
    func startGame() {
        guard !started else { return }
        let aiNames = ["Ravi", "Meera", "Arjun"]
        var used = 0
        while let seat = engine.firstOpenSeat {
            engine.addPlayer(TDPPlayer(id: "s\(seat)",
                                       name: aiNames[used % aiNames.count],
                                       seat: seat, isAI: true))
            used += 1
        }
        started = true
        transport?.updateAdvert(currentAdvert)

        for seat in 0..<TDPProtocol.totalSeats {
            engine.apply(.setReady(seat: seat, ready: true))
        }
        pump()
    }

    // MARK: Local input

    /// Applies an intent originating from a seat this device controls.
    @discardableResult
    func submit(_ intent: TDPIntent, from seat: TDPSeat) -> TDPError? {
        guard localSeats.contains(seat) else {
            return TDPError("That seat is not played on this device.")
        }
        return perform(intent, seat: seat)
    }

    @discardableResult
    private func perform(_ intent: TDPIntent, seat: TDPSeat) -> TDPError? {
        if intent.kind == .beginNextRound, seat != engine.state.hostSeat {
            let error = TDPError("Only the host can begin the next round.")
            delegate?.host(self, didReject: error)
            return error
        }
        guard let action = intent.action(for: seat) else {
            let error = TDPError("Malformed action.")
            delegate?.host(self, didReject: error)
            return error
        }
        if let error = engine.apply(action) {
            delegate?.host(self, didReject: error)
            return error
        }
        pump()
        return nil
    }

    // MARK: The loop

    /// Advances everything that needs no human: automatic phases, then the
    /// AI seat whose turn it is. Re-entrant-safe via `cancelPending`.
    func pump() {
        cancelPending()
        refreshArrangeDeadline()
        publish()

        if let deadline = arrangeDeadline {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                engine.apply(.khichaiArrangeTimeout)
                pump()
                return
            }
            // Tick on each whole second so every screen's countdown moves.
            let fraction = remaining.truncatingRemainder(dividingBy: 1)
            schedule(after: fraction > 0.05 ? fraction : 1) { [weak self] in self?.pump() }
            return
        }

        switch engine.state.phase {
        case .dealerDraw, .dealFirstFive, .dealThree, .dealTwo:
            schedule(after: dealPace) { [weak self] in
                guard let self else { return }
                self.engine.flushAutomatic()
                self.pump()
            }
            return

        case .trickResolve:
            // Hold the completed trick on screen before collecting it —
            // longer when a person won it with a moment worth watching.
            let moment = trickHold > 0 && TDPMoments.pendingMoment(engine.state) == .firstCut
            schedule(after: trickHold + (moment ? momentHold : 0)) { [weak self] in
                guard let self else { return }
                self.engine.apply(.ackTrick)
                self.pump()
            }
            return

        case .sessionEnd:
            return

        default:
            break
        }

        // Any AI seat with something to do?
        for seat in 0..<TDPProtocol.totalSeats {
            guard let player = engine.state.player(at: seat), player.isAI else { continue }
            guard let action = TDPAIEngine.nextAction(state: engine.state,
                                                      seat: seat,
                                                      difficulty: difficulty) else { continue }
            let beat = aiThinkTime > 0 && TDPMoments.justCut(engine.state) ? momentBeat : 0
            schedule(after: aiThinkTime + beat) { [weak self] in
                guard let self else { return }
                if let error = self.engine.apply(action) {
                    dprint("TDP AI produced an illegal action: \(error.message)")
                    return
                }
                self.pump()
            }
            return
        }
    }

    #if DEBUG
    /// Debug only: runs a prepared mid-session state (see
    /// `TDPDebugScenario`) instead of dealing a fresh game. Players and
    /// local seats must already match this service's mode.
    func debugStart(with state: TDPGameState) {
        engine = TDPEngine(state: state)
        started = true
        pump()
    }
    #endif

    private func refreshArrangeDeadline() {
        guard engine.state.phase == .khichai,
              let step = engine.state.khichaiCurrent, step.arranging else {
            arrangeDeadline = nil
            arrangeKey = nil
            return
        }
        // One window per debtor per round.
        let key = "\(engine.state.roundNumber)-\(step.debtorSeat)"
        if arrangeKey != key {
            arrangeKey = key
            arrangeDeadline = Date().addingTimeInterval(arrangeWindow)
        }
    }

    private var arrangeSecondsLeft: Int? {
        arrangeDeadline.map { max(0, Int(ceil($0.timeIntervalSinceNow))) }
    }

    private func schedule(after delay: TimeInterval, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        pendingWork.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelPending() {
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()
    }

    // MARK: Publishing

    private var connectedSeats: Set<TDPSeat> {
        var seats: Set<TDPSeat> = localSeats
        for (seat, peer) in remoteSeats where transport?.connectedPeerIds.contains(peer) == true {
            seats.insert(seat)
        }
        for player in engine.state.players where player.isAI { seats.insert(player.seat) }
        return seats
    }

    /// Sends every seat its own redacted view. Local seats go to the
    /// delegate, remote seats over the wire.
    func publish() {
        let connected = connectedSeats
        for seat in localSeats.sorted() {
            let view = TDPViewBuilder.view(from: engine.state, for: seat,
                                           isHost: seat == 0, connectedSeats: connected,
                                           arrangeSecondsLeft: arrangeSecondsLeft)
            delegate?.host(self, didUpdateLocalView: view, seat: seat)
        }
        for (seat, peer) in remoteSeats {
            let view = TDPViewBuilder.view(from: engine.state, for: seat,
                                           isHost: false, connectedSeats: connected,
                                           arrangeSecondsLeft: arrangeSecondsLeft)
            send(type: .clientView, payload: view, to: [peer])
        }
        delegate?.hostDidPublish(self)
    }

    func publishLobby() {
        let snapshot = lobbySnapshot()
        delegate?.host(self, didUpdateLobby: snapshot)
        broadcast(type: .lobbySnapshot, payload: snapshot)
        transport?.updateAdvert(currentAdvert)
    }

    private func lobbySnapshot() -> TDPLobbySnapshot {
        var seats: [TDPLobbySeat] = []
        for seat in 0..<TDPProtocol.totalSeats {
            if let player = engine.state.player(at: seat) {
                let kind: String
                if seat == 0 { kind = "host" }
                else if player.isAI { kind = "ai" }
                else { kind = "remote" }
                seats.append(TDPLobbySeat(seat: seat, name: player.name,
                                          kind: kind, isReady: player.isReady))
            } else {
                seats.append(TDPLobbySeat(seat: seat, name: "Open", kind: "open", isReady: false))
            }
        }
        return TDPLobbySnapshot(tableId: tableID,
                                hostName: engine.state.player(at: 0)?.name ?? "Host",
                                targetRounds: engine.state.targetRounds,
                                seats: seats,
                                canStart: !started)
    }

    // MARK: Incoming

    private func handle(_ event: TDPPeerEvent) {
        switch event {
        case .receivedInvitation(let peerId, _):
            // Accept while there is a free seat; the join request that
            // follows does the actual seating.
            if !started && engine.state.players.count < TDPProtocol.totalSeats {
                transport?.accept(peerId: peerId)
            } else {
                transport?.reject(peerId: peerId)
            }

        case .peerDisconnected(let peerId):
            guard let seat = remoteSeats.first(where: { $0.value == peerId })?.key else { return }
            remoteSeats.removeValue(forKey: seat)
            if !started {
                engine.removePlayer(at: seat)
                publishLobby()
            } else {
                // Mid-game: the seat stays, but nobody is driving it. The
                // table is paused rather than handed to a bot — a quota
                // game is distorted by a bot inheriting someone's debts.
                delegate?.host(self, didEndWith: "\(engine.state.name(at: seat)) disconnected.")
            }

        case .transportError(let error):
            dprint("TDP transport error: \(error.localizedDescription)")

        default:
            break
        }
    }

    private func handle(data: Data, from peerId: String) {
        guard let decoded = try? TDPWireCodec.decode(data),
              decoded.header.tableId == tableID,
              decoded.header.senderPeerId == peerId else { return }
        switch decoded.type {
        case .joinRequest:
            guard let request: TDPJoinRequest = try? decoded.decode() else { return }
            seat(peerId: peerId, request: request)

        case .intent:
            guard let intent: TDPIntent = try? decoded.decode(),
                  let seat = remoteSeats.first(where: { $0.value == peerId })?.key else { return }
            // The seat comes from our own registry, never from the message,
            // so a client cannot act on another seat's behalf.
            let action = intent.action(for: seat)
            let authorizationError = intent.kind == .beginNextRound
                ? TDPError("Only the host can begin the next round.")
                : nil
            if let error = authorizationError ?? (action == nil ? TDPError("Malformed action.") : nil) {
                send(type: .intentRejected,
                     payload: TDPIntentRejected(kind: intent.kind, reason: error.message),
                     to: [peerId])
                publish()
            } else if let action, let error = engine.apply(action) {
                send(type: .intentRejected,
                     payload: TDPIntentRejected(kind: intent.kind, reason: error.message),
                     to: [peerId])
                publish()
            } else {
                pump()
            }

        case .ping:
            send(type: .pong, payload: TDPJoinRejected(reason: "pong"), to: [peerId])

        default:
            break
        }
    }

    private func seat(peerId: String, request: TDPJoinRequest) {
        guard !started else {
            send(type: .joinRejected, payload: TDPJoinRejected(reason: "That table has already started."), to: [peerId])
            return
        }
        guard request.clientVersion == TDPProtocol.version else {
            send(type: .joinRejected, payload: TDPJoinRejected(reason: "Different app version."), to: [peerId])
            return
        }
        guard let free = engine.firstOpenSeat else {
            send(type: .joinRejected, payload: TDPJoinRejected(reason: "The table is full."), to: [peerId])
            return
        }

        let name = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let player = TDPPlayer(id: "s\(free)", name: name.isEmpty ? "Guest" : name,
                               seat: free, isAI: false, isRemote: true)
        if let error = engine.addPlayer(player) {
            send(type: .joinRejected, payload: TDPJoinRejected(reason: error.message), to: [peerId])
            return
        }
        remoteSeats[free] = peerId

        send(type: .joinAccepted,
             payload: TDPJoinAccepted(seat: free, displayName: player.name, lobby: lobbySnapshot()),
             to: [peerId])
        publishLobby()
    }

    // MARK: Send helpers

    private func nextSequence() -> UInt64 {
        sequence += 1
        return sequence
    }

    private func send<P: Codable>(type: TDPMessageType, payload: P, to peers: [String]) {
        guard let transport else { return }
        let message = TDPMessage(tableId: tableID,
                                 roundNumber: engine.state.roundNumber,
                                 sequence: nextSequence(),
                                 senderPeerId: transport.localPeerId,
                                 type: type,
                                 payload: payload)
        guard let data = try? TDPWireCodec.encode(message) else { return }
        transport.send(data, to: peers)
    }

    private func broadcast<P: Codable>(type: TDPMessageType, payload: P) {
        guard let transport else { return }
        let message = TDPMessage(tableId: tableID,
                                 roundNumber: engine.state.roundNumber,
                                 sequence: nextSequence(),
                                 senderPeerId: transport.localPeerId,
                                 type: type,
                                 payload: payload)
        guard let data = try? TDPWireCodec.encode(message) else { return }
        transport.broadcast(data)
    }
}
