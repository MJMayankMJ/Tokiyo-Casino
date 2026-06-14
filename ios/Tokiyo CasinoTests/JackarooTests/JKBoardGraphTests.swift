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

    func testDefault100CellBoard_hasExpectedShape() {
        let g = JKBoardGraph()
        XCTAssertEqual(g.trackCells.count, 100)
        XCTAssertEqual(g.cellsPerQuadrant, 25)
        XCTAssertEqual(g.safeGateOffsetFromBase, 2)
        XCTAssertEqual(g.safeCells.count, 16)
        XCTAssertEqual(g.homePockets.count, 4)
    }

    func testEachSeatHasExpectedBaseAndSafeGate() {
        let g = JKBoardGraph()
        XCTAssertEqual(g.baseCell[0], 0)
        XCTAssertEqual(g.baseCell[1], 25)
        XCTAssertEqual(g.baseCell[2], 50)
        XCTAssertEqual(g.baseCell[3], 75)
        XCTAssertEqual(g.safeGateCell[0], 98)
        XCTAssertEqual(g.safeGateCell[1], 23)
        XCTAssertEqual(g.safeGateCell[2], 48)
        XCTAssertEqual(g.safeGateCell[3], 73)

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

    func testBaseAndGateAreTwoStepsApart() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            let path = g.walk(from: g.baseCell[seat]!, steps: 2, direction: .ccw)
            XCTAssertEqual(path.last, g.safeGateCell[seat])
        }
    }

    func testWalkAroundTheLoopReturnsToStart() {
        let g = JKBoardGraph()
        let path = g.walk(from: 0, steps: 100, direction: .cw)
        XCTAssertEqual(path.count, 100)
        XCTAssertEqual(path.last, 0)
    }

    func testWalkBackwardTwoStepsFromBaseHitsGate() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            let path = g.walk(from: g.baseCell[seat]!, steps: 2, direction: .ccw)
            XCTAssertEqual(path.last, g.safeGateCell[seat])
        }
    }

    func testDistanceToSafeGate_isZeroAtGateAndLoopMinusTwoAtBase() {
        let g = JKBoardGraph()
        for seat in 0..<4 {
            XCTAssertEqual(g.distanceToSafeGate(from: g.safeGateCell[seat]!,
                                                for: seat,
                                                direction: .cw), 0)
            XCTAssertEqual(g.distanceToSafeGate(from: g.baseCell[seat]!,
                                                for: seat,
                                                direction: .cw),
                           g.trackCells.count - 2)
        }
    }
}
