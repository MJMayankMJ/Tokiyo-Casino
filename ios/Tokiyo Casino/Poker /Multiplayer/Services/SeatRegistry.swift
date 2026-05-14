//
//  SeatRegistry.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Bookkeeping for the host: which seat is held by which network peer,
//  who is currently disconnected, who has been swapped to AI, and the
//  reconnect tokens we hand out so a peer can come back after dropping.
//

import Foundation

final class SeatRegistry {

    enum SeatKind: String {
        case host       // the device running the host service
        case remote     // a guest human over the network
        case ai         // AI bot (filling an empty seat)
        case open       // unfilled in lobby
    }

    struct SeatRecord {
        let seatId: Int
        var kind: SeatKind
        var displayName: String
        /// Peer id that owns this seat (nil for AI/host/open).
        var peerId: String?
        /// Reconnect token issued to the seat's owner. Stable across a
        /// single session so reconnecting peers get the same seat back.
        var reconnectToken: String?
        var isReady: Bool
        var isDisconnected: Bool
        /// True after the host swapped this seat to AI because the guest
        /// didn't reconnect within `reconnectGraceSeconds`.
        var aiTookOver: Bool
    }

    var seats: [SeatRecord] = []

    /// Token → seat id quick lookup so reconnect requests can be matched
    /// in O(1) without scanning the whole table.
    private var tokenIndex: [String: Int] = [:]

    func reset(totalSeats: Int, hostSeatId: Int, hostName: String) {
        seats = (0..<totalSeats).map { id in
            if id == hostSeatId {
                return SeatRecord(
                    seatId: id, kind: .host, displayName: hostName,
                    peerId: nil, reconnectToken: nil,
                    isReady: true, isDisconnected: false, aiTookOver: false
                )
            }
            return SeatRecord(
                seatId: id, kind: .open, displayName: "Seat \(id + 1)",
                peerId: nil, reconnectToken: nil,
                isReady: false, isDisconnected: false, aiTookOver: false
            )
        }
        tokenIndex.removeAll()
    }

    func record(forSeat seatId: Int) -> SeatRecord? {
        guard seatId >= 0 && seatId < seats.count else { return nil }
        return seats[seatId]
    }

    func seat(forPeer peerId: String) -> Int? {
        seats.firstIndex(where: { $0.peerId == peerId })
    }

    func seat(forToken token: String) -> Int? { tokenIndex[token] }

    func firstOpenSeat() -> Int? {
        seats.firstIndex(where: { $0.kind == .open })
    }

    @discardableResult
    func assign(remotePeerId: String, displayName: String) -> Int? {
        guard let seatId = firstOpenSeat() else { return nil }
        let token = UUID().uuidString
        seats[seatId].kind = .remote
        seats[seatId].peerId = remotePeerId
        seats[seatId].displayName = displayName
        seats[seatId].reconnectToken = token
        seats[seatId].isReady = false
        seats[seatId].isDisconnected = false
        seats[seatId].aiTookOver = false
        tokenIndex[token] = seatId
        return seatId
    }

    func markDisconnected(seatId: Int) {
        guard seats.indices.contains(seatId) else { return }
        seats[seatId].isDisconnected = true
    }

    func markReconnected(seatId: Int, peerId: String) {
        guard seats.indices.contains(seatId) else { return }
        seats[seatId].isDisconnected = false
        seats[seatId].peerId = peerId
    }

    func swapToAI(seatId: Int, displayName: String) {
        guard seats.indices.contains(seatId) else { return }
        if let oldToken = seats[seatId].reconnectToken {
            tokenIndex.removeValue(forKey: oldToken)
        }
        seats[seatId].kind = .ai
        seats[seatId].displayName = displayName
        seats[seatId].peerId = nil
        seats[seatId].reconnectToken = nil
        seats[seatId].isReady = true
        seats[seatId].isDisconnected = false
        seats[seatId].aiTookOver = true
    }

    func remove(peerId: String) {
        if let seatId = seat(forPeer: peerId) {
            markDisconnected(seatId: seatId)
        }
    }

    func setReady(seatId: Int, isReady: Bool) {
        guard seats.indices.contains(seatId) else { return }
        seats[seatId].isReady = isReady
    }

    func setSettings(totalSeats: Int) {
        if totalSeats == seats.count { return }
        if totalSeats > seats.count {
            for i in seats.count..<totalSeats {
                seats.append(SeatRecord(
                    seatId: i, kind: .open, displayName: "Seat \(i + 1)",
                    peerId: nil, reconnectToken: nil,
                    isReady: false, isDisconnected: false, aiTookOver: false
                ))
            }
        } else {
            // Shrinking — drop trailing open seats only. Refuse if a
            // non-open seat would be lost; caller must validate.
            seats.removeLast(seats.count - totalSeats)
        }
    }

    func lobbySeatPayloads() -> [LobbySeatPayload] {
        seats.map { rec in
            LobbySeatPayload(
                seatId: rec.seatId,
                displayName: rec.displayName,
                kind: rec.kind.rawValue,
                peerId: rec.peerId,
                isHost: rec.kind == .host,
                isReady: rec.isReady
            )
        }
    }

    /// Map suitable for snapshot building: seatId → "host" | "remote" |
    /// "ai" | "open". The snapshot ignores "open" (those seats aren't
    /// part of the GameManager once a hand starts), but the lobby uses
    /// the full set.
    func playerKindBySeatId() -> [Int: String] {
        var out: [Int: String] = [:]
        for rec in seats {
            switch rec.kind {
            case .host, .remote: out[rec.seatId] = "human"
            case .ai: out[rec.seatId] = "ai"
            case .open: continue
            }
        }
        return out
    }

    func disconnectedSeats() -> Set<Int> {
        Set(seats.filter { $0.isDisconnected }.map { $0.seatId })
    }

    func aiTakenOverSeats() -> Set<Int> {
        Set(seats.filter { $0.aiTookOver }.map { $0.seatId })
    }
}
