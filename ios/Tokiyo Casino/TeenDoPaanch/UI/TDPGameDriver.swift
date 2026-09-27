//
//  TDPGameDriver.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The table UI renders a `TDPClientView` and posts `TDPIntent`s. It does
//  not care whether the authority is in-process (practice, pass-and-play)
//  or across the room (friends) — so both modes share one screen and one
//  code path, and the guest UI can never diverge from the host's rules.
//

import Foundation

protocol TDPGameDriver: AnyObject {
    var currentView: TDPClientView? { get }
    /// Seat this device is currently acting for. In pass-and-play it moves
    /// as the turn moves.
    var activeSeat: TDPSeat { get }
    /// True when more than one seat is played on this device, so the UI
    /// knows to draw the handoff curtain.
    var isSharedDevice: Bool { get }
    var onViewChanged: ((TDPClientView) -> Void)? { get set }
    var onRejected: ((String) -> Void)? { get set }
    var onEnded: ((String) -> Void)? { get set }

    func send(_ intent: TDPIntent)
    func start()
    func stop()

    /// Seats played on this device.
    var localSeats: [TDPSeat] { get }
    /// Acts for one particular seat on this device — for the public choices
    /// every person sharing a phone makes, like the vote on more rounds.
    func send(_ intent: TDPIntent, as seat: TDPSeat)
}

extension TDPGameDriver {
    var localSeats: [TDPSeat] { [activeSeat] }
    func send(_ intent: TDPIntent, as seat: TDPSeat) { send(intent) }
}

// MARK: - Host-backed (practice, pass & play, and the host's own seat)

final class TDPHostDriver: TDPGameDriver, TDPHostServiceDelegate {

    let service: TDPHostService
    private(set) var viewsBySeat: [TDPSeat: TDPClientView] = [:]
    private(set) var activeSeat: TDPSeat = 0
    /// Who is physically holding a shared device — the last seat that had a
    /// private decision to make.
    private var holderSeat: TDPSeat?

    var onViewChanged: ((TDPClientView) -> Void)?
    var onRejected: ((String) -> Void)?
    var onEnded: ((String) -> Void)?

    /// Decisions that need a hand only its owner may see.
    private static let privatePrompts: Set<TDPPrompt> = [
        .chooseTrump, .settleUp, .arrangeCards, .khichaiDraw, .khichaiReturn, .playCard
    ]

    init(service: TDPHostService) {
        self.service = service
        activeSeat = service.localSeats.sorted().first ?? 0
        service.delegate = self
    }

    var isSharedDevice: Bool { service.localSeats.count > 1 }

    var currentView: TDPClientView? { viewsBySeat[activeSeat] }

    /// Picks whose hand to show once all local views are fresh.
    private func resolveActiveSeat() -> TDPSeat {
        let seats = service.localSeats.sorted()
        guard seats.count > 1 else { return seats.first ?? 0 }

        if let seat = seats.first(where: { Self.privatePrompts.contains(viewsBySeat[$0]?.prompt ?? .none) }) {
            holderSeat = seat
            return seat
        }
        // The round summary is public, and the host seat drives "next round".
        if seats.contains(where: { viewsBySeat[$0]?.prompt == .roundEnd }), let host = seats.first {
            return host
        }
        // Nobody here has a decision (an AI is thinking, or a trick is being
        // collected). Stay on whoever holds the device rather than flipping
        // to another player's hand.
        return holderSeat ?? seats.first ?? 0
    }

    func start() {
        service.startGame()
    }

    func stop() {
        service.stopHosting()
    }

    func send(_ intent: TDPIntent) {
        service.submit(intent, from: activeSeat)
    }

    var localSeats: [TDPSeat] { service.localSeats.sorted() }

    func send(_ intent: TDPIntent, as seat: TDPSeat) {
        service.submit(intent, from: seat)
    }

    // MARK: TDPHostServiceDelegate

    func host(_ service: TDPHostService, didUpdateLocalView view: TDPClientView, seat: TDPSeat) {
        viewsBySeat[seat] = view
    }

    func hostDidPublish(_ service: TDPHostService) {
        activeSeat = resolveActiveSeat()
        if let view = viewsBySeat[activeSeat] { onViewChanged?(view) }
    }

    func host(_ service: TDPHostService, didReject error: TDPError) {
        onRejected?(error.message)
    }

    func host(_ service: TDPHostService, didEndWith reason: String) {
        onEnded?(reason)
    }
}

// MARK: - Client-backed (a guest at someone else's table)

final class TDPClientDriver: TDPGameDriver, TDPClientServiceDelegate {

    let service: TDPClientService

    var onViewChanged: ((TDPClientView) -> Void)?
    var onRejected: ((String) -> Void)?
    var onEnded: ((String) -> Void)?

    init(service: TDPClientService) {
        self.service = service
        service.delegate = self
    }

    var currentView: TDPClientView? { service.latestView }
    var activeSeat: TDPSeat { service.seat ?? 0 }
    var isSharedDevice: Bool { false }

    func start() {}
    func stop() { service.leave() }

    func send(_ intent: TDPIntent) { service.send(intent) }

    // MARK: TDPClientServiceDelegate

    func client(_ service: TDPClientService, didJoinSeat seat: TDPSeat) {}

    func client(_ service: TDPClientService, didUpdateView view: TDPClientView) {
        onViewChanged?(view)
    }

    func client(_ service: TDPClientService, didRejectIntent reason: String) {
        onRejected?(reason)
    }

    func client(_ service: TDPClientService, didFailWith reason: String) {
        onEnded?(reason)
    }
}
