//
//  PokerTableViewLayout.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension PokerTableView {
    
    // MARK: - Layout
    func setupView() {
        backgroundColor = UIColor(red: 0.08, green: 0.25, blue: 0.08, alpha: 1.0)
        
        // Table oval background
        setupTableOval()
        
        // Phase label (moved higher to avoid overlap)
        phaseLabel.text = "Waiting..."
        phaseLabel.textColor = .white
        phaseLabel.font = .systemFont(ofSize: 18, weight: .bold)
        phaseLabel.textAlignment = .center
        phaseLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        phaseLabel.layer.cornerRadius = 8
        phaseLabel.layer.masksToBounds = true
        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(phaseLabel)
        
        // Pot label (positioned better)
        potLabel.text = "Pot: $0"
        potLabel.textColor = .white
        potLabel.font = .boldSystemFont(ofSize: 22)
        potLabel.textAlignment = .center
        potLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        potLabel.layer.cornerRadius = 12
        potLabel.layer.masksToBounds = true
        potLabel.layer.borderWidth = 2
        potLabel.layer.borderColor = UIColor.yellow.cgColor
        potLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(potLabel)
        
        // Setup community cards area (better spacing)
        setupCommunityCards()
        
        NSLayoutConstraint.activate([
            // Phase label
            phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            phaseLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            phaseLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            phaseLabel.heightAnchor.constraint(equalToConstant: 32),
            
            // Pot label
            potLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            potLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            potLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            potLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func setupTableOval() {
        // Create a more realistic poker table background
        let ovalLayer = CAShapeLayer()
        let tableRect = CGRect(x: 30, y: 80, width: bounds.width - 60, height: bounds.height - 240)
        let path = UIBezierPath(ovalIn: tableRect)
        ovalLayer.path = path.cgPath
        ovalLayer.fillColor = UIColor(red: 0.12, green: 0.35, blue: 0.12, alpha: 1.0).cgColor
        ovalLayer.strokeColor = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0).cgColor
        ovalLayer.lineWidth = 12
        ovalLayer.shadowColor = UIColor.black.cgColor
        ovalLayer.shadowOffset = CGSize(width: 0, height: 6)
        ovalLayer.shadowOpacity = 0.6
        ovalLayer.shadowRadius = 15
        layer.insertSublayer(ovalLayer, at: 0)
    }
    
    func setupCommunityCards() {
        // Clear existing community card views
        communityCardViews.forEach { $0.removeFromSuperview() }
        communityCardViews.removeAll()
        
        let cardWidth: CGFloat = 60
        let cardHeight: CGFloat = 84
        let cardSpacing: CGFloat = 8
        
        for i in 0..<5 {
            let cardView = CardView()
            cardView.translatesAutoresizingMaskIntoConstraints = false
            cardView.isHidden = true
            addSubview(cardView)
            communityCardViews.append(cardView)
            
            let xOffset = CGFloat((i - 2)) * (cardWidth + cardSpacing)
            
            NSLayoutConstraint.activate([
                cardView.widthAnchor.constraint(equalToConstant: cardWidth),
                cardView.heightAnchor.constraint(equalToConstant: cardHeight),
                cardView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 20),
                cardView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: xOffset)
            ])
        }
    }
    
    func setupPlayers(_ players: [Player], dealerIndex: Int) {
        self.players = players
        
        // Remove existing player views
        playerViews.forEach { $0.removeFromSuperview() }
        playerViews.removeAll()
        
        // Create new player views with proper sizing
        for (index, player) in players.enumerated() {
            let playerView = PlayerView()
            playerView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(playerView)
            playerViews.append(playerView)
            
            // Size based on player type
            let size = player.isHuman ? humanPlayerSize : aiPlayerSize
            
            NSLayoutConstraint.activate([
                playerView.widthAnchor.constraint(equalToConstant: size.width),
                playerView.heightAnchor.constraint(equalToConstant: size.height)
            ])
            
            playerView.configureWith(player: player, isDealer: index == dealerIndex)
        }
        
        // Position players after layout
        DispatchQueue.main.async {
            self.updatePlayerPositions()
        }
    }
    
    func updatePlayerPositions() {
        for (index, playerView) in playerViews.enumerated() {
            guard index < playerPositions.count else { continue }
            
            let position = playerPositions[index]
            let xPosition = bounds.width * position.x
            var yPosition = bounds.height * position.y
            
            // Apply extra shift only to the human player (index 0)
            if index == 0 {
                yPosition += humanPlayerVerticalShift
            }
            
            playerView.center = CGPoint(x: xPosition, y: yPosition)
        }
    }
    
    /// Adjusts the human player view position when betting controls appear/disappear.
    /// - Parameter shiftUp: If true, shifts player up to make room for betting controls.
    func adjustHumanPlayerPosition(shiftUp: Bool) {
        guard !playerViews.isEmpty else { return }
        
        // Choose how much to move (tune this value if needed)
        let shiftAmount: CGFloat = -180   // negative = move up
        
        humanPlayerVerticalShift = shiftUp ? shiftAmount : 0
        
        // Animate the movement smoothly
        UIView.animate(withDuration: 0.25) {
            self.updatePlayerPositions()
            self.layoutIfNeeded()
        }
        
        print("PokerTableView: \(shiftUp ? "Shifted human player up" : "Reset human player position")")
    }
}
