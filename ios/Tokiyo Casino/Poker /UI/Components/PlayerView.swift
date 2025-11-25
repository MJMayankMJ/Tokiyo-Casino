//
//  PlayerView.swift
//  Tokiyo Casino
//
//  Created by Hari's Mac on 25.11.2025.
//

import Foundation
import UIKit

// MARK: - Enhanced Player View with Dynamic Card Sizing
class PlayerView: UIView {
    
    private let nameLabel = UILabel()
    private let chipsLabel = UILabel()
    private let actionLabel = UILabel()
    private let card1View = CardView()
    private let card2View = CardView()
    private let dealerButton = UILabel()
    private let betChipsView = UILabel()
    private let highlightBorder = CAShapeLayer()
    
    private var player: Player?
    private var isHumanPlayer = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.75)
        layer.cornerRadius = 12
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        
        // Setup highlight border
        highlightBorder.fillColor = UIColor.clear.cgColor
        highlightBorder.strokeColor = UIColor.yellow.cgColor
        highlightBorder.lineWidth = 3
        highlightBorder.opacity = 0
        layer.addSublayer(highlightBorder)
        
        // Name label
        nameLabel.textColor = .white
        nameLabel.font = .boldSystemFont(ofSize: 14)
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        
        // Chips label
        chipsLabel.textColor = .yellow
        chipsLabel.font = .systemFont(ofSize: 12, weight: .medium)
        chipsLabel.textAlignment = .center
        chipsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        chipsLabel.layer.cornerRadius = 8
        chipsLabel.layer.masksToBounds = true
        chipsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chipsLabel)
        
        // Cards setup
        [card1View, card2View].forEach { cardView in
            cardView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(cardView)
        }
        
        // Action label
        actionLabel.textColor = .white
        actionLabel.font = .boldSystemFont(ofSize: 11)
        actionLabel.textAlignment = .center
        actionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        actionLabel.layer.cornerRadius = 8
        actionLabel.layer.masksToBounds = true
        actionLabel.alpha = 0
        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionLabel)
        
        // Dealer button - small red circle indicator
        dealerButton.text = "D"
        dealerButton.textColor = .white
        dealerButton.backgroundColor = .red
        dealerButton.font = .boldSystemFont(ofSize: 8)
        dealerButton.textAlignment = .center
        dealerButton.layer.cornerRadius = 5
        dealerButton.layer.masksToBounds = true
        dealerButton.layer.borderWidth = 1
        dealerButton.layer.borderColor = UIColor.white.cgColor
        dealerButton.isHidden = true
        dealerButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dealerButton)
        
        // Bet chips - positioned to avoid overlap
        betChipsView.textColor = .white
        betChipsView.backgroundColor = UIColor.orange.withAlphaComponent(0.95)
        betChipsView.font = .boldSystemFont(ofSize: 11)
        betChipsView.textAlignment = .center
        betChipsView.layer.cornerRadius = 10
        betChipsView.layer.masksToBounds = true
        betChipsView.layer.borderWidth = 2
        betChipsView.layer.borderColor = UIColor.white.cgColor
        betChipsView.isHidden = true
        betChipsView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(betChipsView)
    }
    
    private func setupConstraints() {
        // Clear existing constraints
        removeConstraints(constraints)
        
        if isHumanPlayer {
            setupHumanPlayerConstraints()
        } else {
            setupAIPlayerConstraints()
        }
        
        // Common constraints
        NSLayoutConstraint.activate([
            // Name label
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            nameLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Chips label - at bottom
            chipsLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            chipsLabel.heightAnchor.constraint(equalToConstant: 24),
            chipsLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // Action label - above cards
            actionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionLabel.bottomAnchor.constraint(equalTo: card1View.topAnchor, constant: -6),
            actionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 70),
            actionLabel.heightAnchor.constraint(equalToConstant: 22),
            
            // Dealer button - small circle (10x10)
            dealerButton.widthAnchor.constraint(equalToConstant: 10),
            dealerButton.heightAnchor.constraint(equalToConstant: 10),
            dealerButton.topAnchor.constraint(equalTo: topAnchor, constant: -5),
            dealerButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            // Bet chips - positioned outside player view to avoid overlap
            betChipsView.heightAnchor.constraint(equalToConstant: 26),
            betChipsView.centerXAnchor.constraint(equalTo: centerXAnchor),
            betChipsView.topAnchor.constraint(equalTo: bottomAnchor, constant: 14),
            betChipsView.widthAnchor.constraint(greaterThanOrEqualToConstant: 65)
        ])
        
        // Different padding for human vs AI players to maintain visual balance
        if isHumanPlayer {
            // Human player gets more padding due to wider view (larger cards)
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                chipsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
                chipsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24)
            ])
        } else {
            // AI players use standard padding
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                chipsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
                chipsLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
            ])
        }
    }
    
    private func setupHumanPlayerConstraints() {
        // Larger cards for human player
        NSLayoutConstraint.activate([
            card1View.widthAnchor.constraint(equalToConstant: 60),
            card1View.heightAnchor.constraint(equalToConstant: 80),
            card1View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -30),
            card1View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            
            card2View.widthAnchor.constraint(equalToConstant: 60),
            card2View.heightAnchor.constraint(equalToConstant: 80),
            card2View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 30),
            card2View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10)
        ])
    }
    
    private func setupAIPlayerConstraints() {
        // Smaller cards for AI players
        NSLayoutConstraint.activate([
            card1View.widthAnchor.constraint(equalToConstant: 42),
            card1View.heightAnchor.constraint(equalToConstant: 54),
            card1View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -19),
            card1View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            
            card2View.widthAnchor.constraint(equalToConstant: 42),
            card2View.heightAnchor.constraint(equalToConstant: 54),
            card2View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 19),
            card2View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        highlightBorder.path = UIBezierPath(roundedRect: bounds, cornerRadius: 12).cgPath
    }

    func configureWith(player: Player, isDealer: Bool = false) {
        self.player = player
        self.isHumanPlayer = player.isHuman
        
        print("PlayerView: Configuring \(player.name) with \(player.holeCards.count) cards")
        
        // Setup constraints based on player type
        setupConstraints()
        
        nameLabel.text = player.name
        updateChips()
        
        // Show cards if player has them
        if player.holeCards.count >= 2 {
            print("PlayerView: Setting cards for \(player.name) - \(player.holeCards[0].description), \(player.holeCards[1].description)")
            
            // Set cards - face up for human, face down for AI
            card1View.setCard(player.holeCards[0], faceUp: player.isHuman)
            card2View.setCard(player.holeCards[1], faceUp: player.isHuman)
            card1View.isHidden = false
            card2View.isHidden = false
        } else {
            print("PlayerView: No cards to show for \(player.name)")
            card1View.isHidden = true
            card2View.isHidden = true
        }
        
        // Dealer button
        dealerButton.isHidden = !isDealer
        
        // Update appearance based on player state
        updateAppearance()
    }
    private func updateAppearance() {
        guard let player = player else { return }
        
        // Dim if folded
        alpha = player.isFolded ? 0.6 : 1.0
        
        // Border color based on state
        if player.isFolded {
            layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
        } else if player.isActive {
            layer.borderColor = UIColor.green.withAlphaComponent(0.6).cgColor
        } else {
            layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        }
    }
    
    func updateChips() {
        guard let player = player else { return }
        chipsLabel.text = "$\(player.chips)"
    }
    
    func showAction(_ action: PlayerAction) {
        actionLabel.text = action.description
        
        // Color based on action
        switch action {
        case .fold:
            actionLabel.backgroundColor = UIColor.red.withAlphaComponent(0.9)
        case .check:
            actionLabel.backgroundColor = UIColor.green.withAlphaComponent(0.9)
        case .call:
            actionLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.9)
        case .raise:
            actionLabel.backgroundColor = UIColor.orange.withAlphaComponent(0.9)
        case .allIn:
            actionLabel.backgroundColor = UIColor.purple.withAlphaComponent(0.9)
        }
        
        // Show with animation
        actionLabel.alpha = 0
        actionLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.actionLabel.alpha = 1
            self.actionLabel.transform = .identity
        }
        
        // Hide after delay
        UIView.animate(withDuration: 0.3, delay: 2.5, options: []) {
            self.actionLabel.alpha = 0
        }
    }
    
    func showBet(_ amount: Int) {
        if amount > 0 {
            betChipsView.text = "$\(amount)"
            betChipsView.isHidden = false
            
            // Animate bet display
            betChipsView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.3, delay: 0.1, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                self.betChipsView.transform = .identity
            }
        } else {
            UIView.animate(withDuration: 0.2) {
                self.betChipsView.alpha = 0
            } completion: { _ in
                self.betChipsView.isHidden = true
                self.betChipsView.alpha = 1
            }
        }
    }
    
    func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            highlightBorder.opacity = 1
            
            // Pulse animation
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.4
            animation.toValue = 1.0
            animation.duration = 0.8
            animation.autoreverses = true
            animation.repeatCount = .infinity
            highlightBorder.add(animation, forKey: "pulse")
        } else {
            highlightBorder.removeAllAnimations()
            highlightBorder.opacity = 0
        }
    }
    
    func showWinAnimation() {
        // Win animation with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        UIView.animate(withDuration: 0.5, animations: {
            self.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.layer.borderColor = UIColor.yellow.cgColor
            self.layer.borderWidth = 4
            self.backgroundColor = UIColor.yellow.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.5) {
                self.transform = .identity
                self.layer.borderWidth = 2
                self.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            }
        }
    }
    

    func revealCards() {
        guard let player = player else {
            print("PlayerView: No player set!")
            return
        }
        
        print("PlayerView: revealCards called for \(player.name)")
        
        // FIX: Simplified logic.
        // Reveal cards for ANY player (Human or AI) who hasn't folded.
        if !player.isFolded && player.holeCards.count >= 2 {
            print("PlayerView: Revealing cards for \(player.name)")
            
            // Reveal first card immediately
            card1View.revealCard()
            
            // Reveal second card with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.card2View.revealCard()
            }
        } else {
            print("PlayerView: Not revealing cards - Folded or invalid state")
        }
    }
    
    func forceRevealCards() {
        guard let player = player else { return }
        
        print("PlayerView: Force revealing cards for \(player.name) "
              + "folded: \(player.isFolded), invested: \(player.totalInvested)")
        
        // At showdown: if you have two hole cards, we show them.
        if player.holeCards.count >= 2 {
            card1View.forceShowCard()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.card2View.forceShowCard()
            }
        }
    }

}
