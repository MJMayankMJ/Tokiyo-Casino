//
//  BettingControllerView.swift
//  Tokiyo Casino
//
//  Created by Hari's Mac on 25.11.2025.
//

import Foundation
import UIKit

// MARK: - Betting Controls View
class BettingControlsView: UIView {
    
    private let foldButton = UIButton(type: .system)
    private let checkCallButton = UIButton(type: .system)
    private let raiseButton = UIButton(type: .system)
    private let allInButton = UIButton(type: .system)
    private let buttonStackView = UIStackView()
    
    // Enhanced UI elements
    private let containerView = UIView()
    private let chipIndicatorLabel = UILabel()
    
    // Raise amount controls
    private let raiseControlsContainer = UIView()
    private let raiseAmountLabel = UILabel()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let minRaiseButton = UIButton(type: .system)
    private let maxRaiseButton = UIButton(type: .system)
    
    var onAction: ((PlayerAction) -> Void)?
    
    private var minRaise: Int = 0
    private var maxRaise: Int = 0
    private var callAmount: Int = 0
    private var currentRaiseAmount: Int = 0
    private let raiseIncrement: Int = 50
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Main background with rounded corners
        backgroundColor = UIColor(red: 0.02, green: 0.08, blue: 0.02, alpha: 0.95)
        layer.cornerRadius = 20
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: -4)
        layer.shadowOpacity = 0.6
        layer.shadowRadius = 12
        
        // Container with gradient background
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Add gradient to container
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.05, green: 0.18, blue: 0.08, alpha: 1.0).cgColor,
            UIColor(red: 0.02, green: 0.10, blue: 0.04, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = bounds
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 0.3).cgColor
        
        // Chip indicator
        chipIndicatorLabel.font = UIFont(name: "Copperplate-Bold", size: 13) ?? .systemFont(ofSize: 13, weight: .bold)
        chipIndicatorLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        chipIndicatorLabel.textAlignment = .center
        chipIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chipIndicatorLabel)
        
        // Setup raise controls container
        setupRaiseControls()
        
        // Setup stack view for buttons
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStackView)
        
        // Configure buttons
        setupButton(foldButton, title: "FOLD", gradient: [
            UIColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.65, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        ], action: #selector(foldTapped))
        
        setupButton(checkCallButton, title: "CHECK", gradient: [
            UIColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1.0).cgColor,
            UIColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).cgColor
        ], action: #selector(checkCallTapped))
        
        setupButton(raiseButton, title: "RAISE", gradient: [
            UIColor(red: 0.95, green: 0.65, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.75, green: 0.45, blue: 0.1, alpha: 1.0).cgColor
        ], action: #selector(raiseTapped))
        
        setupButton(allInButton, title: "ALL IN", gradient: [
            UIColor(red: 0.65, green: 0.2, blue: 0.85, alpha: 1.0).cgColor,
            UIColor(red: 0.45, green: 0.1, blue: 0.65, alpha: 1.0).cgColor
        ], action: #selector(allInTapped))
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            // Chip indicator
            chipIndicatorLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 14),
            chipIndicatorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Raise controls container
            raiseControlsContainer.topAnchor.constraint(equalTo: chipIndicatorLabel.bottomAnchor, constant: 12),
            raiseControlsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            raiseControlsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            raiseControlsContainer.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -14),
            
            // Button stack
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 58)
        ])
    }
    
    private func setupRaiseControls() {
        raiseControlsContainer.isHidden = true
        raiseControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(raiseControlsContainer)
        
        // Amount label
        raiseAmountLabel.text = "$0"
        raiseAmountLabel.font = UIFont(name: "Copperplate-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        raiseAmountLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        raiseAmountLabel.textAlignment = .center
        raiseAmountLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        raiseAmountLabel.layer.cornerRadius = 12
        raiseAmountLabel.layer.masksToBounds = true
        raiseAmountLabel.layer.borderWidth = 2
        raiseAmountLabel.layer.borderColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.4).cgColor
        raiseAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        raiseControlsContainer.addSubview(raiseAmountLabel)
        
        // Minus button
        setupControlButton(minusButton, title: "−", fontSize: 32, action: #selector(minusTapped))
        
        // Plus button
        setupControlButton(plusButton, title: "+", fontSize: 28, action: #selector(plusTapped))
        
        // Min/Max buttons
        minRaiseButton.setTitle("MIN", for: .normal)
        minRaiseButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
        minRaiseButton.setTitleColor(.white, for: .normal)
        minRaiseButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        minRaiseButton.layer.cornerRadius = 8
        minRaiseButton.layer.borderWidth = 1
        minRaiseButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        minRaiseButton.addTarget(self, action: #selector(minRaiseTapped), for: .touchUpInside)
        minRaiseButton.translatesAutoresizingMaskIntoConstraints = false
        raiseControlsContainer.addSubview(minRaiseButton)
        
        maxRaiseButton.setTitle("MAX", for: .normal)
        maxRaiseButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
        maxRaiseButton.setTitleColor(.white, for: .normal)
        maxRaiseButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.8)
        maxRaiseButton.layer.cornerRadius = 8
        maxRaiseButton.layer.borderWidth = 1
        maxRaiseButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        maxRaiseButton.addTarget(self, action: #selector(maxRaiseTapped), for: .touchUpInside)
        maxRaiseButton.translatesAutoresizingMaskIntoConstraints = false
        raiseControlsContainer.addSubview(maxRaiseButton)
        
        NSLayoutConstraint.activate([
            // Amount label
            raiseAmountLabel.topAnchor.constraint(equalTo: raiseControlsContainer.topAnchor, constant: 8),
            raiseAmountLabel.centerXAnchor.constraint(equalTo: raiseControlsContainer.centerXAnchor),
            raiseAmountLabel.widthAnchor.constraint(equalToConstant: 200),
            raiseAmountLabel.heightAnchor.constraint(equalToConstant: 50),
            
            // Minus button
            minusButton.centerYAnchor.constraint(equalTo: raiseAmountLabel.centerYAnchor),
            minusButton.trailingAnchor.constraint(equalTo: raiseAmountLabel.leadingAnchor, constant: -12),
            minusButton.widthAnchor.constraint(equalToConstant: 50),
            minusButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Plus button
            plusButton.centerYAnchor.constraint(equalTo: raiseAmountLabel.centerYAnchor),
            plusButton.leadingAnchor.constraint(equalTo: raiseAmountLabel.trailingAnchor, constant: 12),
            plusButton.widthAnchor.constraint(equalToConstant: 50),
            plusButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Min button
            minRaiseButton.topAnchor.constraint(equalTo: raiseAmountLabel.bottomAnchor, constant: 10),
            minRaiseButton.leadingAnchor.constraint(equalTo: raiseControlsContainer.leadingAnchor, constant: 40),
            minRaiseButton.widthAnchor.constraint(equalToConstant: 60),
            minRaiseButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Max button
            maxRaiseButton.topAnchor.constraint(equalTo: raiseAmountLabel.bottomAnchor, constant: 10),
            maxRaiseButton.trailingAnchor.constraint(equalTo: raiseControlsContainer.trailingAnchor, constant: -40),
            maxRaiseButton.widthAnchor.constraint(equalToConstant: 60),
            maxRaiseButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func setupControlButton(_ button: UIButton, title: String, fontSize: CGFloat, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.9)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 4
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(controlButtonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(controlButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        button.translatesAutoresizingMaskIntoConstraints = false
        raiseControlsContainer.addSubview(button)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Update gradient layer frame
        if let gradientLayer = containerView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = containerView.bounds
        }
        
        // Update button gradient frames
        for case let button in buttonStackView.arrangedSubviews {
            if let gradientLayer = button.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                gradientLayer.frame = button.bounds
            }
        }
    }
    
    private func setupButton(_ button: UIButton, title: String, gradient: [CGColor], action: Selector) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = gradient
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.cornerRadius = 12
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 14) ?? .boldSystemFont(ofSize: 14)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 5
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        buttonStackView.addArrangedSubview(button)
    }
    
    func updateForActions(_ actions: [PlayerAction], callAmount: Int, minRaise: Int, maxRaise: Int) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        self.callAmount = callAmount
        self.minRaise = minRaise
        self.maxRaise = maxRaise
        self.currentRaiseAmount = minRaise
        
        // Update chip indicator
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if let formatted = formatter.string(from: NSNumber(value: maxRaise)) {
            chipIndicatorLabel.text = "💰 Chips: $\(formatted)"
        }
        
        // Update button states
        updateButtonState(foldButton, enabled: actions.contains { if case .fold = $0 { return true } else { return false } })
        
        let canCheck = actions.contains { if case .check = $0 { return true } else { return false } }
        let canCall = actions.contains { if case .call = $0 { return true } else { return false } }
        
        if canCheck {
            checkCallButton.setTitle("CHECK", for: .normal)
            updateButtonGradient(checkCallButton, colors: [
                UIColor(red: 0.2, green: 0.75, blue: 0.35, alpha: 1.0).cgColor,
                UIColor(red: 0.15, green: 0.55, blue: 0.25, alpha: 1.0).cgColor
            ])
        } else if canCall {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            let formattedCall = formatter.string(from: NSNumber(value: callAmount)) ?? "\(callAmount)"
            checkCallButton.setTitle("CALL $\(formattedCall)", for: .normal)
            checkCallButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 12) ?? .boldSystemFont(ofSize: 12)
            updateButtonGradient(checkCallButton, colors: [
                UIColor(red: 0.2, green: 0.5, blue: 0.85, alpha: 1.0).cgColor,
                UIColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 1.0).cgColor
            ])
        }
        updateButtonState(checkCallButton, enabled: canCheck || canCall)
        
        updateButtonState(raiseButton, enabled: actions.contains { if case .raise = $0 { return true } else { return false } })
        updateButtonState(allInButton, enabled: actions.contains { if case .allIn = $0 { return true } else { return false } })
        
        // Update raise amount display
        updateRaiseAmountDisplay()
        
        // Animate appearance
        transform = CGAffineTransform(translationX: 0, y: 100)
        alpha = 0
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    private func updateButtonState(_ button: UIButton, enabled: Bool) {
        button.isEnabled = enabled
        button.alpha = enabled ? 1.0 : 0.4
        button.layer.borderColor = enabled ?
            UIColor.white.withAlphaComponent(0.4).cgColor :
            UIColor.white.withAlphaComponent(0.2).cgColor
    }
    
    private func updateButtonGradient(_ button: UIButton, colors: [CGColor]) {
        if let gradientLayer = button.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.colors = colors
        }
    }
    
    private func updateRaiseAmountDisplay() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if let formatted = formatter.string(from: NSNumber(value: currentRaiseAmount)) {
            raiseAmountLabel.text = "$\(formatted)"
        }
        
        // Update button states
        minusButton.isEnabled = currentRaiseAmount > minRaise
        minusButton.alpha = minusButton.isEnabled ? 1.0 : 0.5
        
        plusButton.isEnabled = currentRaiseAmount < maxRaise
        plusButton.alpha = plusButton.isEnabled ? 1.0 : 0.5
    }
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) {
            sender.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            sender.transform = .identity
        }
    }
    
    @objc private func controlButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.08) {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }
    }
    
    @objc private func controlButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            sender.transform = .identity
        }
    }
    
    @objc private func foldTapped() {
        addHapticFeedback(.medium)
        onAction?(.fold)
        hideWithAnimation()
    }
    
    @objc private func checkCallTapped() {
        addHapticFeedback(.light)
        if checkCallButton.title(for: .normal) == "CHECK" {
            onAction?(.check)
        } else {
            onAction?(.call)
        }
        hideWithAnimation()
    }
    
    @objc private func raiseTapped() {
        addHapticFeedback(.light)
        
        if raiseControlsContainer.isHidden {
            showRaiseControls()
        } else {
            onAction?(.raise(currentRaiseAmount))
            hideWithAnimation()
        }
    }
    
    @objc private func minusTapped() {
        addHapticFeedback(.light)
        currentRaiseAmount = max(minRaise, currentRaiseAmount - raiseIncrement)
        animateAmountChange()
    }
    
    @objc private func plusTapped() {
        addHapticFeedback(.light)
        currentRaiseAmount = min(maxRaise, currentRaiseAmount + raiseIncrement)
        animateAmountChange()
    }
    
    @objc private func minRaiseTapped() {
        addHapticFeedback(.light)
        currentRaiseAmount = minRaise
        animateAmountChange()
    }
    
    @objc private func maxRaiseTapped() {
        addHapticFeedback(.medium)
        currentRaiseAmount = maxRaise
        animateAmountChange()
    }
    
    private func animateAmountChange() {
        UIView.animate(withDuration: 0.1, animations: {
            self.raiseAmountLabel.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
                self.raiseAmountLabel.transform = .identity
            }
        }
        updateRaiseAmountDisplay()
    }
    
    private func showRaiseControls() {
        chipIndicatorLabel.isHidden = true
        raiseControlsContainer.isHidden = false
        
        raiseButton.setTitle("✓ CONFIRM", for: .normal)
        updateButtonGradient(raiseButton, colors: [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor,
            UIColor(red: 0.8, green: 0.64, blue: 0.0, alpha: 1.0).cgColor
        ])
        
        raiseControlsContainer.alpha = 0
        raiseControlsContainer.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.raiseControlsContainer.alpha = 1
            self.raiseControlsContainer.transform = .identity
        }
    }
    
    @objc private func allInTapped() {
        addHapticFeedback(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.addHapticFeedback(.heavy)
        }
        onAction?(.allIn)
        hideWithAnimation()
    }
    
    private func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    private func hideWithAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 50).scaledBy(x: 0.92, y: 0.92)
        }) { _ in
            self.isHidden = true
            self.transform = .identity
            self.resetRaiseControls()
        }
    }
    
    private func resetRaiseControls() {
        raiseControlsContainer.isHidden = true
        chipIndicatorLabel.isHidden = false
        raiseButton.setTitle("RAISE", for: .normal)
        updateButtonGradient(raiseButton, colors: [
            UIColor(red: 0.95, green: 0.65, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.75, green: 0.45, blue: 0.1, alpha: 1.0).cgColor
        ])
        currentRaiseAmount = minRaise
    }
}
