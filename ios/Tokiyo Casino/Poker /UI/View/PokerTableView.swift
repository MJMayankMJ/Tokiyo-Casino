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
    var designFrame: CGRect = .zero
    var designScale: CGFloat = 1

    // Round-end overlay banner (live only between showdown and the next hand)
    var resultBanner: RoundResultBanner?

    // Layout coordinates for 6-max seats, expressed as [0..1] across the
    // prototype's 360×480 table container, not the inset oval felt.
    let playerPositions: [CGPoint] = [
        CGPoint(x: 180.0 / 360.0, y: 490.0 / 480.0), // 0 — Human wrapper bottom: -10
        CGPoint(x:  44.0 / 360.0, y: 388.0 / 480.0), // 1 — bottom-left
        CGPoint(x:  22.0 / 360.0, y: 200.0 / 480.0), // 2 — mid-left
        CGPoint(x: 180.0 / 360.0, y:  50.0 / 480.0), // 3 — top center
        CGPoint(x: 338.0 / 360.0, y: 200.0 / 480.0), // 4 — mid-right
        CGPoint(x: 316.0 / 360.0, y: 388.0 / 480.0)  // 5 — bottom-right
    ]

    let humanPlayerBaseSize = CGSize(width: 360, height: 150)
    let aiPlayerBaseSize = CGSize(width: 96, height: 114)

    // Bet pill positions (felt-relative). For the hero this sits above the
    // hero zone but inside the felt.
    let betPillPositions: [CGPoint] = [
        CGPoint(x: 180.0 / 360.0, y: 384.0 / 480.0), // hero bet is rendered in HeroZone
        CGPoint(x: 108.0 / 360.0, y: 338.0 / 480.0), // bottom-left
        CGPoint(x:  82.0 / 360.0, y: 200.0 / 480.0), // mid-left
        CGPoint(x: 180.0 / 360.0, y: 108.0 / 480.0), // top
        CGPoint(x: 278.0 / 360.0, y: 200.0 / 480.0), // mid-right
        CGPoint(x: 252.0 / 360.0, y: 338.0 / 480.0)  // bottom-right
    ]

    let cardSides: [PlayerView.TuckedCardSide] = [
        .right, .right, .right, .right, .left, .left
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
