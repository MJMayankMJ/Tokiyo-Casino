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
    private let logoImageView = UIImageView()
    private let playButton = UIButton(type: .system)
    private let playerCountSegment = UISegmentedControl(items: ["3", "4", "5", "6"])
    private let playerCountLabel = UILabel()
    private let startingChipsSlider = UISlider()
    private let startingChipsLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1.0)
        
        // Title
        titleLabel.text = "Texas Hold'em Poker"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Logo/Cards decoration
        logoImageView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        logoImageView.layer.cornerRadius = 10
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        
        // Draw some cards as logo
        drawPokerLogo()
        
        // Player count label
        playerCountLabel.text = "Number of Players"
        playerCountLabel.font = .systemFont(ofSize: 16)
        playerCountLabel.textColor = .white
        playerCountLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerCountLabel)
        
        // Player count segment
        playerCountSegment.selectedSegmentIndex = 3 // Default to 6 players
        playerCountSegment.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        playerCountSegment.selectedSegmentTintColor = UIColor.green.withAlphaComponent(0.5)
        playerCountSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        playerCountSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playerCountSegment)
        
        // Starting chips label
        startingChipsLabel.text = "Starting Chips: $1000"
        startingChipsLabel.font = .systemFont(ofSize: 16)
        startingChipsLabel.textColor = .white
        startingChipsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startingChipsLabel)
        
        // Starting chips slider
        startingChipsSlider.minimumValue = 500
        startingChipsSlider.maximumValue = 5000
        startingChipsSlider.value = 1000
        startingChipsSlider.minimumTrackTintColor = .green
        startingChipsSlider.maximumTrackTintColor = .gray
        startingChipsSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        startingChipsSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startingChipsSlider)
        
        
        // Play button
        playButton.setTitle("Start Game", for: .normal)
        playButton.titleLabel?.font = .boldSystemFont(ofSize: 20)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = UIColor.green.withAlphaComponent(0.7)
        playButton.layer.cornerRadius = 25
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(playButton)
        
        
        // Settings button
        settingsButton.setTitle("Settings", for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 16)
        settingsButton.setTitleColor(.white, for: .normal)
        settingsButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        settingsButton.layer.cornerRadius = 20
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),
            
            playerCountLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 40),
            playerCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            playerCountSegment.topAnchor.constraint(equalTo: playerCountLabel.bottomAnchor, constant: 10),
            playerCountSegment.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerCountSegment.widthAnchor.constraint(equalToConstant: 240),
            playerCountSegment.heightAnchor.constraint(equalToConstant: 40),
            
            startingChipsLabel.topAnchor.constraint(equalTo: playerCountSegment.bottomAnchor, constant: 30),
            startingChipsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            startingChipsSlider.topAnchor.constraint(equalTo: startingChipsLabel.bottomAnchor, constant: 10),
            startingChipsSlider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startingChipsSlider.widthAnchor.constraint(equalToConstant: 240),
            
            playButton.topAnchor.constraint(equalTo: startingChipsSlider.bottomAnchor, constant: 50),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 200),
            playButton.heightAnchor.constraint(equalToConstant: 50),
            
            settingsButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 20),
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 150),
            settingsButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func drawPokerLogo() {
        // Create mini card views for logo
        let card1 = createMiniCard(rank: "A", suit: "♠", color: .black)
        let card2 = createMiniCard(rank: "K", suit: "♥", color: .red)
        
        card1.transform = CGAffineTransform(rotationAngle: -0.2)
        card2.transform = CGAffineTransform(rotationAngle: 0.2)
        
        logoImageView.addSubview(card1)
        logoImageView.addSubview(card2)
        
        card1.translatesAutoresizingMaskIntoConstraints = false
        card2.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card1.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor, constant: -20),
            card1.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            card1.widthAnchor.constraint(equalToConstant: 60),
            card1.heightAnchor.constraint(equalToConstant: 80),
            
            card2.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor, constant: 20),
            card2.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
            card2.widthAnchor.constraint(equalToConstant: 60),
            card2.heightAnchor.constraint(equalToConstant: 80)
        ])
    }
    
    private func createMiniCard(rank: String, suit: String, color: UIColor) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 5
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.black.cgColor
        
        let rankLabel = UILabel()
        rankLabel.text = rank
        rankLabel.font = .boldSystemFont(ofSize: 20)
        rankLabel.textColor = color
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(rankLabel)
        
        let suitLabel = UILabel()
        suitLabel.text = suit
        suitLabel.font = .systemFont(ofSize: 24)
        suitLabel.textColor = color
        suitLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(suitLabel)
        
        NSLayoutConstraint.activate([
            rankLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 5),
            rankLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 5),
            
            suitLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            suitLabel.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])
        
        return cardView
    }
    
    @objc private func sliderChanged() {
        let chips = Int(startingChipsSlider.value / 100) * 100
        startingChipsSlider.value = Float(chips)
        startingChipsLabel.text = "Starting Chips: $\(chips)"
    }
    
    @objc private func playTapped() {
        let playerCount = playerCountSegment.selectedSegmentIndex + 3
        let startingChips = Int(startingChipsSlider.value)
        
        let gameVC = GameViewController(playerCount: playerCount, startingChips: startingChips)
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        // Add settings view controller
        let alert = UIAlertController(title: "Settings", message: "Coming soon!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
