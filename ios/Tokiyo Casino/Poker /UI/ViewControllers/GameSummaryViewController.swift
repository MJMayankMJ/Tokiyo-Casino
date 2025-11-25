//
//  GameSummaryViewController.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

struct PlayerSummary {
    let player: Player
    let handDescription: String?
    let category: PlayerCategory
    
    enum PlayerCategory {
        case winner
        case folded
        case lost
    }
}

class GameSummaryViewController: UIViewController {
    
    // MARK: - Properties
    private let playerSummaries: [PlayerSummary]
    private let totalPot: Int
    private let communityCards: [Card]
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let potLabel = UILabel()
    private let communityCardsContainer = UIView()
    private let winnersContainer = UIView()
    private let foldedContainer = UIView()
    private let lostContainer = UIView()
    private let newGameButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    
    private let gradientLayer = CAGradientLayer()
    
    // Callbacks
    var onNewGame: (() -> Void)?
    var onMenu: (() -> Void)?
    
    // MARK: - Initialization
    init(playerSummaries: [PlayerSummary], totalPot: Int, communityCards: [Card]) {
        self.playerSummaries = playerSummaries
        self.totalPot = totalPot
        self.communityCards = communityCards
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        layoutSummary()
        animateEntrance()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Gradient background
        gradientLayer.colors = [
            UIColor(red: 0.02, green: 0.20, blue: 0.06, alpha: 1.0).cgColor,
            UIColor(red: 0.01, green: 0.10, blue: 0.03, alpha: 1.0).cgColor
        ]
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // Content view
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "🎉 HAND SUMMARY 🎉"
        titleLabel.font = UIFont(name: "Copperplate-Bold", size: 28) ?? .boldSystemFont(ofSize: 28)
        titleLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 3
        contentView.addSubview(titleLabel)
        
        // Pot label
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let formattedPot = formatter.string(from: NSNumber(value: totalPot)) ?? "\(totalPot)"
        
        potLabel.text = "💰 TOTAL POT: $\(formattedPot)"
        potLabel.font = UIFont(name: "Copperplate", size: 18) ?? .systemFont(ofSize: 18, weight: .semibold)
        potLabel.textColor = .white
        potLabel.textAlignment = .center
        potLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(potLabel)
        
        // Community cards container
        communityCardsContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(communityCardsContainer)
        
        // Containers for different player categories
        winnersContainer.translatesAutoresizingMaskIntoConstraints = false
        foldedContainer.translatesAutoresizingMaskIntoConstraints = false
        lostContainer.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(winnersContainer)
        contentView.addSubview(foldedContainer)
        contentView.addSubview(lostContainer)
        
        // Buttons
        setupButtons()
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            potLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            potLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            communityCardsContainer.topAnchor.constraint(equalTo: potLabel.bottomAnchor, constant: 20),
            communityCardsContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            communityCardsContainer.heightAnchor.constraint(equalToConstant: 80),
            
            winnersContainer.topAnchor.constraint(equalTo: communityCardsContainer.bottomAnchor, constant: 30),
            winnersContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            winnersContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            lostContainer.topAnchor.constraint(equalTo: winnersContainer.bottomAnchor, constant: 20),
            lostContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            lostContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            foldedContainer.topAnchor.constraint(equalTo: lostContainer.bottomAnchor, constant: 20),
            foldedContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            foldedContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            foldedContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -120)
        ])
    }
    
    private func setupButtons() {
        // New Game button
        newGameButton.setTitle("NEW HAND", for: .normal)
        newGameButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        newGameButton.setTitleColor(.white, for: .normal)
        newGameButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        newGameButton.layer.cornerRadius = 25
        newGameButton.layer.shadowColor = UIColor.black.cgColor
        newGameButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        newGameButton.layer.shadowOpacity = 0.5
        newGameButton.layer.shadowRadius = 8
        newGameButton.layer.borderWidth = 2
        newGameButton.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0).cgColor
        newGameButton.addTarget(self, action: #selector(newGameTapped), for: .touchUpInside)
        newGameButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newGameButton)
        
        // Menu button
        menuButton.setTitle("EXIT TO MENU", for: .normal)
        menuButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        menuButton.setTitleColor(.white.withAlphaComponent(0.9), for: .normal)
        menuButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        menuButton.layer.cornerRadius = 20
        menuButton.layer.borderWidth = 1
        menuButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            newGameButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            newGameButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newGameButton.widthAnchor.constraint(equalToConstant: 200),
            newGameButton.heightAnchor.constraint(equalToConstant: 50),
            
            menuButton.bottomAnchor.constraint(equalTo: newGameButton.topAnchor, constant: -12),
            menuButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 150),
            menuButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Layout
    private func layoutSummary() {
        // Show community cards
        layoutCommunityCards()
        
        // Categorize players
        let winners = playerSummaries.filter { $0.category == .winner }
        let folded = playerSummaries.filter { $0.category == .folded }
        let lost = playerSummaries.filter { $0.category == .lost }
        
        // Layout each category
        if !winners.isEmpty {
            layoutPlayerCategory(players: winners, in: winnersContainer, title: "🏆 WINNERS", color: UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.9))
        }
        
        if !lost.isEmpty {
            layoutPlayerCategory(players: lost, in: lostContainer, title: "🎲 PLAYERS", color: UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 0.7))
        }
        
        if !folded.isEmpty {
            layoutPlayerCategory(players: folded, in: foldedContainer, title: "😔 FOLDED", color: UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.7))
        }
    }
    
    private func layoutCommunityCards() {
        let cardWidth: CGFloat = 50
        let cardSpacing: CGFloat = 8
        let totalWidth = CGFloat(communityCards.count) * (cardWidth + cardSpacing) - cardSpacing
        
        var xOffset: CGFloat = 0
        
        for card in communityCards {
            let cardView = createSmallCardView(card: card, width: cardWidth)
            cardView.frame = CGRect(x: xOffset, y: 0, width: cardWidth, height: 70)
            communityCardsContainer.addSubview(cardView)
            xOffset += cardWidth + cardSpacing
        }
        
        communityCardsContainer.widthAnchor.constraint(equalToConstant: totalWidth).isActive = true
    }
    
    private func layoutPlayerCategory(players: [PlayerSummary], in container: UIView, title: String, color: UIColor) {
        // Category header
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = UIFont(name: "Copperplate-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        headerLabel.textColor = .white
        headerLabel.textAlignment = .center
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(headerLabel)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor),
            headerLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
        
        var previousView: UIView = headerLabel
        
        for (index, summary) in players.enumerated() {
            let playerCard = createPlayerCard(summary: summary, color: color)
            playerCard.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(playerCard)
            
            NSLayoutConstraint.activate([
                playerCard.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: 15),
                playerCard.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                playerCard.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                playerCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
            ])
            
            previousView = playerCard
            
            if index == players.count - 1 {
                playerCard.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
            }
        }
    }
    
    private func createPlayerCard(summary: PlayerSummary, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = color
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 2
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowOpacity = 0.3
        card.layer.shadowRadius = 6
        
        // Player name
        let nameLabel = UILabel()
        nameLabel.text = summary.player.name
        nameLabel.font = UIFont(name: "Copperplate-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)
        
        // Hand description (if winner or lost)
        var handDescLabel: UILabel?
        if let handDesc = summary.handDescription {
            let label = UILabel()
            label.text = handDesc
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .white.withAlphaComponent(0.95)
            label.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(label)
            handDescLabel = label
        }
        
        // Hole cards
        let cardsContainer = UIView()
        cardsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardsContainer)
        
        let cardWidth: CGFloat = 45
        let cardSpacing: CGFloat = 8
        
        for (index, holeCard) in summary.player.holeCards.enumerated() {
            let cardView = createSmallCardView(card: holeCard, width: cardWidth)
            cardView.frame = CGRect(
                x: CGFloat(index) * (cardWidth + cardSpacing),
                y: 0,
                width: cardWidth,
                height: 60
            )
            cardsContainer.addSubview(cardView)
        }
        
        // Stats container (contributed & chips)
        let statsContainer = UIView()
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statsContainer)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        
        let contributedText = formatter.string(from: NSNumber(value: summary.player.totalInvested)) ?? "\(summary.player.totalInvested)"
        let chipsText = formatter.string(from: NSNumber(value: summary.player.chips)) ?? "\(summary.player.chips)"
        
        let contributedLabel = UILabel()
        contributedLabel.text = "💰 Chips: $\(chipsText)"
        contributedLabel.font = .systemFont(ofSize: 13, weight: .medium)
        contributedLabel.textColor = .white.withAlphaComponent(0.9)
        contributedLabel.translatesAutoresizingMaskIntoConstraints = false
        statsContainer.addSubview(contributedLabel)
        
//        let chipsLabel = UILabel()
//        chipsLabel.text = "💰 Chips: $\(chipsText)"
//        chipsLabel.font = .systemFont(ofSize: 13, weight: .medium)
//        chipsLabel.textColor = .white.withAlphaComponent(0.9)
//        chipsLabel.translatesAutoresizingMaskIntoConstraints = false
//        statsContainer.addSubview(chipsLabel)
        
        // Constraints
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            
            cardsContainer.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            cardsContainer.widthAnchor.constraint(equalToConstant: 2 * cardWidth + cardSpacing),
            cardsContainer.heightAnchor.constraint(equalToConstant: 60),
            
            statsContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            statsContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            statsContainer.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            
            contributedLabel.topAnchor.constraint(equalTo: statsContainer.topAnchor),
            contributedLabel.leadingAnchor.constraint(equalTo: statsContainer.leadingAnchor),
            
//            chipsLabel.topAnchor.constraint(equalTo: statsContainer.topAnchor),
//            chipsLabel.trailingAnchor.constraint(equalTo: statsContainer.trailingAnchor)
        ])
        
        if let handDescLabel = handDescLabel {
            NSLayoutConstraint.activate([
                handDescLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
                handDescLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
                handDescLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardsContainer.leadingAnchor, constant: -12),
                
                statsContainer.topAnchor.constraint(equalTo: handDescLabel.bottomAnchor, constant: 12)
            ])
        } else {
            statsContainer.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 12).isActive = true
        }
        
        return card
    }
    
    private func createSmallCardView(card: Card, width: CGFloat) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 5
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowOpacity = 0.3
        cardView.layer.shadowRadius = 3
        
        let height = width * 1.4
        
        // Rank label
        let rankLabel = UILabel()
        rankLabel.text = card.rank.shortString
        rankLabel.font = .boldSystemFont(ofSize: width * 0.35)
        rankLabel.textColor = card.suit.color
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(rankLabel)
        
        // Suit label
        let suitLabel = UILabel()
        suitLabel.text = card.suit.symbol
        suitLabel.font = .systemFont(ofSize: width * 0.5)
        suitLabel.textColor = card.suit.color
        suitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(suitLabel)
        
        NSLayoutConstraint.activate([
            rankLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 3),
            rankLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 3),
            
            suitLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            suitLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
        
        return cardView
    }
    
    // MARK: - Animation
    private func animateEntrance() {
        view.alpha = 0
        view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            self.view.alpha = 1
            self.view.transform = .identity
        })
        
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // MARK: - Actions
    @objc private func newGameTapped() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        dismiss(animated: true) {
            self.onNewGame?()
        }
    }
    
    @objc private func menuTapped() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        dismiss(animated: true) {
            self.onMenu?()
        }
    }
}
