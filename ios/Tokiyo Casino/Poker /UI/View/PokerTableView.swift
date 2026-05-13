//
//  PokerTableView.swift
//  Poker
//
//  Redesigned felt container — pot pill, community cards, and seats are
//  positioned over a soft cream felt instead of the green oval baize.
//

import UIKit

class PokerTableView: UIView {

    // MARK: - Public properties (preserve existing API surface)
    var playerViews: [PlayerView] = []
    var communityCardViews: [CardView] = []
    let potLabel = UILabel()        // kept for source-compat; not displayed
    let phaseLabel = UILabel()      // kept for source-compat; not displayed
    let tableImageView = UIImageView() // unused but retained
    var humanPlayerVerticalShift: CGFloat = 0

    // Felt + adornments
    let feltView = UIView()
    let feltInnerBorder = UIView()
    let potPill = PotPillView()
    let communityRow = UIStackView()
    var betPills: [Int: BetPillView] = [:] // playerId -> pill

    // Layout coordinates for 6-max seats, expressed as [0..1] across the
    // *felt* rect (not the tableView). Mirrors the Claude Design seat layout
    // (felt is 360×480 in the design — coords below come from those pixels).
    let playerPositions: [CGPoint] = [
        CGPoint(x: 0.50, y: 1.02),  // 0 — Human (overhangs felt's bottom)
        CGPoint(x: 0.12, y: 0.81),  // 1 — bottom-left
        CGPoint(x: 0.06, y: 0.42),  // 2 — mid-left
        CGPoint(x: 0.50, y: 0.10),  // 3 — top center
        CGPoint(x: 0.94, y: 0.42),  // 4 — mid-right
        CGPoint(x: 0.88, y: 0.81)   // 5 — bottom-right
    ]

    let humanPlayerSize = CGSize(width: 240, height: 150)
    let aiPlayerSize = CGSize(width: 110, height: 110)

    // Bet pill positions (felt-relative). For the hero this sits above the
    // hero zone but inside the felt.
    let betPillPositions: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.80),  // 0 — hero
        CGPoint(x: 0.30, y: 0.70),  // 1 — bottom-left
        CGPoint(x: 0.23, y: 0.42),  // 2 — mid-left
        CGPoint(x: 0.50, y: 0.22),  // 3 — top
        CGPoint(x: 0.77, y: 0.42),  // 4 — mid-right
        CGPoint(x: 0.70, y: 0.70)   // 5 — bottom-right
    ]

    var players: [Player] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFelt()
        updatePlayerPositions()
        updateBetPillPositions()
    }
}
