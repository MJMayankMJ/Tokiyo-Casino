//
//  JKBoardViewRenderingTests.swift
//  Tokiyo CasinoTests — Jackaroo
//
//  Lightweight UI smoke tests for the circular Jackaroo board renderer.
//

import UIKit
import XCTest
@testable import Tokiyo_Casino

final class JKBoardViewRenderingTests: XCTestCase {

    func testBoardRenderingProducesNonBlankPortraitImage() {
        let graph = JKBoardGraph()
        let board = JKBoardView(graph: graph)
        board.frame = CGRect(x: 0, y: 0, width: 390, height: 520)
        board.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: board.bounds)
        let image = renderer.image { context in
            board.layer.render(in: context.cgContext)
        }

        XCTAssertGreaterThan(nonZeroPixelByteCount(in: image), 4_000)
    }

    func testHitTargetFindsRepresentativeCells() {
        let graph = JKBoardGraph()
        let board = JKBoardView(graph: graph)
        board.frame = CGRect(x: 0, y: 0, width: 390, height: 520)
        board.layoutIfNeeded()

        let layout = JKBoardLayout(frame: board.bounds,
                                   cellsPerQuadrant: graph.cellsPerQuadrant)

        XCTAssertEqual(board.hitTarget(at: layout.trackCentres[0]), .track(0))
        XCTAssertEqual(board.hitTarget(at: layout.safeCentres[1][2]), .safe(1, 2))
        XCTAssertEqual(board.hitTarget(at: layout.homeCentres[2][3]), .home(2, 3))
        XCTAssertEqual(board.hitTarget(at: layout.center), .center)
    }

    private func nonZeroPixelByteCount(in image: UIImage) -> Int {
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else {
            return 0
        }
        let length = CFDataGetLength(data)
        var count = 0
        var index = 0
        while index < length {
            if bytes[index] != 0 {
                count += 1
            }
            index += 1
        }
        return count
    }
}
