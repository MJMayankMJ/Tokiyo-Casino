//
//  ProtocolGoldenFixtures.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Golden JSON fixtures for the multiplayer protocol. Compiled into the
//  app (DEBUG only) and validated on first launch via
//  `runProtocolFixtureSelfTest()`. They double as a reference for any
//  future Android decoder — drop these strings into the Android side
//  and the same Codable structures should round-trip.
//

import Foundation

#if DEBUG

enum ProtocolGoldenFixtures {

    /// Each fixture is a *canonical* encoding of a payload type. Bytes
    /// are sorted-keys, so changes to the encoder ordering will fail the
    /// fixture check and surface the wire-incompat early.
    static let tableSnapshotV1: String = """
    {"communityCards":[{"rank":"ace","suit":"spades"},{"rank":"king","suit":"hearts"},{"rank":"10","suit":"clubs"}],"currentBet":40,"currentPlayerSeat":2,"dealerSeat":0,"handNumber":3,"isPaused":false,"minRaise":40,"pausedForSeatId":null,"phase":"flop","players":[{"chips":960,"currentBet":40,"displayName":"Alice (host)","hasCards":true,"isAITakenOver":false,"isActive":true,"isAllIn":false,"isDealer":true,"isDisconnected":false,"isFolded":false,"kind":"human","lastAction":"call","lastActionAmount":null,"revealedHoleCards":null,"seatId":0,"totalInvested":40},{"chips":960,"currentBet":40,"displayName":"Bob","hasCards":true,"isAITakenOver":false,"isActive":true,"isAllIn":false,"isDealer":false,"isDisconnected":false,"isFolded":false,"kind":"human","lastAction":"call","lastActionAmount":null,"revealedHoleCards":null,"seatId":1,"totalInvested":40},{"chips":1000,"currentBet":0,"displayName":"\\ud83d\\udc20 Fish","hasCards":true,"isAITakenOver":false,"isActive":true,"isAllIn":false,"isDealer":false,"isDisconnected":false,"isFolded":false,"kind":"ai","lastAction":null,"lastActionAmount":null,"revealedHoleCards":null,"seatId":2,"totalInvested":0}],"pot":120,"smallBlind":10}
    """

    static let privateCardsV1: String = """
    {"cards":[{"rank":"ace","suit":"spades"},{"rank":"king","suit":"spades"}],"handNumber":3,"seatId":1}
    """

    static let actionIntentV1: String = """
    {"action":"raise","clientKnownSequence":42,"raiseAmount":80,"seatId":2}
    """

    static let actionAcceptedV1: String = """
    {"action":"raise","appliedSequence":43,"raiseAmount":80,"seatId":2}
    """

    static let roundResultV1: String = """
    {"communityCards":[{"rank":"ace","suit":"spades"},{"rank":"king","suit":"hearts"},{"rank":"10","suit":"clubs"},{"rank":"7","suit":"diamonds"},{"rank":"2","suit":"clubs"}],"handNumber":3,"revealedHoleCards":[{"cards":[{"rank":"ace","suit":"hearts"},{"rank":"king","suit":"diamonds"}],"seatId":0}],"totalPot":240,"winners":[{"amount":240,"displayName":"Alice (host)","handDescription":"Two Pair, Aces and Kings","seatId":0}]}
    """

    /// Run an in-process round-trip check. Logs a clear failure if the
    /// fixtures drift from the live encoder. Safe to call repeatedly.
    static func selfTest() {
        verify(tableSnapshotV1, as: TableSnapshotPayload.self, label: "tableSnapshot")
        verify(privateCardsV1, as: PrivateCardsPayload.self, label: "privateCards")
        verify(actionIntentV1, as: PlayerActionIntentPayload.self, label: "actionIntent")
        verify(actionAcceptedV1, as: ActionAcceptedPayload.self, label: "actionAccepted")
        verify(roundResultV1, as: RoundResultPayload.self, label: "roundResult")
    }

    private static func verify<P: Codable>(_ json: String, as: P.Type, label: String) {
        guard let data = json.data(using: .utf8) else {
            print("⚠️ Poker MP fixture \(label): cannot UTF-8 encode")
            return
        }
        do {
            let value = try PokerWireCodec.decoder.decode(P.self, from: data)
            let reEncoded = try PokerWireCodec.encoder.encode(value)
            if reEncoded != data {
                let got = String(data: reEncoded, encoding: .utf8) ?? "<binary>"
                print("⚠️ Poker MP fixture drift for \(label).\n  expected: \(json)\n  got:      \(got)")
            } else {
                print("✅ Poker MP fixture \(label) round-trip OK (\(data.count) bytes)")
            }
        } catch {
            print("⚠️ Poker MP fixture \(label) failed to decode: \(error)")
        }
    }
}

#endif
