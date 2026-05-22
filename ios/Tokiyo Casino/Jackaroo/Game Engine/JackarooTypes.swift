//
//  JackarooTypes.swift
//  Tokiyo Casino — Jackaroo
//
//  Small enums shared across the engine. Kept in one file because they
//  are tiny and constantly referenced.
//

import Foundation

/// Player identity within a seated game. Stored as a plain `Int` for
/// `Codable` simplicity and dictionary key efficiency.
public typealias SeatID = Int

/// Marble identity 0…15. Owner is `id / 4`. See JACKAROO_TECH_SPEC §2.
public typealias MarbleID = Int

/// Board cell identity — index into `JKBoardGraph.cells`.
public typealias CellID = Int

// MARK: - Phase

public enum JKPhase: String, Codable, Hashable {
    case dealing
    case playing
    case finished
}

// MARK: - Team

public enum JKTeam: String, Codable, Hashable {
    /// Seats 0 + 2.
    case a
    /// Seats 1 + 3.
    case b

    static func of(seat: SeatID) -> JKTeam {
        (seat % 2 == 0) ? .a : .b
    }

    /// The partner seat for a given seat in the default 4-player setup.
    static func partner(of seat: SeatID) -> SeatID {
        (seat + 2) % 4
    }
}

// MARK: - Direction

public enum JKDirection: String, Codable, Hashable {
    /// Dealer's left starts, play clockwise (Jawaker Basic default).
    case cw
    /// Dealer's right starts, play counter-clockwise (CatsAtCards / community).
    case ccw
}
