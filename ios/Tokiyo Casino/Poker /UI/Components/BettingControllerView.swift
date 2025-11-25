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
    private let raiseSlider = UISlider()
    private let raiseAmountLabel = UILabel()
    private let buttonStackView = UIStackView()
    
    // Enhanced UI elements
    private let containerView = UIView()
    private let chipIndicatorLabel = UILabel()
    private let potentialWinLabel = UILabel()
    private let actionTitleLabel = UILabel()
    
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
        // Container with gradient background
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Add gradient to container
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 0.95).cgColor,
            UIColor(red: 0.02, green: 0.08, blue: 0.02, alpha: 0.98).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = bounds
        containerView.layer.insertSublayer(gradientLayer, at: 0)
        containerView.layer.cornerRadius = 20
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 0.4).cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: -4)
        containerView.layer.shadowOpacity = 0.5
        containerView.layer.shadowRadius = 12
        
        // Action title label
        actionTitleLabel.text = ""
        actionTitleLabel.font = UIFont(name: "Copperplate", size: 12) ?? .systemFont(ofSize: 12, weight: .bold)
        actionTitleLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        actionTitleLabel.textAlignment = .center
        actionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(actionTitleLabel)
        
        // Setup stack view for buttons
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 10
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonStackView)
        
        // Configure buttons with enhanced styling
        setupButton(foldButton, title: "FOLD", gradient: [
            UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 1.0).cgColor
        ], action: #selector(foldTapped))
        
        setupButton(checkCallButton, title: "CHECK", gradient: [
            UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0).cgColor,
            UIColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0).cgColor
        ], action: #selector(checkCallTapped))
        
        setupButton(raiseButton, title: "RAISE", gradient: [
            UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.7, green: 0.4, blue: 0.1, alpha: 1.0).cgColor
        ], action: #selector(raiseTapped))
        
        setupButton(allInButton, title: "ALL IN", gradient: [
            UIColor(red: 0.6, green: 0.2, blue: 0.8, alpha: 1.0).cgColor,
            UIColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1.0).cgColor
        ], action: #selector(allInTapped))
        
        // Raise amount label with enhanced styling
        raiseAmountLabel.textColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        raiseAmountLabel.font = UIFont(name: "Copperplate-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        raiseAmountLabel.textAlignment = .center
        raiseAmountLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        raiseAmountLabel.layer.cornerRadius = 12
        raiseAmountLabel.layer.masksToBounds = true
        raiseAmountLabel.layer.borderWidth = 1
        raiseAmountLabel.layer.borderColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.5).cgColor
        raiseAmountLabel.isHidden = true
        raiseAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(raiseAmountLabel)
        
        // Enhanced raise slider
        raiseSlider.minimumTrackTintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        raiseSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.3)
        raiseSlider.thumbTintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        raiseSlider.layer.shadowColor = UIColor.black.cgColor
        raiseSlider.layer.shadowOffset = CGSize(width: 0, height: 2)
        raiseSlider.layer.shadowOpacity = 0.4
        raiseSlider.layer.shadowRadius = 3
        raiseSlider.isHidden = true
        raiseSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        raiseSlider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(raiseSlider)
        
        // Chip indicator (shows available chips)
        chipIndicatorLabel.font = UIFont(name: "Copperplate", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        chipIndicatorLabel.textColor = .white.withAlphaComponent(0.8)
        chipIndicatorLabel.textAlignment = .center
        chipIndicatorLabel.isHidden = true
        chipIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(chipIndicatorLabel)
        
        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Action title
            actionTitleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            actionTitleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            // Button stack view
            buttonStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            buttonStackView.heightAnchor.constraint(equalToConstant: 60),
            
            // Chip indicator
            chipIndicatorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            chipIndicatorLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -8),
            
            // Raise amount label
            raiseAmountLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            raiseAmountLabel.bottomAnchor.constraint(equalTo: buttonStackView.topAnchor, constant: -12),
            raiseAmountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            raiseAmountLabel.heightAnchor.constraint(equalToConstant: 38),
            
            // Slider
            raiseSlider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            raiseSlider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            raiseSlider.bottomAnchor.constraint(equalTo: raiseAmountLabel.topAnchor, constant: -12),
            raiseSlider.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        // Update gradient frame on layout
        layoutIfNeeded()
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
        // Create gradient layer
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = gradient
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.cornerRadius = 12
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 13) ?? .boldSystemFont(ofSize: 13)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowOpacity = 0.4
        button.layer.shadowRadius = 4
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        buttonStackView.addArrangedSubview(button)
    }
    
    func updateForActions(_ actions: [PlayerAction], callAmount: Int, minRaise: Int, maxRaise: Int) {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        self.callAmount = callAmount
        self.minRaise = minRaise
        self.maxRaise = maxRaise
        
        // Update chip indicator
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if let formatted = formatter.string(from: NSNumber(value: maxRaise)) {
            chipIndicatorLabel.text = "💰 Available: $\(formatted)"
            chipIndicatorLabel.isHidden = false
        }
        
        // Update button states and titles
        updateButtonState(foldButton, enabled: actions.contains { if case .fold = $0 { return true } else { return false } })
        
        let canCheck = actions.contains { if case .check = $0 { return true } else { return false } }
        let canCall = actions.contains { if case .call = $0 { return true } else { return false } }
        
        if canCheck {
            checkCallButton.setTitle("CHECK", for: .normal)
            updateButtonGradient(checkCallButton, colors: [
                UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0).cgColor,
                UIColor(red: 0.15, green: 0.5, blue: 0.2, alpha: 1.0).cgColor
            ])
        } else if canCall {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            let formattedCall = formatter.string(from: NSNumber(value: callAmount)) ?? "\(callAmount)"
            checkCallButton.setTitle("CALL $\(formattedCall)", for: .normal)
            checkCallButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 11) ?? .boldSystemFont(ofSize: 11)
            updateButtonGradient(checkCallButton, colors: [
                UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0).cgColor,
                UIColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1.0).cgColor
            ])
        }
        updateButtonState(checkCallButton, enabled: canCheck || canCall)
        
        updateButtonState(raiseButton, enabled: actions.contains { if case .raise = $0 { return true } else { return false } })
        updateButtonState(allInButton, enabled: actions.contains { if case .allIn = $0 { return true } else { return false } })
        
        // Setup slider
        if raiseButton.isEnabled {
            raiseSlider.minimumValue = Float(minRaise)
            raiseSlider.maximumValue = Float(maxRaise)
            raiseSlider.value = Float(minRaise)
            sliderChanged()
        }
        
        // Animate appearance with spring animation
        transform = CGAffineTransform(translationX: 0, y: 100)
        alpha = 0
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
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
    
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        }
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.alpha = sender.isEnabled ? 1.0 : 0.4
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
        
        if raiseSlider.isHidden {
            // Show slider with animation
            showRaiseControls()
        } else {
            // Confirm raise
            let amount = Int(raiseSlider.value)
            onAction?(.raise(amount))
            hideWithAnimation()
        }
    }
    
    private func showRaiseControls() {
        raiseSlider.isHidden = false
        raiseAmountLabel.isHidden = false
        chipIndicatorLabel.isHidden = true
        
        // Update raise button
        raiseButton.setTitle("CONFIRM", for: .normal)
        updateButtonGradient(raiseButton, colors: [
            UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor,
            UIColor(red: 0.8, green: 0.64, blue: 0.0, alpha: 1.0).cgColor
        ])
        
        // Animate slider appearance
        raiseSlider.alpha = 0
        raiseAmountLabel.alpha = 0
        raiseSlider.transform = CGAffineTransform(translationX: 0, y: 20)
        raiseAmountLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.raiseSlider.alpha = 1
            self.raiseAmountLabel.alpha = 1
            self.raiseSlider.transform = .identity
            self.raiseAmountLabel.transform = .identity
        }
    }
    
    @objc private func allInTapped() {
        addHapticFeedback(.heavy)
        
        // Extra confirmation haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.addHapticFeedback(.heavy)
        }
        
        onAction?(.allIn)
        hideWithAnimation()
    }
    
    @objc private func sliderChanged() {
        // Round to nearest 10
        let amount = Int(raiseSlider.value / 10) * 10
        raiseSlider.value = Float(amount)
        
        // Format with commas
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        if let formatted = formatter.string(from: NSNumber(value: amount)) {
            raiseAmountLabel.text = "$\(formatted)"
        }
        
        // Add bounce animation
        UIView.animate(withDuration: 0.1, animations: {
            self.raiseAmountLabel.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.raiseAmountLabel.transform = .identity
            }
        }
        
        // Light haptic feedback while sliding
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    private func hideWithAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 50).scaledBy(x: 0.95, y: 0.95)
        }) { _ in
            self.isHidden = true
            self.transform = .identity
            self.resetRaiseControls()
        }
    }
    
    private func resetRaiseControls() {
        raiseSlider.isHidden = true
        raiseAmountLabel.isHidden = true
        chipIndicatorLabel.isHidden = false
        raiseButton.setTitle("RAISE", for: .normal)
        updateButtonGradient(raiseButton, colors: [
            UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0).cgColor,
            UIColor(red: 0.7, green: 0.4, blue: 0.1, alpha: 1.0).cgColor
        ])
    }
}
