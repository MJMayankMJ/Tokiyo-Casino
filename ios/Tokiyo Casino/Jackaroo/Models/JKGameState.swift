//
//  JKGameState.swift
//  Tokiyo Casino — Jackaroo
//
//  Root snapshot. The engine owns one of these and mutates it through
//  the move resolver. The state alone (plus the rules) is enough for
//  every subsystem to do its job — the board graph is reconstructed
//  from rules + topology and held separately by the engine because
//  it doesn't need to be serialized.
//

import Foundation

public struct JKGameState: Codable {
    public var players: [JKPlayer]               // 4
    public var marbles: [JKMarble]               // 16
    public var deck: [JKCard]                    // draw pile (last index = top)
    public var firePile: [JKCard]                // discard

    public var dealer: SeatID
    public var currentSeat: SeatID
    public var phase: JKPhase
    public var direction: JKDirection

    /// How many hands have been dealt during this game. Used for
    /// `dealCycle` scheduling and the "Hand N" info pill.
    public var handsDealt: Int

    /// Per-seat "I've finished all 4 of my own marbles" flag. Once
    /// true, that seat moves partner marbles (`partnerHandoff`).
    public var handoffEngaged: [Bool]            // length 4

    public var rules: JKRulesPreset
    public var seed: UInt64
    public var rng: JKSeededRNG
    public var log: [JKGameLog.Event]
    public var winner: JKTeam?

    public init(
        players: [JKPlayer],
        marbles: [JKMarble],
        dealer: SeatID,
        rules: JKRulesPreset,
        seed: UInt64
    ) {
        precondition(players.count == 4, "Jackaroo is 4-player")
        precondition(marbles.count == 16, "Jackaroo uses 16 marbles")
        self.players = players
        self.marbles = marbles
        self.deck = []
        self.firePile = []
        self.dealer = dealer
        self.currentSeat = (dealer + 1) % 4    // dealer's left starts (CW default)
        self.phase = .dealing
        self.direction = rules.direction
        self.handsDealt = 0
        self.handoffEngaged = [false, false, false, false]
        self.rules = rules
        self.seed = seed
        self.rng = JKSeededRNG(seed: seed)
        self.log = []
        self.winner = nil

        if rules.seatOrder == .dealerRightCCW {
            self.currentSeat = (dealer + 3) % 4   // dealer's right
        }
    }

    // MARK: - Queries

    /// All 4 marbles owned by a given seat.
    public func ownMarbles(of seat: SeatID) -> [JKMarble] {
        marbles.filter { $0.owner == seat }
    }

    /// Marbles the given seat is allowed to move on its turn.
    /// Includes the partner's marbles if handoff is engaged for the seat.
    public func ownableMarbles(of seat: SeatID) -> [JKMarble] {
        let direct = ownMarbles(of: seat)
        guard rules.partnerHandoff, handoffEngaged[seat] else { return direct }
        let partner = JKTeam.partner(of: seat)
        return direct + ownMarbles(of: partner)
    }

    /// `true` iff every marble owned by `seat` is parked in Safe.
    public func hasFinishedOwnMarbles(_ seat: SeatID) -> Bool {
        ownMarbles(of: seat).allSatisfy {
            if case .safe = $0.position { return true }
            return false
        }
    }

    public func team(_ team: JKTeam) -> [JKMarble] {
        marbles.filter { $0.owner % 2 == (team == .a ? 0 : 1) }
    }

    /// Victory check — all 8 team marbles in Safe.
    public func winnerIfAny() -> JKTeam? {
        for t in [JKTeam.a, JKTeam.b] {
            if team(t).allSatisfy({
                if case .safe = $0.position { return true }
                return false
            }) {
                return t
            }
        }
        return nil
    }
}
