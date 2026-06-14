//
//  JKBoardLayout.swift
//  Tokiyo Casino — Jackaroo
//
//  Circular, Kerdany-style board geometry. This is a clean UIKit
//  recreation: the engine supplies topology, and this file projects it
//  onto a normalized circular canvas without importing external assets.
//

import UIKit

struct JKBoardLayout {

    /// Original view bounds used to compute the board.
    let frame: CGRect

    /// Square board area centered inside `frame`.
    let boardRect: CGRect

    /// Pixel scale from the source SVG's 800x800 coordinate system.
    let svgScale: CGFloat

    /// Center of the board circle.
    let center: CGPoint

    /// Outer board radius.
    let boardRadius: CGFloat

    /// Radius of the 100-cell track ring.
    let trackRadius: CGFloat

    /// Visual diameter of a single track / safe / home hole.
    let cellSize: CGFloat

    /// Visual radius of a single track hole.
    let cellRadius: CGFloat

    /// Marble view size. `JKMarbleView` draws its body inset by 10%,
    /// so this yields an SVG-style 8-unit marble radius.
    let marbleSize: CGFloat

    /// Total cells per quadrant.
    let cellsPerQuadrant: Int

    /// Center of every track cell, indexed by CellID.
    let trackCentres: [CGPoint]

    /// Per-seat safe-lane centres. `safeCentres[seat][laneIndex]`.
    /// laneIndex 0 = closest to the gate, 3 = deepest.
    let safeCentres: [[CGPoint]]

    /// Per-seat home pocket centres. `homeCentres[seat][slot]`.
    let homeCentres: [[CGPoint]]

    /// Per-seat rounded-box bounds around each 2x2 home cluster.
    let homeRects: [CGRect]

    /// Per-seat board labels near the home boxes.
    let homeLabelPoints: [CGPoint]

    /// Center rect used for the Card Pile + Fire Pile area.
    let centerRect: CGRect

    // MARK: - Init

    init(frame: CGRect, cellsPerQuadrant: Int = 25) {
        precondition(frame.width > 0 && frame.height > 0)
        precondition(cellsPerQuadrant >= 8)

        self.frame = frame
        self.cellsPerQuadrant = cellsPerQuadrant

        let board = JKBoardLayout.squared(in: frame)
        self.boardRect = board

        let side = board.width
        let scale = side / 800
        self.svgScale = scale
        let center = CGPoint(x: board.midX, y: board.midY)
        self.center = center
        self.boardRadius = 398 * scale
        self.trackRadius = 312 * scale
        self.cellRadius = 9.25 * scale
        self.cellSize = cellRadius * 2
        self.marbleSize = 20 * scale

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: board.minX + side * x,
                    y: board.minY + side * y)
        }

        let loopSize = cellsPerQuadrant * 4
        var track: [CGPoint] = []
        track.reserveCapacity(loopSize)
        for cell in 0..<loopSize {
            let t = CGFloat(cell) / CGFloat(loopSize)
            let angle = t * CGFloat.pi * 2 - CGFloat.pi / 2
            track.append(CGPoint(
                x: center.x + cos(angle) * trackRadius,
                y: center.y + sin(angle) * trackRadius
            ))
        }
        self.trackCentres = track

        let safeRadii = [240, 200, 162, 124].map { CGFloat($0) * scale }
        let safeAngles: [CGFloat] = [
            -CGFloat.pi / 2,
             0,
             CGFloat.pi / 2,
             CGFloat.pi
        ]
        var safes: [[CGPoint]] = Array(repeating: [], count: 4)
        for seat in 0..<4 {
            let angle = safeAngles[seat]
            safes[seat] = safeRadii.map { radius in
                CGPoint(x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius)
            }
        }
        self.safeCentres = safes

        let homeCenters = [
            point(0.500, 0.055),
            point(0.945, 0.500),
            point(0.500, 0.945),
            point(0.055, 0.500)
        ]
        let homeOffsets = [
            CGPoint(x: -0.020 * side, y: -0.014 * side),
            CGPoint(x:  0.020 * side, y: -0.014 * side),
            CGPoint(x: -0.020 * side, y:  0.014 * side),
            CGPoint(x:  0.020 * side, y:  0.014 * side)
        ]

        let homeBoxSize = CGSize(width: 68 * scale, height: 50 * scale)
        var homes: [[CGPoint]] = Array(repeating: [], count: 4)
        var boxes: [CGRect] = []
        boxes.reserveCapacity(4)
        for seat in 0..<4 {
            homes[seat] = homeOffsets.map { offset in
                CGPoint(x: homeCenters[seat].x + offset.x,
                        y: homeCenters[seat].y + offset.y)
            }
            boxes.append(CGRect(
                x: homeCenters[seat].x - homeBoxSize.width / 2,
                y: homeCenters[seat].y - homeBoxSize.height / 2,
                width: homeBoxSize.width,
                height: homeBoxSize.height
            ))
        }
        self.homeCentres = homes
        self.homeRects = boxes

        self.homeLabelPoints = [
            point(0.500, 0.0975),
            point(0.945, 0.4600),
            point(0.500, 0.9025),
            point(0.055, 0.4600)
        ]

        let centerSide = 116 * scale
        self.centerRect = CGRect(
            x: center.x - centerSide / 2,
            y: center.y - centerSide / 2,
            width: centerSide,
            height: centerSide
        )
    }

    // MARK: - Query

    func point(for position: JKPosition, owner: SeatID) -> CGPoint? {
        switch position {
        case .home(let slot):
            guard owner >= 0, owner < homeCentres.count else { return nil }
            guard slot >= 0, slot < homeCentres[owner].count else { return nil }
            return homeCentres[owner][slot]
        case .track(let id):
            return point(forTrack: id)
        case .safe(let lane):
            guard owner >= 0, owner < safeCentres.count else { return nil }
            guard lane >= 0, lane < safeCentres[owner].count else { return nil }
            return safeCentres[owner][lane]
        }
    }

    func point(forTrack cell: CellID) -> CGPoint? {
        guard cell >= 0, cell < trackCentres.count else { return nil }
        return trackCentres[cell]
    }

    // MARK: - Helpers

    static func squared(in r: CGRect) -> CGRect {
        let side = min(r.width, r.height)
        return CGRect(
            x: r.minX + (r.width - side) / 2,
            y: r.minY + (r.height - side) / 2,
            width: side,
            height: side
        )
    }

    static func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

}
