//
//  ProtocolConstants.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Transport-neutral protocol constants shared by host and clients. These
//  values are part of the wire contract that future Android clients must
//  honor, so they must not change without bumping `protocolVersion`.
//

import Foundation

enum PokerProtocol {

    /// Wire-format version. Increment on any breaking change to message
    /// shapes. Clients MUST reject envelopes with mismatched major versions.
    static let version: Int = 1

    /// MPC service type (Bonjour) advertised by hosts. Must be 1–15
    /// lowercase ASCII chars per Apple's MPC docs.
    static let mpcServiceType: String = "tokiyo-poker"

    /// Soft size budget. Snapshots that exceed this in tests indicate a
    /// payload growth regression and should be investigated.
    static let warnPayloadBytes: Int = 16 * 1024

    /// Hard size limit. Incoming envelopes beyond this MUST be dropped.
    static let maxPayloadBytes: Int = 32 * 1024

    /// Max human players for v1 (PRD §9 recommendation).
    static let maxHumanSeats: Int = 6

    /// Maximum seats supported at a table.
    static let maxTotalSeats: Int = 6

    /// How long the host waits for a disconnected guest to reconnect
    /// before swapping their seat to an AI bot (PRD §5).
    static let reconnectGraceSeconds: TimeInterval = 30
}
