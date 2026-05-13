//
//  GameViewControllerSetup.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension GameViewController {
    
    // MARK: - Setup
    func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1.0)
        
        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Betting controls
        bettingControls.translatesAutoresizingMaskIntoConstraints = false
        bettingControls.isHidden = true
        bettingControls.onAction = { [weak self] action in
            self?.handlePlayerAction(action)
        }
        view.addSubview(bettingControls)
        
        // Menu button
        menuButton.setTitle("Menu", for: .normal)
        menuButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        menuButton.layer.cornerRadius = 10
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        
        // Mute button
        muteButton.setImage(getMuteButtonImage(), for: .normal)
        muteButton.tintColor = .white
        muteButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        muteButton.layer.cornerRadius = 20
        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(muteButton)
        
        // New hand button
        newHandButton.setTitle("New Hand", for: .normal)
        newHandButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        newHandButton.setTitleColor(.white, for: .normal)
        newHandButton.backgroundColor = UIColor.green.withAlphaComponent(0.8)
        newHandButton.layer.cornerRadius = 12
        newHandButton.layer.borderWidth = 2
        newHandButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        newHandButton.addTarget(self, action: #selector(newHandTapped), for: .touchUpInside)
        newHandButton.translatesAutoresizingMaskIntoConstraints = false
        newHandButton.isHidden = true
        view.addSubview(newHandButton)
        
        NSLayoutConstraint.activate([
            // Table view
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Betting controls - more padding and height
            bettingControls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bettingControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bettingControls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 30),
            bettingControls.heightAnchor.constraint(equalToConstant: 200),
            
            // Menu button
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            menuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            menuButton.widthAnchor.constraint(equalToConstant: 90),
            menuButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Mute button
            muteButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            muteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            muteButton.widthAnchor.constraint(equalToConstant: 40),
            muteButton.heightAnchor.constraint(equalToConstant: 40),
            
            // New hand button
            newHandButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newHandButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 100),
            newHandButton.widthAnchor.constraint(equalToConstant: 140),
            newHandButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    func setupGame() {
        gameManager = GameManager(playerCount: playerCount, startingChips: startingChips)
        gameManager.delegate = self
        
        // Start first hand after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startNewHand()
        }
    }
    
    func setupNotifications() {
        // Listen for delayed winner alerts
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDelayedWinnerAlert(_:)),
            name: NSNotification.Name("ShowWinnerAlert"),
            object: nil
        )
        
        // Listen for sound setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(soundSettingChanged),
            name: NSNotification.Name("SoundSettingChanged"),
            object: nil
        )
    }
}
