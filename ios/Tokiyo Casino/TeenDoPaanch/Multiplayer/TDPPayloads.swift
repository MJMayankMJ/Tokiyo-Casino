//
//  TDPPayloads.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Every message payload. Wire-stable: renaming a field is a breaking
//  change that needs `TDPProtocol.version` bumped.
//
//  The important type here is `TDPClientView` — the *redacted* per-seat
//  snapshot. It is the only game state a client ever sees, so hidden
//  information is enforced by construction rather than by discipline.
//

import Foundation

// MARK: - Lobby

/// Broadcast in MPC `discoveryInfo`, so it must stay a flat string map.
struct TDPLobbyAdvert {
    let tableId: String
    let hostName: String
    let humansJoined: Int
    let targetRounds: Int
    let isStarted: Bool

    var discoveryInfo: [String: String] {
        [
            "v": "\(TDPProtocol.version)",
            "tableId": tableId,
            "host": hostName,
            "humans": "\(humansJoined)",
            "rounds": "\(targetRounds)",
            "started": isStarted ? "1" : "0"
        ]
    }

    init(tableId: String, hostName: String, humansJoined: Int, targetRounds: Int, isStarted: Bool) {
        self.tableId = tableId
        self.hostName = hostName
        self.humansJoined = humansJoined
        self.targetRounds = targetRounds
        self.isStarted = isStarted
    }

    /// Returns nil for a host on a different major protocol version, so
    /// incompatible tables never appear in the join list.
    init?(discoveryInfo info: [String: String]) {
        guard let raw = info["v"], Int(raw) == TDPProtocol.version else { return nil }
        self.tableId = info["tableId"] ?? UUID().uuidString
        self.hostName = info["host"] ?? "Host"
        self.humansJoined = Int(info["humans"] ?? "1") ?? 1
        self.targetRounds = Int(info["rounds"] ?? "3") ?? 3
        self.isStarted = (info["started"] ?? "0") == "1"
    }
}

struct TDPJoinRequest: Codable {
    let displayName: String
    let clientVersion: Int
}

struct TDPJoinAccepted: Codable {
    let seat: TDPSeat
    let displayName: String
    let lobby: TDPLobbySnapshot
}

struct TDPJoinRejected: Codable {
    let reason: String
}

struct TDPLobbySeat: Codable {
    let seat: TDPSeat
    let name: String
    /// "host" | "remote" | "ai" | "open"
    let kind: String
    let isReady: Bool
}

struct TDPLobbySnapshot: Codable {
    let tableId: String
    let hostName: String
    let targetRounds: Int
    let seats: [TDPLobbySeat]
    let canStart: Bool
}

struct TDPPeerLeft: Codable {
    let seat: TDPSeat
    let reason: String
}

struct TDPHostEnding: Codable {
    let reason: String
}

// MARK: - Redacted game view

struct TDPSeatView: Codable {
    let seat: TDPSeat
    let name: String
    /// "you" | "ai" | "remote"
    let kind: String
    /// Card *count* only — never the cards.
    let handCount: Int
    let tricksWon: Int
    let quota: Int
    let score: Int
    /// `TDPRole` raw value, nil before the dealer is known.
    let role: String?
    let isDealer: Bool
    let isConnected: Bool
    /// Card drawn in the first-dealer draw; public by nature.
    let drawnCard: Card?
}

/// The pull in progress. `drawnCard` and `legalReturnIDs` are populated
/// ONLY in the creditor's copy — everyone else sees the seats and counts
/// so their animation can run, and nothing else.
struct TDPKhichaiView: Codable {
    let creditorSeat: TDPSeat
    let debtorSeat: TDPSeat
    let fanCount: Int
    let iAmCreditor: Bool
    let iAmDebtor: Bool
    let drawnCard: Card?
    let legalReturnIDs: [String]?
}

/// What the host is waiting on from this client, so the UI knows which
/// control to surface without re-deriving the rules.
enum TDPPrompt: String, Codable {
    case none
    case ready
    case chooseTrump
    case khichaiDraw
    case khichaiReturn
    case playCard
    case roundEnd
}

struct TDPClientView: Codable {
    let tableId: String
    let phase: TDPPhase
    let roundNumber: Int
    let trickNumber: Int
    let targetRounds: Int

    // This client
    let mySeat: TDPSeat
    let myHand: [Card]
    let myLegalCardIDs: [String]
    let prompt: TDPPrompt
    let isMyTurn: Bool
    /// Only the trump selector sees this, and only under highest-of-three.
    let myPrivateTrumpCard: Card?

    // Public
    let seats: [TDPSeatView]
    let dealerSeat: TDPSeat?
    let trump: Suit?
    let trumpMethod: TDPTrumpMethod?
    let revealedTrumpCard: Card?
    let currentTrick: [TDPTrickPlay]
    let leadSuit: Suit?
    let currentTurnSeat: TDPSeat?
    let leaderSeat: TDPSeat?
    let lastTrick: [TDPTrickPlay]
    let lastTrickWinnerSeat: TDPSeat?

    // Settlement
    let debts: [TDPDebt]
    let khichai: TDPKhichaiView?

    // Session
    let roundHistory: [TDPRoundScore]
    let canEndSession: Bool
    let isHost: Bool
    let message: String
}

// MARK: - Intents (client → host)

/// One flat struct rather than an enum with associated values, so the
/// wire form stays trivially decodable from another platform.
struct TDPIntent: Codable {

    enum Kind: String, Codable {
        case ready
        case targetRounds
        case trumpSuit
        case trumpSeventh
        case trumpHighestOfThree
        case khichaiDraw
        case khichaiReturn
        case playCard
        case beginNextRound
        case extendSession
        case endSession
    }

    let kind: Kind
    var ready: Bool?
    var rounds: Int?
    var suit: Suit?
    /// Position in the fanned hand, never a card id — the host resolves it.
    var fanIndex: Int?
    var cardID: String?

    init(kind: Kind,
         ready: Bool? = nil,
         rounds: Int? = nil,
         suit: Suit? = nil,
         fanIndex: Int? = nil,
         cardID: String? = nil) {
        self.kind = kind
        self.ready = ready
        self.rounds = rounds
        self.suit = suit
        self.fanIndex = fanIndex
        self.cardID = cardID
    }

    /// Maps to an engine action for `seat`. The host always supplies the
    /// seat itself — a client cannot act for another seat by asking to.
    func action(for seat: TDPSeat) -> TDPAction? {
        switch kind {
        case .ready:               return .setReady(seat: seat, ready: ready ?? true)
        case .targetRounds:        return .setTargetRounds(seat: seat, rounds: rounds ?? 3)
        case .trumpSuit:           return suit.map { .selectTrumpSuit(seat: seat, suit: $0) }
        case .trumpSeventh:        return .selectTrumpSeventh(seat: seat)
        case .trumpHighestOfThree: return .selectTrumpHighestOfThree(seat: seat)
        case .khichaiDraw:         return .khichaiDraw(seat: seat, fanIndex: fanIndex)
        case .khichaiReturn:       return cardID.map { .khichaiReturn(seat: seat, cardID: $0) }
        case .playCard:            return cardID.map { .playCard(seat: seat, cardID: $0) }
        case .beginNextRound:      return .beginNextRound
        case .extendSession:       return .extendSession(seat: seat)
        case .endSession:          return .endSession(seat: seat)
        }
    }
}

struct TDPIntentRejected: Codable {
    let kind: TDPIntent.Kind
    let reason: String
}
