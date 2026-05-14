//
//  MessageEnvelope.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Wire envelope that wraps every multiplayer message. Generic over the
//  payload so the same envelope shape can be reused for lobby, gameplay,
//  and connection messages.
//

import Foundation

/// Canonical list of message types. The raw string is the on-wire value;
/// Android clients must match these strings exactly.
enum PokerMessageType: String, Codable, CaseIterable {
    // Lobby
    case joinRequest
    case joinAccepted
    case joinRejected
    case peerLeft
    case seatUpdate
    case readyChanged
    case lobbySettingsChanged
    case startGame

    // Game
    case tableSnapshot
    case privateCards
    case actionRequest
    case playerActionIntent
    case actionAccepted
    case actionRejected
    case roundResult
    case sessionResult

    // Connection
    case ping
    case pong
    case pause
    case resume
    case reconnectRequest
    case reconnectAccepted
    case hostEndingTable
}

/// Generic envelope. `payload` is decoded into a concrete type after the
/// envelope's `type` field has been read (`PokerWireCodec.decode`).
struct PokerMessage<Payload: Codable>: Codable {
    let protocolVersion: Int
    let sessionId: String
    let tableId: String
    /// 1-based hand counter. `nil` for messages that aren't tied to a hand
    /// (lobby, ping/pong, host-ending, etc).
    let handNumber: UInt32?
    /// Host-assigned monotonic sequence for authoritative messages. `nil`
    /// for client-originated messages that don't need an order guarantee.
    let sequence: UInt64?
    let senderPeerId: String
    let type: PokerMessageType
    let payload: Payload

    init(
        sessionId: String,
        tableId: String,
        handNumber: UInt32? = nil,
        sequence: UInt64? = nil,
        senderPeerId: String,
        type: PokerMessageType,
        payload: Payload
    ) {
        self.protocolVersion = PokerProtocol.version
        self.sessionId = sessionId
        self.tableId = tableId
        self.handNumber = handNumber
        self.sequence = sequence
        self.senderPeerId = senderPeerId
        self.type = type
        self.payload = payload
    }
}

/// Header-only view used when the receiver needs to read `type` before
/// committing to a concrete payload struct.
struct PokerMessageHeader: Decodable {
    let protocolVersion: Int
    let sessionId: String
    let tableId: String
    let handNumber: UInt32?
    let sequence: UInt64?
    let senderPeerId: String
    let type: PokerMessageType
}
