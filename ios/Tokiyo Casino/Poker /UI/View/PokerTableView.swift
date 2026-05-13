//
//  PokerTableView.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

// MARK: - Enhanced PokerTableView with Better Positioning
class PokerTableView: UIView {
    
    // MARK: - Properties
    var playerViews: [PlayerView] = []
    var communityCardViews: [CardView] = []
    let potLabel = UILabel()
    let phaseLabel = UILabel()
    let tableImageView = UIImageView()
    var humanPlayerVerticalShift: CGFloat = 0
    
    // Improved layout positions for players (6-max) - avoiding overlaps
    let playerPositions: [CGPoint] = [
        CGPoint(x: 0.5, y: 0.88),   // Player (bottom center) - Human player
        CGPoint(x: 0.12, y: 0.68),  // Player 1 (left middle)
        CGPoint(x: 0.12, y: 0.32),  // Player 2 (top left)
        CGPoint(x: 0.5, y: 0.12),   // Player 3 (top center)
        CGPoint(x: 0.88, y: 0.32),  // Player 4 (top right)
        CGPoint(x: 0.88, y: 0.68)   // Player 5 (right middle)
    ]
    
    // Player view sizes - larger for human
    let humanPlayerSize = CGSize(width: 160, height: 160)
    let aiPlayerSize = CGSize(width: 120, height: 100)
    
    var players: [Player] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayerPositions()
    }
}
