//
//  JKBoardGraphTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Pure topology tests. No state, no moves — just the board graph
//  invariants.
//

import XCTest
@testable import Tokiyo_Casino

final class JKBoardGraphTests: XCTestCase {

    func testDefault72CellBoard_hasExpectedShape() {
        let g = JKBoardGraph()
        XCTAssertEqual(g.trackCells.count, 72)
        XCTAssertEqual(g.cellsPerQuadrant, 18)
        XCTAssertEqual(g.safeCells.count, 16)
        XCTAssertEqual(g.homePockets.count, 4)
    }

    func testEachSeatHasOneBaseAndOneSafeGate() {
        let g = JKBoardGraph()
        var bases = Set<CellID>()
        var gates = Set<CellID>()
        for seat in 0..<4 {
            XCTAssertNotNil(g.baseCell[seat])
            XCTAssertNotNil(g.safeGateCell[seat])
            bases.insert(g.baseCell[seat]!)
            gates.insert(g.safeGateCell[seat]!)
            XCTAssertEqual(g.safeLane[seat]?.count, 4)
        }
        XCTAssertEqual(bases.count, 4, "Base cells must be distinct per seat")
        XCTAssertEqual(gates.count, 4, "Safe gates must be distinct per seat")
    }

    func testBaseAndGateAreAdjacent() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            // gate is one step CCW from base
            let prev = g.next(from: g.baseCell[seat]!, direction: .ccw)
            XCTAssertEqual(prev, g.safeGateCell[seat])
        }
    }

    func testWalkAroundTheLoopReturnsToStart() {
        let g = JKBoardGraph()
        let path = g.walk(from: 0, steps: 72, direction: .cw)
        XCTAssertEqual(path.count, 72)
        XCTAssertEqual(path.last, 0)
    }

    func testWalkBackwardOneStepFromBaseHitsGate() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            let path = g.walk(from: g.baseCell[seat]!, steps: 1, direction: .ccw)
            XCTAssertEqual(path, [g.safeGateCell[seat]!])
        }
    }

    func testDistanceToSafeGate_isZeroAtGateAndQuadrantMinusOneAtBase() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            XCTAssertEqual(g.distanceToSafeGate(from: g.safeGateCell[seat]!,
                                                for: seat,
                                                direction: .cw), 0)
            XCTAssertEqual(g.distanceToSafeGate(from: g.baseCell[seat]!,
                                                for: seat,
                                                direction: .cw),
                           g.trackCells.count - 1)
        }
    }
}
