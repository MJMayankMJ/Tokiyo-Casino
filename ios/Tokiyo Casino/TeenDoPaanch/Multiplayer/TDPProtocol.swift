//
//  TDPProtocol.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Wire contract for offline friends play. Same shape as the Poker
//  protocol (`OFFLINE_FRIENDS_PRD.md` §4): host-authoritative, JSON with
//  pinned key order so a future Android client can byte-compare fixtures.
//
//  The host holds the only `TDPGameState`. Clients never receive it —
//  they get a per-seat redacted `TDPClientView`.
//

import Foundation

enum TDPProtocol {

    /// Bump on any breaking change to a payload shape.
    /// 3: settle-up choice, arranging window, per-round target changes.
    static let version: Int = 3

    /// Bonjour service type. 1–15 lowercase ASCII per Apple's MPC docs.
    static let mpcServiceType = "tokiyo-tdp"

    /// Teen Do Paanch is always exactly three seats.
    static let totalSeats = 3

    static let warnPayloadBytes = 8 * 1024
    static let maxPayloadBytes = 32 * 1024

    /// How long a seat stays reserved for a guest that dropped, before it
    /// is recycled to `.open`.
    static let staleAwaySeatSeconds: TimeInterval = 5 * 60
}

// MARK: - Message types

enum TDPMessageType: String, Codable, CaseIterable {
    // Lobby
    case joinRequest
    case joinAccepted
    case joinRejected
    case lobbySnapshot
    case startGame
    case peerLeft

    // Game
    case clientView
    case intent
    case intentRejected
    case hostEndingTable

    // Connection
    case ping
    case pong
}

// MARK: - Envelope

struct TDPMessage<Payload: Codable>: Codable {
    let protocolVersion: Int
    let tableId: String
    let roundNumber: Int?
    let sequence: UInt64?
    let senderPeerId: String
    let type: TDPMessageType
    let payload: Payload

    init(tableId: String,
         roundNumber: Int? = nil,
         sequence: UInt64? = nil,
         senderPeerId: String,
         type: TDPMessageType,
         payload: Payload) {
        self.protocolVersion = TDPProtocol.version
        self.tableId = tableId
        self.roundNumber = roundNumber
        self.sequence = sequence
        self.senderPeerId = senderPeerId
        self.type = type
        self.payload = payload
    }
}

/// Header-only view, so the receiver can read `type` before committing to
/// a concrete payload struct.
struct TDPMessageHeader: Decodable {
    let protocolVersion: Int
    let tableId: String
    let roundNumber: Int?
    let sequence: UInt64?
    let senderPeerId: String
    let type: TDPMessageType
}

// MARK: - Codec

enum TDPWireError: Error, LocalizedError {
    case oversize(bytes: Int)
    case unsupportedVersion(Int)
    case decodeFailure(String)
    case missingPayload

    var errorDescription: String? {
        switch self {
        case .oversize(let bytes):
            return "Message exceeded \(TDPProtocol.maxPayloadBytes) bytes (\(bytes))."
        case .unsupportedVersion(let v):
            return "Unsupported Teen Do Paanch protocol version: \(v)."
        case .decodeFailure(let reason):
            return "Could not decode message: \(reason)"
        case .missingPayload:
            return "Message had no payload."
        }
    }
}

struct TDPDecodedMessage {
    let type: TDPMessageType
    let header: TDPMessageHeader
    let payloadData: Data

    func decode<P: Decodable>(_: P.Type = P.self) throws -> P {
        do { return try TDPWireCodec.decoder.decode(P.self, from: payloadData) }
        catch { throw TDPWireError.decodeFailure(error.localizedDescription) }
    }
}

enum TDPWireCodec {

    /// `sortedKeys` keeps the bytes stable for golden fixtures.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder = JSONDecoder()

    static func encode<P: Encodable>(_ message: TDPMessage<P>) throws -> Data {
        let data: Data
        do { data = try encoder.encode(message) }
        catch { throw TDPWireError.decodeFailure(error.localizedDescription) }
        guard data.count <= TDPProtocol.maxPayloadBytes else {
            throw TDPWireError.oversize(bytes: data.count)
        }
        #if DEBUG
        if data.count > TDPProtocol.warnPayloadBytes {
            dprint("⚠️ TDP MP: large message (\(data.count) bytes) type=\(message.type.rawValue)")
        }
        #endif
        return data
    }

    /// Two-pass decode: read the header for `type`, then isolate the raw
    /// `payload` object so the caller can decode it into the right struct.
    static func decode(_ data: Data) throws -> TDPDecodedMessage {
        guard data.count <= TDPProtocol.maxPayloadBytes else {
            throw TDPWireError.oversize(bytes: data.count)
        }
        let header: TDPMessageHeader
        do { header = try decoder.decode(TDPMessageHeader.self, from: data) }
        catch { throw TDPWireError.decodeFailure(error.localizedDescription) }

        guard header.protocolVersion == TDPProtocol.version else {
            throw TDPWireError.unsupportedVersion(header.protocolVersion)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payloadAny = object["payload"] else {
            throw TDPWireError.missingPayload
        }
        guard let payloadData = try? JSONSerialization.data(withJSONObject: payloadAny,
                                                            options: [.sortedKeys]) else {
            throw TDPWireError.decodeFailure("payload could not be reserialised")
        }
        return TDPDecodedMessage(type: header.type, header: header, payloadData: payloadData)
    }
}
