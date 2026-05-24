//
//  JKBoardLayout.swift
//  Tokiyo Casino — Jackaroo
//
//  Octagonal board geometry matching a real wooden Jackaroo board.
//
//  Outline: a regular-ish octagon — 4 long edges (top, right, bottom,
//  left) and 4 short diagonal "corner-cut" edges. The playable holes do
//  not sit on those corner cuts. Instead, the 72-cell loop is projected
//  as a Jackaroo-style inner path: short diagonal connector runs near
//  each corner plus one straight row along each player's side.
//
//  Cell distribution per quadrant:
//    Quadrant 0: top row    (seat 0)
//    Quadrant 1: right row  (seat 1)
//    Quadrant 2: bottom row (seat 2)
//    Quadrant 3: left row   (seat 3)
//
//  Each seat's home pocket is a 2×2 marble cluster outside the rhombus,
//  centered near that player's board edge. The safe lane is a short
//  4-hole branch breaking inward from the middle of the player's row.
//

import UIKit

struct JKBoardLayout {

    /// Edge-to-edge size of the board area.
    let frame: CGRect

    /// Visual diameter of a single track / safe / home hole.
    let cellSize: CGFloat

    /// Total cells per quadrant (one player-side path).
    let cellsPerQuadrant: Int

    /// Cells placed along the straight row inside each quadrant.
    let cellsPerLongEdge: Int

    /// Cells placed along octagon corner cuts. Kept as a diagnostic
    /// value so callers can assert that those cuts remain empty.
    let cellsPerCornerCut: Int

    /// 8 vertex positions of the felt outline, clockwise from the
    /// **left end of the top edge** (v0).
    let octagonVertices: [CGPoint]

    /// Centre of every track cell, indexed by CellID.
    let trackCentres: [CGPoint]

    /// Per-seat safe-lane centres. `safeCentres[seat][laneIndex]`.
    /// laneIndex 0 = closest to the gate, 3 = deepest (closest to centre).
    let safeCentres: [[CGPoint]]

    /// Per-seat home pocket centres. `homeCentres[seat][slot]`.
    let homeCentres: [[CGPoint]]

    /// Centre rect used for the Card Pile + Fire Pile area.
    let centerRect: CGRect

    // MARK: - Init

    init(frame: CGRect, cellsPerQuadrant: Int = 18) {
        precondition(frame.width > 0 && frame.height > 0)
        precondition(cellsPerQuadrant >= 8)
        self.frame = frame
        self.cellsPerQuadrant = cellsPerQuadrant

        // Each quadrant is one player-side path: diagonal approach,
        // straight row, diagonal exit. The clipped octagon corners stay
        // empty, matching physical Jackaroo boards.
        let cellsPerCornerCut = 0
        let diagonalCellsPerEnd = min(
            max(4, Int((CGFloat(cellsPerQuadrant) * 0.28).rounded())),
            (cellsPerQuadrant - 2) / 2
        )
        let cellsPerLongEdge = cellsPerQuadrant - diagonalCellsPerEnd * 2
        precondition(cellsPerLongEdge > 0)
        self.cellsPerCornerCut = cellsPerCornerCut
        self.cellsPerLongEdge = cellsPerLongEdge

        // Square the playable area so the octagon is regular.
        let board = JKBoardLayout.squared(in: frame)
        let outer = board.insetBy(dx: board.width * 0.04, dy: board.width * 0.04)

        // The outline still has real clipped corners, but they are now
        // mostly empty wood/felt instead of carrying track holes.
        let cornerInset = outer.width * 0.18

        let v0 = CGPoint(x: outer.minX + cornerInset, y: outer.minY)
        let v1 = CGPoint(x: outer.maxX - cornerInset, y: outer.minY)
        let v2 = CGPoint(x: outer.maxX,               y: outer.minY + cornerInset)
        let v3 = CGPoint(x: outer.maxX,               y: outer.maxY - cornerInset)
        let v4 = CGPoint(x: outer.maxX - cornerInset, y: outer.maxY)
        let v5 = CGPoint(x: outer.minX + cornerInset, y: outer.maxY)
        let v6 = CGPoint(x: outer.minX,               y: outer.maxY - cornerInset)
        let v7 = CGPoint(x: outer.minX,               y: outer.minY + cornerInset)
        self.octagonVertices = [v0, v1, v2, v3, v4, v5, v6, v7]

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: outer.minX + outer.width * x,
                    y: outer.minY + outer.height * y)
        }

        // Twelve anchors trace the real-board rhythm:
        // diagonal connector → straight side row → diagonal connector.
        // The row anchors sit inward from the octagon's long edges, while
        // connector anchors sit closer to the board corners without
        // falling onto the clipped corner cuts.
        let a0  = point(0.15, 0.15)
        let a1  = point(0.34, 0.23)
        let a2  = point(0.66, 0.23)
        let a3  = point(0.85, 0.15)
        let a4  = point(0.77, 0.34)
        let a5  = point(0.77, 0.66)
        let a6  = point(0.85, 0.85)
        let a7  = point(0.66, 0.77)
        let a8  = point(0.34, 0.77)
        let a9  = point(0.15, 0.85)
        let a10 = point(0.23, 0.66)
        let a11 = point(0.23, 0.34)

        func segmentStride(from a: CGPoint, to b: CGPoint, count: Int) -> CGFloat {
            guard count > 0 else { return .greatestFiniteMagnitude }
            return hypot(b.x - a.x, b.y - a.y) / CGFloat(count + 1)
        }

        let diagonalStride = min(
            segmentStride(from: a0, to: a1, count: diagonalCellsPerEnd),
            segmentStride(from: a2, to: a3, count: diagonalCellsPerEnd),
            segmentStride(from: a3, to: a4, count: diagonalCellsPerEnd),
            segmentStride(from: a5, to: a6, count: diagonalCellsPerEnd)
        )
        let straightStride = min(
            segmentStride(from: a1, to: a2, count: cellsPerLongEdge),
            segmentStride(from: a4, to: a5, count: cellsPerLongEdge)
        )

        // Keep holes readable even though the diagonal connector runs are
        // shorter than the straight side rows.
        self.cellSize = max(
            min(diagonalStride, straightStride) * 0.78,
            outer.width * 0.024
        )

        // Walk a segment using midpoint sampling. This keeps neighbouring
        // segments visually connected without dropping doubled holes
        // directly on top of the anchor joins.
        func placeAlong(from a: CGPoint, to b: CGPoint, count: Int,
                        into arr: inout [CGPoint]) {
            guard count > 0 else { return }
            let dx = b.x - a.x, dy = b.y - a.y
            for i in 0..<count {
                let t = (CGFloat(i) + 0.5) / CGFloat(count)
                arr.append(CGPoint(x: a.x + dx * t, y: a.y + dy * t))
            }
        }

        var centres: [CGPoint] = []
        centres.reserveCapacity(cellsPerQuadrant * 4)
        // Quadrant 0: top side
        placeAlong(from: a0, to: a1, count: diagonalCellsPerEnd, into: &centres)
        placeAlong(from: a1, to: a2, count: cellsPerLongEdge, into: &centres)
        placeAlong(from: a2, to: a3, count: diagonalCellsPerEnd, into: &centres)
        // Quadrant 1: right side
        placeAlong(from: a3, to: a4, count: diagonalCellsPerEnd, into: &centres)
        placeAlong(from: a4, to: a5, count: cellsPerLongEdge, into: &centres)
        placeAlong(from: a5, to: a6, count: diagonalCellsPerEnd, into: &centres)
        // Quadrant 2: bottom side
        placeAlong(from: a6, to: a7, count: diagonalCellsPerEnd, into: &centres)
        placeAlong(from: a7, to: a8, count: cellsPerLongEdge, into: &centres)
        placeAlong(from: a8, to: a9, count: diagonalCellsPerEnd, into: &centres)
        // Quadrant 3: left side
        placeAlong(from: a9, to: a10, count: diagonalCellsPerEnd, into: &centres)
        placeAlong(from: a10, to: a11, count: cellsPerLongEdge, into: &centres)
        placeAlong(from: a11, to: a0, count: diagonalCellsPerEnd, into: &centres)
        self.trackCentres = centres

        let mid = CGPoint(x: outer.midX, y: outer.midY)

        // Side frames, indexed by seat. `outward` points from the
        // rhombus row toward the board edge; `tangent` follows the row.
        let sideFrames: [(mid: CGPoint, tangent: CGPoint, outward: CGPoint)] = [
            (
                mid: CGPoint(x: (a1.x + a2.x) / 2, y: a1.y),
                tangent: CGPoint(x: 1, y: 0),
                outward: CGPoint(x: 0, y: -1)
            ),
            (
                mid: CGPoint(x: a4.x, y: (a4.y + a5.y) / 2),
                tangent: CGPoint(x: 0, y: 1),
                outward: CGPoint(x: 1, y: 0)
            ),
            (
                mid: CGPoint(x: (a7.x + a8.x) / 2, y: a7.y),
                tangent: CGPoint(x: -1, y: 0),
                outward: CGPoint(x: 0, y: 1)
            ),
            (
                mid: CGPoint(x: a10.x, y: (a10.y + a11.y) / 2),
                tangent: CGPoint(x: 0, y: -1),
                outward: CGPoint(x: -1, y: 0)
            ),
        ]

        // Safe lanes — 4 holes branching from the middle of each side
        // toward the centre. They are deliberately short so the centre
        // remains mostly open for the card area.
        let laneStride = cellSize * 1.38
        let laneFirstOffset = cellSize * 1.60
        var safes: [[CGPoint]] = Array(repeating: [], count: 4)
        for seat in 0..<4 {
            let side = sideFrames[seat]
            let inward = CGPoint(x: -side.outward.x, y: -side.outward.y)
            let startX = side.mid.x + inward.x * laneFirstOffset
            let startY = side.mid.y + inward.y * laneFirstOffset
            for li in 0..<4 {
                let s = CGFloat(li) * laneStride
                safes[seat].append(CGPoint(
                    x: startX + inward.x * s,
                    y: startY + inward.y * s
                ))
            }
        }
        self.safeCentres = safes

        // Home pockets — 2×2 grid outside each player's side row, near
        // the middle of the matching board edge. The grid axes are the
        // track tangent and the outward direction.
        let homeStride = cellSize * 1.45
        let homeOffset = cellSize * 2.85
        var homes: [[CGPoint]] = Array(repeating: [], count: 4)
        for seat in 0..<4 {
            let side = sideFrames[seat]
            let tangent = side.tangent
            let outward = side.outward
            let cx = side.mid.x + outward.x * homeOffset
            let cy = side.mid.y + outward.y * homeOffset
            let halfStride = homeStride / 2
            homes[seat] = [
                CGPoint(
                    x: cx - tangent.x * halfStride - outward.x * halfStride,
                    y: cy - tangent.y * halfStride - outward.y * halfStride
                ),
                CGPoint(
                    x: cx + tangent.x * halfStride - outward.x * halfStride,
                    y: cy + tangent.y * halfStride - outward.y * halfStride
                ),
                CGPoint(
                    x: cx - tangent.x * halfStride + outward.x * halfStride,
                    y: cy - tangent.y * halfStride + outward.y * halfStride
                ),
                CGPoint(
                    x: cx + tangent.x * halfStride + outward.x * halfStride,
                    y: cy + tangent.y * halfStride + outward.y * halfStride
                ),
            ]
        }
        self.homeCentres = homes

        // Centre card area — larger and squarely centered, with room
        // left between it and the short safe-lane branches.
        let deepestLaneOffset = laneFirstOffset + CGFloat(3) * laneStride
        let sideLength = a2.x - a1.x
        let rowToCentre = mid.y - a1.y
        let geometricLimit = max(
            outer.width * 0.24,
            (rowToCentre - deepestLaneOffset - cellSize * 1.15) * 2
        )
        let centreSide = min(
            sideLength * 0.82,
            max(outer.width * 0.26, geometricLimit)
        )
        self.centerRect = CGRect(
            x: mid.x - centreSide / 2,
            y: mid.y - centreSide / 2,
            width: centreSide,
            height: centreSide
        )
    }

    // MARK: - Query

    func point(for position: JKPosition, owner: SeatID) -> CGPoint? {
        switch position {
        case .home(let slot):
            guard owner >= 0, owner < 4 else { return nil }
            guard slot >= 0, slot < homeCentres[owner].count else { return nil }
            return homeCentres[owner][slot]
        case .track(let id):
            guard id >= 0, id < trackCentres.count else { return nil }
            return trackCentres[id]
        case .safe(let lane):
            guard owner >= 0, owner < 4 else { return nil }
            guard lane >= 0, lane < safeCentres[owner].count else { return nil }
            return safeCentres[owner][lane]
        }
    }

    func point(forTrack cell: CellID) -> CGPoint? {
        guard cell >= 0, cell < trackCentres.count else { return nil }
        return trackCentres[cell]
    }

    // MARK: - Helpers

    private static func squared(in r: CGRect) -> CGRect {
        let side = min(r.width, r.height)
        return CGRect(
            x: r.minX + (r.width - side) / 2,
            y: r.minY + (r.height - side) / 2,
            width: side,
            height: side
        )
    }
}
