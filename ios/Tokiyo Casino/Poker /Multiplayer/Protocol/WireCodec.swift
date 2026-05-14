//
//  WireCodec.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Encode/decode for envelopes plus the union dispatch that turns raw
//  bytes into a typed payload. Encoding pins JSON ordering (`sortedKeys`)
//  so golden fixtures and Android comparisons stay byte-identical.
//

import Foundation

enum PokerWireError: Error, LocalizedError {
    case oversize(bytes: Int)
    case unsupportedVersion(Int)
    case decodeFailure(underlying: Error)
    case unknownType(String)

    var errorDescription: String? {
        switch self {
        case .oversize(let bytes):
            return "Multiplayer message exceeded \(PokerProtocol.maxPayloadBytes) bytes (\(bytes))."
        case .unsupportedVersion(let v):
            return "Unsupported multiplayer protocol version: \(v)."
        case .decodeFailure(let err):
            return "Failed to decode multiplayer message: \(err.localizedDescription)"
        case .unknownType(let t):
            return "Unknown multiplayer message type: \(t)."
        }
    }
}

/// Type-erased decoded message. The consumer switches on `type` and uses
/// the corresponding `as*` accessor for the payload.
struct DecodedPokerMessage {
    let type: PokerMessageType
    let header: PokerMessageHeader
    /// The raw payload JSON object, re-encodable. Kept so subsystems can
    /// decode the payload into whichever struct they need.
    let payloadData: Data

    func decodePayload<P: Decodable>(_ : P.Type = P.self,
                                     decoder: JSONDecoder = PokerWireCodec.decoder) throws -> P {
        do { return try decoder.decode(P.self, from: payloadData) }
        catch { throw PokerWireError.decodeFailure(underlying: error) }
    }
}

enum PokerWireCodec {

    /// Shared encoder. `sortedKeys` keeps JSON byte-stable so we can use
    /// golden fixtures in tests and on the Android side.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        // Use ISO seconds if any payload ever carries a Date (none today).
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Encode an outbound envelope. Throws `oversize` if encoded length
    /// exceeds the hard limit; logs a warning if it exceeds the soft
    /// budget so we can keep tabs on snapshot bloat over time.
    static func encode<P: Encodable>(_ message: PokerMessage<P>) throws -> Data {
        let data: Data
        do {
            data = try encoder.encode(message)
        } catch {
            throw PokerWireError.decodeFailure(underlying: error)
        }
        guard data.count <= PokerProtocol.maxPayloadBytes else {
            throw PokerWireError.oversize(bytes: data.count)
        }
        if data.count > PokerProtocol.warnPayloadBytes {
            #if DEBUG
            print("⚠️ Poker MP: large message (\(data.count) bytes) type=\(message.type.rawValue)")
            #endif
        }
        return data
    }

    /// Two-pass decode:
    /// 1) read the envelope header to learn `type`
    /// 2) extract the raw `payload` sub-object as `Data` for typed decode
    static func decode(_ data: Data) throws -> DecodedPokerMessage {
        guard data.count <= PokerProtocol.maxPayloadBytes else {
            throw PokerWireError.oversize(bytes: data.count)
        }

        let header: PokerMessageHeader
        do {
            header = try decoder.decode(PokerMessageHeader.self, from: data)
        } catch {
            throw PokerWireError.decodeFailure(underlying: error)
        }

        guard header.protocolVersion == PokerProtocol.version else {
            throw PokerWireError.unsupportedVersion(header.protocolVersion)
        }

        // Re-read as a JSON object so we can isolate `payload` and reserialize.
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw PokerWireError.decodeFailure(underlying: error)
        }
        guard let dict = jsonObject as? [String: Any],
              let payloadAny = dict["payload"] else {
            throw PokerWireError.decodeFailure(
                underlying: NSError(domain: "PokerWire", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Missing payload."]))
        }

        let payloadData: Data
        do {
            // sortedKeys here too so derived test outputs are stable.
            payloadData = try JSONSerialization.data(withJSONObject: payloadAny, options: [.sortedKeys])
        } catch {
            throw PokerWireError.decodeFailure(underlying: error)
        }

        return DecodedPokerMessage(type: header.type, header: header, payloadData: payloadData)
    }
}
