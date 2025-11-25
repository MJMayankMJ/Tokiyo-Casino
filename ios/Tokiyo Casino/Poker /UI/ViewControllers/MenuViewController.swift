//
//  MenuViewController.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

class MenuViewController: UIViewController {
    
    // UI Elements
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let logoContainerView = UIView()
    private let playButton = UIButton(type: .system)
    private let playerCountSegment = UISegmentedControl(items: ["3", "4", "5"])
    private let playerCountLabel = UILabel()
    private let startingChipsSlider = UISlider()
    private let startingChipsLabel = UILabel()
    private let startingChipsValueLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let gradientLayer = CAGradientLayer()
    
    // Decorative elements
    private let chipDecoration1 = UIView()
    private let chipDecoration2 = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addDecorations()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }
    
    private func setupUI() {
        // Gradient background
        gradientLayer.colors = [
            UIColor(red: 0.02, green: 0.20, blue: 0.06, alpha: 1.0).cgColor,
            UIColor(red: 0.01, green: 0.10, blue: 0.03, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Title with shadow
        titleLabel.text = "TEXAS HOLD'EM"
        titleLabel.font = UIFont(name: "Copperplate-Bold", size: 32) ?? .boldSystemFont(ofSize: 32)
        titleLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold color
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 3
        view.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "POKER"
        subtitleLabel.font = UIFont(name: "Copperplate", size: 20) ?? .systemFont(ofSize: 20, weight: .medium)
        subtitleLabel.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        subtitleLabel.layer.shadowOpacity = 0.6
        subtitleLabel.layer.shadowRadius = 2
        view.addSubview(subtitleLabel)
        
        // Logo container with enhanced styling
        logoContainerView.backgroundColor = .clear
        logoContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoContainerView)
        
        // Draw poker logo
        drawPokerLogo()
        
        // Player count label with better styling
        playerCountLabel.text = "NUMBER OF PLAYERS"
        playerCountLabel.font = UIFont(name: "Copperplate", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        playerCountLabel.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.9)
        playerCountLabel.textAlignment = .center
        playerCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerCountLabel)
        
        // Enhanced segment control
        playerCountSegment.selectedSegmentIndex = 3 // Default to 6 players
        playerCountSegment.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        playerCountSegment.selectedSegmentTintColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        playerCountSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            .font: UIFont.boldSystemFont(ofSize: 16)
        ], for: .normal)
        playerCountSegment.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 16)
        ], for: .selected)
        playerCountSegment.layer.cornerRadius = 8
        playerCountSegment.layer.borderWidth = 1
        playerCountSegment.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 0.5).cgColor
        playerCountSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerCountSegment)
        
        // Starting chips label
        startingChipsLabel.text = "STARTING CHIPS"
        startingChipsLabel.font = UIFont(name: "Copperplate", size: 14) ?? .systemFont(ofSize: 14, weight: .semibold)
        startingChipsLabel.textColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.9)
        startingChipsLabel.textAlignment = .center
        startingChipsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startingChipsLabel)
        
        // Chips value display
        startingChipsValueLabel.text = "$1,000"
        startingChipsValueLabel.font = UIFont(name: "Copperplate-Bold", size: 24) ?? .boldSystemFont(ofSize: 24)
        startingChipsValueLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        startingChipsValueLabel.textAlignment = .center
        startingChipsValueLabel.translatesAutoresizingMaskIntoConstraints = false
        startingChipsValueLabel.layer.shadowColor = UIColor.black.cgColor
        startingChipsValueLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        startingChipsValueLabel.layer.shadowOpacity = 0.6
        startingChipsValueLabel.layer.shadowRadius = 2
        view.addSubview(startingChipsValueLabel)
        
        // Enhanced slider
        startingChipsSlider.minimumValue = 500
        startingChipsSlider.maximumValue = 5000
        startingChipsSlider.value = 1000
        startingChipsSlider.minimumTrackTintColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        startingChipsSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        startingChipsSlider.thumbTintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        startingChipsSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        startingChipsSlider.translatesAutoresizingMaskIntoConstraints = false
        startingChipsSlider.layer.shadowColor = UIColor.black.cgColor
        startingChipsSlider.layer.shadowOffset = CGSize(width: 0, height: 2)
        startingChipsSlider.layer.shadowOpacity = 0.3
        startingChipsSlider.layer.shadowRadius = 2
        view.addSubview(startingChipsSlider)
        
        // Enhanced play button
        playButton.setTitle("START GAME", for: .normal)
        playButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 20) ?? .boldSystemFont(ofSize: 20)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        playButton.layer.cornerRadius = 28
        playButton.layer.shadowColor = UIColor.black.cgColor
        playButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        playButton.layer.shadowOpacity = 0.5
        playButton.layer.shadowRadius = 8
        playButton.layer.borderWidth = 2
        playButton.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0).cgColor
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        playButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        playButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playButton)
        
        // Enhanced settings button
        settingsButton.setTitle("⚙️ Settings", for: .normal)
        settingsButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        settingsButton.setTitleColor(.white.withAlphaComponent(0.9), for: .normal)
        settingsButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        settingsButton.layer.cornerRadius = 22
        settingsButton.layer.borderWidth = 1
        settingsButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logoContainerView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 25),
            logoContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoContainerView.widthAnchor.constraint(equalToConstant: 240),
            logoContainerView.heightAnchor.constraint(equalToConstant: 140),
            
            playerCountLabel.topAnchor.constraint(equalTo: logoContainerView.bottomAnchor, constant: 35),
            playerCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            playerCountSegment.topAnchor.constraint(equalTo: playerCountLabel.bottomAnchor, constant: 12),
            playerCountSegment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerCountSegment.widthAnchor.constraint(equalToConstant: 260),
            playerCountSegment.heightAnchor.constraint(equalToConstant: 44),
            
            startingChipsLabel.topAnchor.constraint(equalTo: playerCountSegment.bottomAnchor, constant: 30),
            startingChipsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startingChipsValueLabel.topAnchor.constraint(equalTo: startingChipsLabel.bottomAnchor, constant: 8),
            startingChipsValueLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startingChipsSlider.topAnchor.constraint(equalTo: startingChipsValueLabel.bottomAnchor, constant: 12),
            startingChipsSlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startingChipsSlider.widthAnchor.constraint(equalToConstant: 260),
            
            playButton.topAnchor.constraint(equalTo: startingChipsSlider.bottomAnchor, constant: 45),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 240),
            playButton.heightAnchor.constraint(equalToConstant: 56),
            
            settingsButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 16),
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 160),
            settingsButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func addDecorations() {
        // Add decorative poker chips
        createChipDecoration(chipDecoration1, x: 30, y: 100)
        createChipDecoration(chipDecoration2, x: view.bounds.width - 60, y: view.bounds.height - 150)
        
        view.addSubview(chipDecoration1)
        view.addSubview(chipDecoration2)
        
        // Animate decorations
        animateChips()
    }
    
    private func createChipDecoration(_ chip: UIView, x: CGFloat, y: CGFloat) {
        chip.frame = CGRect(x: x, y: y, width: 40, height: 40)
        chip.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 0.3)
        chip.layer.cornerRadius = 20
        chip.layer.borderWidth = 2
        chip.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        chip.alpha = 0.6
        
        // Add center circle
        let centerCircle = UIView(frame: CGRect(x: 10, y: 10, width: 20, height: 20))
        centerCircle.backgroundColor = .white.withAlphaComponent(0.2)
        centerCircle.layer.cornerRadius = 10
        chip.addSubview(centerCircle)
    }
    
    private func animateChips() {
        UIView.animate(withDuration: 3.0, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
            self.chipDecoration1.transform = CGAffineTransform(translationX: 0, y: 20)
            self.chipDecoration2.transform = CGAffineTransform(translationX: 0, y: -20)
        })
    }
    
    private func drawPokerLogo() {
        // Create three overlapping cards for a more dynamic look
        let card1 = createMiniCard(rank: "A", suit: "♠", color: .black)
        let card2 = createMiniCard(rank: "K", suit: "♥", color: .red)
        let card3 = createMiniCard(rank: "Q", suit: "♦", color: .red)
        
        card1.transform = CGAffineTransform(rotationAngle: -0.25)
        card2.transform = CGAffineTransform(rotationAngle: 0.0)
        card3.transform = CGAffineTransform(rotationAngle: 0.25)
        
        logoContainerView.addSubview(card1)
        logoContainerView.addSubview(card2)
        logoContainerView.addSubview(card3)
        
        card1.translatesAutoresizingMaskIntoConstraints = false
        card2.translatesAutoresizingMaskIntoConstraints = false
        card3.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card1.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor, constant: -35),
            card1.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            card1.widthAnchor.constraint(equalToConstant: 70),
            card1.heightAnchor.constraint(equalToConstant: 95),
            
            card2.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            card2.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            card2.widthAnchor.constraint(equalToConstant: 70),
            card2.heightAnchor.constraint(equalToConstant: 95),
            
            card3.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor, constant: 35),
            card3.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            card3.widthAnchor.constraint(equalToConstant: 70),
            card3.heightAnchor.constraint(equalToConstant: 95)
        ])
        
        // Add subtle animation to cards
        animateCards([card1, card2, card3])
    }
    
    private func animateCards(_ cards: [UIView]) {
        for (index, card) in cards.enumerated() {
            UIView.animate(withDuration: 2.5, delay: Double(index) * 0.2, options: [.repeat, .autoreverse, .curveEaseInOut], animations: {
                card.transform = card.transform.translatedBy(x: 0, y: -8)
            })
        }
    }
    
    private func createMiniCard(rank: String, suit: String, color: UIColor) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = UIColor.black.withAlphaComponent(0.2).cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowOpacity = 0.4
        cardView.layer.shadowRadius = 6
        
        // Top-left rank and suit
        let topRankLabel = UILabel()
        topRankLabel.text = rank
        topRankLabel.font = .boldSystemFont(ofSize: 22)
        topRankLabel.textColor = color
        topRankLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(topRankLabel)
        
        let topSuitLabel = UILabel()
        topSuitLabel.text = suit
        topSuitLabel.font = .systemFont(ofSize: 18)
        topSuitLabel.textColor = color
        topSuitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(topSuitLabel)
        
        // Center suit (larger)
        let centerSuitLabel = UILabel()
        centerSuitLabel.text = suit
        centerSuitLabel.font = .systemFont(ofSize: 36)
        centerSuitLabel.textColor = color
        centerSuitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(centerSuitLabel)
        
        // Bottom-right rank and suit (rotated)
        let bottomRankLabel = UILabel()
        bottomRankLabel.text = rank
        bottomRankLabel.font = .boldSystemFont(ofSize: 22)
        bottomRankLabel.textColor = color
        bottomRankLabel.transform = CGAffineTransform(rotationAngle: .pi)
        bottomRankLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bottomRankLabel)
        
        let bottomSuitLabel = UILabel()
        bottomSuitLabel.text = suit
        bottomSuitLabel.font = .systemFont(ofSize: 18)
        bottomSuitLabel.textColor = color
        bottomSuitLabel.transform = CGAffineTransform(rotationAngle: .pi)
        bottomSuitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(bottomSuitLabel)
        
        NSLayoutConstraint.activate([
            topRankLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 6),
            topRankLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 6),
            
            topSuitLabel.topAnchor.constraint(equalTo: topRankLabel.bottomAnchor, constant: -2),
            topSuitLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 6),
            
            centerSuitLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            centerSuitLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            bottomRankLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -6),
            bottomRankLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -6),
            
            bottomSuitLabel.bottomAnchor.constraint(equalTo: bottomRankLabel.topAnchor, constant: 2),
            bottomSuitLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -6)
        ])
        
        return cardView
    }
    
    @objc private func sliderChanged() {
        let chips = Int(startingChipsSlider.value / 100) * 100
        startingChipsSlider.value = Float(chips)
        
        // Format with comma
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if let formatted = formatter.string(from: NSNumber(value: chips)) {
            startingChipsValueLabel.text = "$\(formatted)"
        }
        
        // Add subtle bounce animation
        UIView.animate(withDuration: 0.1, animations: {
            self.startingChipsValueLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.startingChipsValueLabel.transform = .identity
            }
        }
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = 1.0
        }
    }
    
    @objc private func playTapped() {
        let playerCount = playerCountSegment.selectedSegmentIndex + 3
        let startingChips = Int(startingChipsSlider.value)
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let gameVC = GameViewController(playerCount: playerCount, startingChips: startingChips)
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        let alert = UIAlertController(title: "Settings", message: "Coming soon!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
