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
    private var playerViews: [PlayerView] = []
    private var communityCardViews: [CardView] = []
    private let potLabel = UILabel()
    private let phaseLabel = UILabel()
    private let tableImageView = UIImageView()
    private var humanPlayerVerticalShift: CGFloat = 0
    
    // Improved layout positions for players (6-max) - avoiding overlaps
    private let playerPositions: [CGPoint] = [
        CGPoint(x: 0.5, y: 0.88),   // Player (bottom center) - Human player
        CGPoint(x: 0.12, y: 0.68),  // Player 1 (left middle)
        CGPoint(x: 0.12, y: 0.32),  // Player 2 (top left)
        CGPoint(x: 0.5, y: 0.12),   // Player 3 (top center)
        CGPoint(x: 0.88, y: 0.32),  // Player 4 (top right)
        CGPoint(x: 0.88, y: 0.68)   // Player 5 (right middle)
    ]
    
    // Player view sizes - larger for human
    private let humanPlayerSize = CGSize(width: 160, height: 160)
    private let aiPlayerSize = CGSize(width: 120, height: 100)
    
    private var players: [Player] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
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
    
    private func setupTableOval() {
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
    
    private func setupCommunityCards() {
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
    
    private func updatePlayerPositions() {
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

   
    func updatePlayers(_ players: [Player], dealerIndex: Int) {
        self.players = players
        
        print("PokerTableView: updatePlayers called with \(players.count) players")
        
        for (index, player) in players.enumerated() {
            if index < playerViews.count {
                playerViews[index].configureWith(player: player, isDealer: index == dealerIndex)
                playerViews[index].showBet(player.currentBet)
            }
        }
    }
    
    func showCommunityCards(_ cards: [Card]) {
        print("Showing \(cards.count) community cards")
        
        for (index, card) in cards.enumerated() {
            if index < communityCardViews.count {
                let cardView = communityCardViews[index]
                cardView.setCard(card, faceUp: true)
                cardView.isHidden = false
                
                // Enhanced animation with better timing
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: .pi)
                
                UIView.animate(
                    withDuration: 0.6,
                    delay: Double(index) * 0.2,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0.8,
                    options: [.curveEaseOut]
                ) {
                    cardView.alpha = 1
                    cardView.transform = .identity
                }
            }
        }
    }
    
    func updatePot(_ amount: Int) {
        potLabel.text = "Pot: $\(amount)"
        
        // Enhanced pot animation
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.potLabel.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.potLabel.transform = .identity
            }
        }
    }
    
    func updatePhase(_ phase: GamePhase) {
        phaseLabel.text = phase.description
        
        // Color based on phase
        switch phase {
        case .waiting:
            phaseLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        case .preFlop:
            phaseLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
        case .flop:
            phaseLabel.backgroundColor = UIColor.green.withAlphaComponent(0.6)
        case .turn:
            phaseLabel.backgroundColor = UIColor.orange.withAlphaComponent(0.6)
        case .river:
            phaseLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
        case .showdown:
            phaseLabel.backgroundColor = UIColor.purple.withAlphaComponent(0.6)
        }
        
        // Animation
        UIView.animate(withDuration: 0.4) {
            self.phaseLabel.alpha = 0.4
        } completion: { _ in
            UIView.animate(withDuration: 0.4) {
                self.phaseLabel.alpha = 1.0
            }
        }
    }
    
    func showPlayerAction(_ player: Player, action: PlayerAction) {
        for (index, p) in players.enumerated() where p.id == player.id {
            if index < playerViews.count {
                playerViews[index].showAction(action)
                playerViews[index].showBet(player.currentBet)
            }
        }
    }
    
    func highlightCurrentPlayer(_ player: Player) {
        for (index, p) in players.enumerated() {
            if index < playerViews.count {
                let isCurrent = p.id == player.id
                playerViews[index].setHighlighted(isCurrent)
            }
        }
    }
    
    func showWinner(_ winner: Player) {
        print("PokerTableView: showWinner called for \(winner.name)")
        
        // Find and animate the winner
        for (index, p) in players.enumerated() where p.id == winner.id {
            if index < playerViews.count {
                print("PokerTableView: Found winner at index \(index)")
                playerViews[index].showWinAnimation()
            }
        }
    }
    
//    func revealAllCards() {
//        print("Revealing all player cards - Total players: \(playerViews.count)")
//        
//        for (index, playerView) in playerViews.enumerated() {
//            // Add staggered delays for dramatic effect
//            let delay = Double(index) * 0.3
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//                playerView.revealCards()
//            }
//        }
//    }
    

    func revealAllCards() {
        print("Revealing all player cards - Total players: \(playerViews.count)")
        
        for (index, playerView) in playerViews.enumerated() {
            let delay = Double(index) * 0.3
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playerView.revealCards()
            }
        }
    }

    
    
    func clearTable() {
        // Hide and reset community cards
        for cardView in communityCardViews {
            UIView.animate(withDuration: 0.2) {
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            } completion: { _ in
                cardView.isHidden = true
                cardView.alpha = 1
                cardView.transform = .identity
            }
        }
        
        // Reset pot
        potLabel.text = "Pot: $0"
        
        // Reset phase
        phaseLabel.text = "Waiting..."
        phaseLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        
        // Reset player highlights
        for playerView in playerViews {
            playerView.setHighlighted(false)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updatePlayerPositions()
    }
}

// MARK: - PokerTableView Extension for Dynamic Player Positioning
extension PokerTableView {
    
    /// Adjusts the human player view position when betting controls appear/disappear.
    /// - Parameter shiftUp: If true, shifts player up to make room for betting controls.
    func adjustHumanPlayerPosition(shiftUp: Bool) {
        guard !playerViews.isEmpty else { return }
        
        // Choose how much to move (tune this value if needed)
        let shiftAmount: CGFloat = -100   // negative = move up
        
        humanPlayerVerticalShift = shiftUp ? shiftAmount : 0
        
        // Animate the movement smoothly
        UIView.animate(withDuration: 0.25) {
            self.updatePlayerPositions()
            self.layoutIfNeeded()
        }
        
        print("PokerTableView: \(shiftUp ? "Shifted human player up" : "Reset human player position")")
    }
}
