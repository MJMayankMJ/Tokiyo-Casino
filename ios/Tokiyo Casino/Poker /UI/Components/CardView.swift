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

// MARK: - Betting Controls View
class BettingControlsView: UIView {
    
    private let foldButton = UIButton(type: .system)
    private let checkCallButton = UIButton(type: .system)
    private let raiseButton = UIButton(type: .system)
    private let allInButton = UIButton(type: .system)
    private let raiseSlider = UISlider()
    private let raiseAmountLabel = UILabel()
    private let buttonStackView = UIStackView()
    
    var onAction: ((PlayerAction) -> Void)?
    
    private var minRaise: Int = 0
    private var maxRaise: Int = 0
    private var callAmount: Int = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.40)
        layer.cornerRadius = 18
    
        
        // Setup stack view for buttons
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonStackView)
        
        // Configure buttons
        let buttons = [foldButton, checkCallButton, raiseButton, allInButton]
        for button in buttons {
            button.titleLabel?.font = .boldSystemFont(ofSize: 12)
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 12
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            buttonStackView.addArrangedSubview(button)
        }
        
        foldButton.setTitle("Fold", for: .normal)
        foldButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        foldButton.addTarget(self, action: #selector(foldTapped), for: .touchUpInside)
        
        checkCallButton.setTitle("Check", for: .normal)
        checkCallButton.backgroundColor = UIColor.green.withAlphaComponent(0.7)
        checkCallButton.addTarget(self, action: #selector(checkCallTapped), for: .touchUpInside)
        
        raiseButton.setTitle("Raise", for: .normal)
        raiseButton.backgroundColor = UIColor.orange.withAlphaComponent(0.7)
        raiseButton.addTarget(self, action: #selector(raiseTapped), for: .touchUpInside)
        
        allInButton.setTitle("All In", for: .normal)
        allInButton.backgroundColor = UIColor.purple.withAlphaComponent(0.7)
        allInButton.addTarget(self, action: #selector(allInTapped), for: .touchUpInside)
        
        // Raise amount label
        raiseAmountLabel.textColor = .white
        raiseAmountLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        raiseAmountLabel.textAlignment = .center
        raiseAmountLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        raiseAmountLabel.layer.cornerRadius = 10
        raiseAmountLabel.layer.masksToBounds = true
        raiseAmountLabel.isHidden = true
        raiseAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(raiseAmountLabel)
        
        // Raise slider
        raiseSlider.minimumTrackTintColor = .orange
        raiseSlider.maximumTrackTintColor = .gray
        raiseSlider.thumbTintColor = .white
        raiseSlider.isHidden = true
        raiseSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        raiseSlider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(raiseSlider)
        
        NSLayoutConstraint.activate([
            // Button stack view - more space from bottom
            buttonStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            buttonStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            buttonStackView.heightAnchor.constraint(equalToConstant: 54),
            
            // Raise amount label
            raiseAmountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            raiseAmountLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
            raiseAmountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            raiseAmountLabel.heightAnchor.constraint(equalToConstant: 32),
            
            // Slider
            raiseSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            raiseSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            raiseSlider.bottomAnchor.constraint(equalTo: raiseAmountLabel.topAnchor, constant: -14),
            raiseSlider.heightAnchor.constraint(equalToConstant: 34)
        ])
    }
    
    func updateForActions(_ actions: [PlayerAction], callAmount: Int, minRaise: Int, maxRaise: Int) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        self.callAmount = callAmount
        self.minRaise = minRaise
        self.maxRaise = maxRaise
        
        // Update button states and titles
        foldButton.isEnabled = actions.contains { if case .fold = $0 { return true } else { return false } }
        foldButton.alpha = foldButton.isEnabled ? 1.0 : 0.5
        
        let canCheck = actions.contains { if case .check = $0 { return true } else { return false } }
        let canCall = actions.contains { if case .call = $0 { return true } else { return false } }
        
        if canCheck {
            checkCallButton.setTitle("Check", for: .normal)
            checkCallButton.backgroundColor = UIColor.green.withAlphaComponent(0.6)
        } else if canCall {
            checkCallButton.setTitle("Call $\(callAmount)", for: .normal)
            checkCallButton.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
        }
        checkCallButton.isEnabled = canCheck || canCall
        checkCallButton.alpha = checkCallButton.isEnabled ? 1.0 : 0.5
        
        raiseButton.isEnabled = actions.contains { if case .raise = $0 { return true } else { return false } }
        raiseButton.alpha = raiseButton.isEnabled ? 1.0 : 0.5
        
        allInButton.isEnabled = actions.contains { if case .allIn = $0 { return true } else { return false } }
        allInButton.alpha = allInButton.isEnabled ? 1.0 : 0.5
        
        // Setup slider
        if raiseButton.isEnabled {
            raiseSlider.minimumValue = Float(minRaise)
            raiseSlider.maximumValue = Float(maxRaise)
            raiseSlider.value = Float(minRaise)
            sliderChanged()
        }
        
        // Animate appearance with better spring animation
        transform = CGAffineTransform(translationX: 0, y: 80)
        alpha = 0
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    @objc private func foldTapped() {
        addHapticFeedback(.medium)
        onAction?(.fold)
        hideWithAnimation()
    }
    
    @objc private func checkCallTapped() {
        addHapticFeedback(.light)
        if checkCallButton.title(for: .normal) == "Check" {
            onAction?(.check)
        } else {
            onAction?(.call)
        }
        hideWithAnimation()
    }
    
    @objc private func raiseTapped() {
        addHapticFeedback(.light)
        
        if raiseSlider.isHidden {
            // Show slider
            raiseSlider.isHidden = false
            raiseAmountLabel.isHidden = false
            raiseButton.setTitle("Confirm", for: .normal)
            raiseButton.backgroundColor = UIColor.yellow.withAlphaComponent(0.6)
            
            // Animate slider appearance
            raiseSlider.alpha = 0
            raiseAmountLabel.alpha = 0
            UIView.animate(withDuration: 0.3) {
                self.raiseSlider.alpha = 1
                self.raiseAmountLabel.alpha = 1
            }
        } else {
            // Confirm raise
            let amount = Int(raiseSlider.value)
            onAction?(.raise(amount))
            hideWithAnimation()
        }
    }
    
    @objc private func allInTapped() {
        addHapticFeedback(.heavy)
        onAction?(.allIn)
        hideWithAnimation()
    }
    
    @objc private func sliderChanged() {
        let amount = Int(raiseSlider.value / 5) * 5 // Round to nearest 5
        raiseSlider.value = Float(amount)
        raiseAmountLabel.text = "Raise to $\(amount)"
        
        // Light haptic feedback while sliding
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    private func hideWithAnimation() {
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 40)
        }) { _ in
            self.isHidden = true
            self.transform = .identity
            self.raiseSlider.isHidden = true
            self.raiseAmountLabel.isHidden = true
            self.raiseButton.setTitle("Raise", for: .normal)
            self.raiseButton.backgroundColor = UIColor.orange.withAlphaComponent(0.7)
        }
    }
}


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
            card1View.widthAnchor.constraint(equalToConstant: 50),
            card1View.heightAnchor.constraint(equalToConstant: 70),
            card1View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -30),
            card1View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            
            card2View.widthAnchor.constraint(equalToConstant: 50),
            card2View.heightAnchor.constraint(equalToConstant: 70),
            card2View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 30),
            card2View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10)
        ])
    }
    
    private func setupAIPlayerConstraints() {
        // Smaller cards for AI players
        NSLayoutConstraint.activate([
            card1View.widthAnchor.constraint(equalToConstant: 32),
            card1View.heightAnchor.constraint(equalToConstant: 44),
            card1View.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -19),
            card1View.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            
            card2View.widthAnchor.constraint(equalToConstant: 32),
            card2View.heightAnchor.constraint(equalToConstant: 44),
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
    
//    func revealCards() {
//        guard let player = player else {
//            print("PlayerView: No player set!")
//            return
//        }
//        
//        print("PlayerView: revealCards called for \(player.name), isHuman: \(player.isHuman), isFolded: \(player.isFolded)")
//        
//        // Only reveal cards for AI players who haven't folded and have cards
//        if !player.isHuman && !player.isFolded && player.holeCards.count >= 2 {
//            print("PlayerView: Revealing cards for \(player.name)")
//            print("PlayerView: Card 1: \(player.holeCards[0].description)")
//            print("PlayerView: Card 2: \(player.holeCards[1].description)")
//            
//            // Reveal first card immediately
//            card1View.revealCard()
//            
//            // Reveal second card with slight delay
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                self.card2View.revealCard()
//            }
//        } else {
//            print("PlayerView: Not revealing cards for \(player.name) - isHuman: \(player.isHuman), isFolded: \(player.isFolded), cardCount: \(player.holeCards.count)")
//        }
//    }
    
//    func forceRevealCards() {
//        guard let player = player else { return }
//        
//        print("PlayerView: Force revealing cards for \(player.name)")
//        
//        if player.holeCards.count >= 2 {
//            card1View.forceShowCard()
//            card2View.forceShowCard()
//        }
//    }
    
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
