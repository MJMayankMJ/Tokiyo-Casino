//
//  JKPlayer.swift
//  Tokiyo Casino — Jackaroo
//
//  Per-seat snapshot. Personality enum mirrors Poker's AIPersonality
//  shape but stays Jackaroo-local so the engine has zero compile-time
//  dependency on the Poker module's enum.
//

import Foundation

public enum JKPersonality: String, Codable, CaseIterable, Hashable {
    case tightAggressive
    case loosePassive
    case balanced
    case bluffer

    var displayName: String {
        switch self {
        case .tightAggressive: return "Shark"
        case .loosePassive:    return "Fish"
        case .balanced:        return "Pro"
        case .bluffer:         return "Maniac"
        }
    }

    /// Emoji used alongside the name for AI seats in the lobby. Jackaroo's
    /// own strings — not shared with Poker's `AIPersonality`.
    var icon: String {
        switch self {
        case .tightAggressive: return "🦈"
        case .loosePassive:    return "🐟"
        case .balanced:        return "🎩"
        case .bluffer:         return "🃏"
        }
    }
}

public enum JKPlayerKind: Codable, Hashable {
    case human
    case ai(personality: JKPersonality)
}

public struct JKPlayer: Codable, Hashable {
    public let seat: SeatID
    public let team: JKTeam
    public let name: String
    public let kind: JKPlayerKind
    public var hand: [JKCard]

    public init(seat: SeatID, name: String, kind: JKPlayerKind, hand: [JKCard] = []) {
        self.seat = seat
        self.team = JKTeam.of(seat: seat)
        self.name = name
        self.kind = kind
        self.hand = hand
    }

    var isHuman: Bool {
        if case .human = kind { return true }
        return false
    }
}
