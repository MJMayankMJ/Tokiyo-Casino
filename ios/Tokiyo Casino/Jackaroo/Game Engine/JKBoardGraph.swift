//
//  JKBoardGraph.swift
//  Tokiyo Casino — Jackaroo
//
//  Pure-data board topology. The loop is built procedurally from a
//  single config value (`cellsPerQuadrant`) so the rendering layer can
//  agree on a layout without touching engine code.
//
//  Default 100-cell board: 4 quadrants × 25 cells each. Each player's
//  Base cell sits at the **start** of their quadrant (the first cell
//  the player encounters when walking clockwise from their corner).
//  The Safe gate is two cells **before** the Base, matching the
//  Kerdany-style entry layout while keeping the engine configurable.
//
//  Cell ID layout for the default 100-cell board:
//    Seat 0 quadrant: cells   0..24   (Base = 0,  Safe gate = 98)
//    Seat 1 quadrant: cells  25..49   (Base = 25, Safe gate = 23)
//    Seat 2 quadrant: cells  50..74   (Base = 50, Safe gate = 48)
//    Seat 3 quadrant: cells  75..99   (Base = 75, Safe gate = 73)
//

import Foundation

public enum JKCellKind: Codable, Hashable {
    case track
    case base(owner: SeatID)
    case safeGate(owner: SeatID)
    case safe(owner: SeatID, lane: Int)
    case home(owner: SeatID, slot: Int)
}

public struct JKBoardGraph: Codable {
    public let cellsPerQuadrant: Int
    public let safeGateOffsetFromBase: Int
    public let trackCells: [JKCellKind]                // length = 4 * cellsPerQuadrant
    public let baseCell: [SeatID: CellID]
    public let safeGateCell: [SeatID: CellID]
    public let safeLane: [SeatID: [CellID]]            // 4 cells per seat, virtual IDs in `safeCells`
    public let safeCells: [JKCellKind]                 // 16 virtual cells (4 per seat)
    public let homePockets: [SeatID: [JKCellKind]]     // 4 per seat (virtual)

    public init(cellsPerQuadrant: Int = 25,
                safeGateOffsetFromBase: Int = 2) {
        precondition(cellsPerQuadrant >= 6, "Quadrant must be wide enough for Base + safe gate spacing")
        precondition(safeGateOffsetFromBase >= 1 && safeGateOffsetFromBase < cellsPerQuadrant,
                     "Safe gate offset must stay inside the previous quadrant")
        self.cellsPerQuadrant = cellsPerQuadrant
        self.safeGateOffsetFromBase = safeGateOffsetFromBase

        let loopSize = cellsPerQuadrant * 4

        // Build the track ring. Base cells live at the **first** cell of
        // each quadrant (so seat 0 Base = 0, seat 1 Base = quadrant, etc.).
        // The safe-gate cell sits just before that base, in the previous
        // quadrant. The default offset is two cells.
        var track = [JKCellKind](repeating: .track, count: loopSize)
        var base: [SeatID: CellID] = [:]
        var gate: [SeatID: CellID] = [:]
        for seat in 0..<4 {
            let baseID  = seat * cellsPerQuadrant
            let gateID  = (baseID + loopSize - safeGateOffsetFromBase) % loopSize
            base[seat] = baseID
            gate[seat] = gateID
            track[baseID] = .base(owner: seat)
            track[gateID] = .safeGate(owner: seat)
        }
        self.trackCells = track
        self.baseCell = base
        self.safeGateCell = gate

        // Build the safe-lane virtual cells. We index them inside a flat
        // 16-cell array, but expose per-seat lane lookups by lane index
        // (`safe(lane: 0...3)` for each seat).
        var safes = [JKCellKind](); safes.reserveCapacity(16)
        var lane: [SeatID: [CellID]] = [:]
        for seat in 0..<4 {
            var ids: [CellID] = []
            for li in 0..<4 {
                ids.append(safes.count)
                safes.append(.safe(owner: seat, lane: li))
            }
            lane[seat] = ids
        }
        self.safeCells = safes
        self.safeLane = lane

        // Home pockets are pure UI affordance — no path enters or leaves
        // through them — but we still record them so the renderer can
        // place marbles cleanly.
        var homes: [SeatID: [JKCellKind]] = [:]
        for seat in 0..<4 {
            homes[seat] = (0..<4).map { .home(owner: seat, slot: $0) }
        }
        self.homePockets = homes
    }

    // MARK: - Track walking

    /// Next cell along the track in `direction`. Returns `nil` if `from`
    /// is not on the track loop (i.e., for Safe / Home positions).
    public func next(from cell: CellID, direction: JKDirection) -> CellID? {
        guard cell >= 0 && cell < trackCells.count else { return nil }
        let n = trackCells.count
        return direction == .cw
            ? (cell + 1) % n
            : (cell + n - 1) % n
    }

    /// Walk N cells along the track in `direction` and return the
    /// **path** as a list of cell IDs in visit order (NOT including the
    /// starting cell). Used by the resolver and by the legal-move
    /// generator's path-validation walker. Pure geometry — no rule
    /// checks here.
    public func walk(from cell: CellID, steps: Int, direction: JKDirection) -> [CellID] {
        guard steps > 0, cell >= 0 && cell < trackCells.count else { return [] }
        var out: [CellID] = []
        out.reserveCapacity(steps)
        var cur = cell
        for _ in 0..<steps {
            guard let nxt = next(from: cur, direction: direction) else { return out }
            out.append(nxt)
            cur = nxt
        }
        return out
    }

    /// Distance from `start` to `seat`'s Safe gate, walking `direction`.
    /// Returns 0 if `start == gate`. Does **not** consider blockers.
    public func distanceToSafeGate(from start: CellID,
                                   for seat: SeatID,
                                   direction: JKDirection) -> Int {
        guard let gate = safeGateCell[seat] else { return 0 }
        let n = trackCells.count
        let raw = direction == .cw
            ? (gate - start + n) % n
            : (start - gate + n) % n
        return raw
    }
}
