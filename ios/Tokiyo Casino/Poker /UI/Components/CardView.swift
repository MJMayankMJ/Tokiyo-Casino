//
//  CardView.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

// MARK: - Fixed CardView with Simple Reveal
class CardView: UIView {
    
    private let imageView = UIImageView()
    private var card: Card?
    private var isFaceUp = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = UIColor.black.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        
        showBackside()
    }
    
    func setCard(_ card: Card, faceUp: Bool = true) {
        self.card = card
        self.isFaceUp = faceUp
        
        if faceUp {
            showCard()
        } else {
            showBackside()
        }
    }
    
    // Simple reveal method - just shows the card immediately
    func revealCard() {
        guard let card = card else {
            print("CardView: No card to reveal!")
            return
        }
        
        print("CardView: Revealing card \(card.description)")
        
        isFaceUp = true
        
        // Use transition animation
        UIView.transition(with: self, duration: 0.5, options: .transitionFlipFromLeft) {
            self.showCard()
        }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // Force show card without animation
    func forceShowCard() {
        guard let card = card else { return }
        print("CardView: Force showing card \(card.description)")
        isFaceUp = true
        showCard()
    }
    
    private func showCard() {
        guard let card = card else { return }
        
        // Clear all subviews first
        subviews.forEach { $0.removeFromSuperview() }
        
        // Re-add imageView
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        
        // Try to load card image from assets first
        let imageName = card.imageName
        print("CardView: Trying to load image: \(imageName)")
        
        if let image = UIImage(named: imageName) {
            imageView.image = image
            imageView.isHidden = false
            print("CardView: Successfully loaded image for \(card.description)")
        } else {
            // Fallback to drawing the card programmatically
            print("CardView: Image not found, drawing card programmatically for \(card.description)")
            imageView.isHidden = true
            drawCard(card)
        }
    }
    
    private func showBackside() {
        // Clear all subviews first
        subviews.forEach { $0.removeFromSuperview() }
        
        // Re-add imageView
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
        
        imageView.isHidden = true
        imageView.image = nil
        
        // Create pattern view for back of card
        let patternView = UIView()
        patternView.backgroundColor = UIColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1.0)
        patternView.layer.cornerRadius = 6
        patternView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(patternView)
        
        // Add decorative pattern
        let centerLabel = UILabel()
        centerLabel.text = "🂠"
        centerLabel.font = .systemFont(ofSize: 16)
        centerLabel.textAlignment = .center
        centerLabel.textColor = .white
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        patternView.addSubview(centerLabel)
        
        NSLayoutConstraint.activate([
            patternView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            patternView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            patternView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            patternView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            
            centerLabel.centerXAnchor.constraint(equalTo: patternView.centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: patternView.centerYAnchor)
        ])
    }
    
    private func drawCard(_ card: Card) {
        backgroundColor = .white
        
        // Create main container
        let cardContainer = UIView()
        cardContainer.backgroundColor = .white
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardContainer)
        
        // Create rank and suit labels
        let rankLabel = UILabel()
        rankLabel.text = card.rank.shortString
        rankLabel.font = .boldSystemFont(ofSize: 18)
        rankLabel.textColor = card.suit.color
        rankLabel.textAlignment = .center
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(rankLabel)
        
        let suitLabel = UILabel()
        suitLabel.text = card.suit.symbol
        suitLabel.font = .systemFont(ofSize: 24)
        suitLabel.textColor = card.suit.color
        suitLabel.textAlignment = .center
        suitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(suitLabel)
        
        NSLayoutConstraint.activate([
            // Container
            cardContainer.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Rank at top
            rankLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 6),
            rankLabel.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            
            // Suit in center
            suitLabel.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            suitLabel.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor)
        ])
    }
}
