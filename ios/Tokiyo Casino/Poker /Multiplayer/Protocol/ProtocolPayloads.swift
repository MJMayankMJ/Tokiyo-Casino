//
//  ProtocolPayloads.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  All message payload structs. Wire-stable: changing a field name or its
//  meaning is a breaking change that requires bumping `PokerProtocol.version`
//  and updating the Android decoder spec.
//

import Foundation

// MARK: - Lobby payloads

/// Snapshot of a host's open table broadcast through MPC's discoveryInfo.
struct LobbyAdvertisement: Codable {
    let tableId: String
    let hostName: String
    let displayName: String
    let smallBlind: Int
    let bigBlind: Int
    let startingChips: Int
    let totalSeats: Int
    let humansJoined: Int
    let aiFillEnabled: Bool
    let isStarted: Bool
}

struct JoinRequestPayload: Codable {
    let displayName: String
    let clientVersion: Int
    /// If the guest is reconnecting, the token they received originally.
    let reconnectToken: String?
}

struct JoinAcceptedPayload: Codable {
    let seatId: Int
    let displayName: String
    let reconnectToken: String
    let lobby: LobbySnapshotPayload
}

struct JoinRejectedPayload: Codable {
    let reason: String
}

struct PeerLeftPayload: Codable {
    let seatId: Int
    let reason: String
}

struct SeatUpdatePayload: Codable {
    let seats: [LobbySeatPayload]
}

struct LobbySettingsChangedPayload: Codable {
    let smallBlind: Int
    let bigBlind: Int
    let startingChips: Int
    let totalSeats: Int
    let aiFillEnabled: Bool
}

struct ReadyChangedPayload: Codable {
    let seatId: Int
    let isReady: Bool
}

struct StartGamePayload: Codable {
    let firstHandNumber: UInt32
}

// MARK: - Lobby snapshot

/// Public view of a lobby — sent on join accept and on every seat change.
struct LobbySnapshotPayload: Codable {
    let tableId: String
    let sessionId: String
    let smallBlind: Int
    let bigBlind: Int
    let startingChips: Int
    let totalSeats: Int
    let aiFillEnabled: Bool
    let seats: [LobbySeatPayload]
    let hostPeerId: String
}

struct LobbySeatPayload: Codable {
    let seatId: Int
    let displayName: String
    /// One of: "open" | "human" | "ai".
    let kind: String
    /// MPC peer-display-name of the guest holding this seat, or nil for
    /// host/AI/open. Useful for UI debugging only.
    let peerId: String?
    let isHost: Bool
    let isReady: Bool
}

// MARK: - Game payloads

struct TableSnapshotPayload: Codable {
    let phase: String
    let handNumber: UInt32
    let dealerSeat: Int
    /// Seat id whose turn it currently is, or nil between streets / when
    /// no action is required (e.g. showdown moment).
    let currentPlayerSeat: Int?
    let smallBlind: Int
    let bigBlind: Int
    let currentBet: Int
    let minRaise: Int
    let pot: Int
    let communityCards: [CardDTO]
    let players: [PublicPlayerStatePayload]
    /// True when a guest is currently disconnected and the host has paused
    /// to wait them out. Clients use this to draw the "waiting for…" UI.
    let isPaused: Bool
    let pausedForSeatId: Int?
}

struct PublicPlayerStatePayload: Codable {
    let seatId: Int
    let displayName: String
    /// One of: "human" | "ai" | "remote".
    let kind: String
    let chips: Int
    let currentBet: Int
    let totalInvested: Int
    let isFolded: Bool
    let isAllIn: Bool
    let isActive: Bool
    let isDealer: Bool
    /// Last action raw enum string: "fold" | "check" | "call" | "raise" | "allIn".
    let lastAction: String?
    let lastActionAmount: Int?
    /// True if the seat currently holds hole cards. The actual values are
    /// sent privately via `privateCards`, never inside the public snapshot.
    let hasCards: Bool
    let isDisconnected: Bool
    let isAITakenOver: Bool
    /// Only populated at showdown for seats whose cards should be visible
    /// to everyone. nil at all other times to preserve privacy.
    let revealedHoleCards: [CardDTO]?
}

struct PrivateCardsPayload: Codable {
    let seatId: Int
    let handNumber: UInt32
    let cards: [CardDTO]
}

struct ActionRequestPayload: Codable {
    let seatId: Int
    let validActions: [String]
    let callAmount: Int
    let minRaise: Int
    let maxRaise: Int
    let currentBet: Int
    let allInTotal: Int
    let deadlineSeconds: Int?
}

struct PlayerActionIntentPayload: Codable {
    let seatId: Int
    /// "fold" | "check" | "call" | "raise" | "allIn".
    let action: String
    let raiseAmount: Int?
    let clientKnownSequence: UInt64
}

struct ActionAcceptedPayload: Codable {
    let seatId: Int
    let action: String
    let raiseAmount: Int?
    let appliedSequence: UInt64
}

struct ActionRejectedPayload: Codable {
    let seatId: Int
    let attemptedAction: String
    let reason: String
}

struct RoundResultPayload: Codable {
    let handNumber: UInt32
    let totalPot: Int
    let winners: [RoundWinnerPayload]
    let communityCards: [CardDTO]
    /// Final showdown reveal of every non-folded player's hole cards.
    let revealedHoleCards: [SeatedHolePayload]
}

struct RoundWinnerPayload: Codable {
    let seatId: Int
    let displayName: String
    let amount: Int
    let handDescription: String
}

struct SeatedHolePayload: Codable {
    let seatId: Int
    let cards: [CardDTO]
}

struct SessionResultPayload: Codable {
    let reason: String
    let standings: [SessionStandingPayload]
}

struct SessionStandingPayload: Codable {
    let seatId: Int
    let displayName: String
    let chips: Int
    let netDelta: Int
    let handsPlayed: Int
    let handsWon: Int
}

// MARK: - Connection payloads

struct PingPayload: Codable {
    let nonce: UInt64
    let sentAtMs: UInt64
}

struct PongPayload: Codable {
    let nonce: UInt64
    let sentAtMs: UInt64
}

struct PausePayload: Codable {
    let reason: String
    let pausedForSeatId: Int?
}

struct ResumePayload: Codable {
    let reason: String
}

struct ReconnectRequestPayload: Codable {
    let reconnectToken: String
    let displayName: String
    let clientVersion: Int
}

struct ReconnectAcceptedPayload: Codable {
    let seatId: Int
    let lobby: LobbySnapshotPayload?
    /// True when the table is already mid-game; clients should expect a
    /// `tableSnapshot` immediately after this message.
    let inGame: Bool
}

struct HostEndingTablePayload: Codable {
    let reason: String
}

// MARK: - Convenience empty payload

/// Use for messages that have no body (none currently, but reserved so
/// future additions don't need to invent shapes).
struct EmptyPayload: Codable {}
