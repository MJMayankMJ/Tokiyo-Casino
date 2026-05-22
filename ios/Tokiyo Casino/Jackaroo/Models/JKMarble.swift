//
//  JKMarble.swift
//  Tokiyo Casino — Jackaroo
//
//  A marble is always in one of three places: its owner's Home pocket,
//  on a specific track cell (which may happen to be its owner's Base
//  cell), or in its owner's Safe lane. There is intentionally no
//  separate `.base` position — that would prevent us from representing
//  an opponent occupying your Base cell. The `JKBoardGraph` is the
//  source of truth for which CellID is which player's Base cell.
//

import Foundation

public enum JKPosition: Codable, Hashable {
    /// Off-track. `slot` 0…3 identifies which Home pocket the marble
    /// is sitting in — purely for visual layout; semantically all four
    /// Home slots are equivalent.
    case home(slot: Int)

    /// Any cell on the loop. Includes Base cells and Safe gate cells —
    /// those are distinguished by `JKBoardGraph.cells[cell]`.
    case track(CellID)

    /// Inside owner's Safe lane. `lane` is 0…3 where 0 = nearest the
    /// gate and 3 = deepest cell.
    case safe(lane: Int)
}

public struct JKMarble: Codable, Hashable {
    public let id: MarbleID
    public let owner: SeatID
    public var position: JKPosition

    public init(id: MarbleID, owner: SeatID, position: JKPosition) {
        self.id = id
        self.owner = owner
        self.position = position
    }

    /// Convenience — `id / 4` is the owner per the canonical layout.
    static func ownerOf(_ id: MarbleID) -> SeatID { id / 4 }
}
