//
//  MineSliderView.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 6/5/25.
//


// this is work in progress.... ie its to improve the slider further but to complex will do it in my free time

//import UIKit
//
//class MineSliderView: UIView {
//    
//    // MARK: - UI Components
//    private let containerView = UIView()
//    private let difficultyStackView = UIStackView()
//    private let safeLabel = UILabel()
//    private let riskyLabel = UILabel()
//    private let trackView = UIView()
//    private let gradientLayer = CAGradientLayer()
//    private let thumbView = UIView()
//    private let bombImageView = UILabel()
//    private let rangeStackView = UIStackView()
//    private let minLabel = UILabel()
//    private let maxLabel = UILabel()
//    
//    // MARK: - Properties
//    private var minValue: Float = 4
//    private var maxValue: Float = 16
//    private var currentValue: Float = 4 {
//        didSet {
//            updateThumbPosition()
//            valueChanged?(currentValue)
//        }
//    }
//    
//    // MARK: - Callbacks
//    var valueChanged: ((Float) -> Void)?
//    
//    // MARK: - Initializers
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        setupView()
//    }
//    
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        setupView()
//    }
//    
//    // MARK: - Setup
//    private func setupView() {
//        setupContainerView()
//        setupDifficultyLabels()
//        setupTrackView()
//        setupThumbView()
//        setupRangeLabels()
//        setupLayout()
//        setupGestures()
//    }
//    
//    private func setupContainerView() {
//        addSubview(containerView)
//        containerView.translatesAutoresizingMaskIntoConstraints = false
//    }
//    
//    private func setupDifficultyLabels() {
//        // Safe label with bomb emoji
//        safeLabel.text = "💣 Safe"
//        safeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
//        safeLabel.textColor = UIColor.systemGray
//        
//        // Risky label with multiple bomb emojis
//        riskyLabel.text = "Risky 💣💣💣"
//        riskyLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
//        riskyLabel.textColor = UIColor.systemGray
//        
//        // Stack view for difficulty labels
//        difficultyStackView.axis = .horizontal
//        difficultyStackView.distribution = .equalSpacing
//        difficultyStackView.addArrangedSubview(safeLabel)
//        difficultyStackView.addArrangedSubview(riskyLabel)
//        
//        containerView.addSubview(difficultyStackView)
//        difficultyStackView.translatesAutoresizingMaskIntoConstraints = false
//    }
//    
//    private func setupTrackView() {
//        trackView.layer.cornerRadius = 8
//        trackView.clipsToBounds = true
//        
//        // Gradient from green to red
//        gradientLayer.colors = [
//            UIColor.systemGreen.withAlphaComponent(0.6).cgColor,
//            UIColor.systemYellow.withAlphaComponent(0.7).cgColor,
//            UIColor.systemOrange.withAlphaComponent(0.8).cgColor,
//            UIColor.systemRed.withAlphaComponent(0.8).cgColor
//        ]
//        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
//        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
//        gradientLayer.cornerRadius = 8
//        
//        trackView.layer.addSublayer(gradientLayer)
//        containerView.addSubview(trackView)
//        trackView.translatesAutoresizingMaskIntoConstraints = false
//    }
//    
//    private func setupThumbView() {
//        thumbView.backgroundColor = UIColor.white
//        thumbView.layer.cornerRadius = 15 // Will be a 30x30 circle
//        thumbView.layer.shadowColor = UIColor.black.cgColor
//        thumbView.layer.shadowOffset = CGSize(width: 0, height: 2)
//        thumbView.layer.shadowRadius = 4
//        thumbView.layer.shadowOpacity = 0.3
//        thumbView.layer.borderWidth = 2
//        thumbView.layer.borderColor = UIColor.systemGray3.cgColor
//        
//        // Bomb emoji in the center
//        bombImageView.text = "💣"
//        bombImageView.font = UIFont.systemFont(ofSize: 16)
//        bombImageView.textAlignment = .center
//        thumbView.addSubview(bombImageView)
//        bombImageView.translatesAutoresizingMaskIntoConstraints = false
//        
//        containerView.addSubview(thumbView)
//        thumbView.translatesAutoresizingMaskIntoConstraints = false
//    }
//    
//    private func setupRangeLabels() {
//        minLabel.text = "\(Int(minValue))"
//        minLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
//        minLabel.textColor = UIColor.systemGray2
//        minLabel.textAlignment = .left
//        
//        maxLabel.text = "\(Int(maxValue))"
//        maxLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
//        maxLabel.textColor = UIColor.systemGray2
//        maxLabel.textAlignment = .right
//        
//        rangeStackView.axis = .horizontal
//        rangeStackView.distribution = .equalSpacing
//        rangeStackView.addArrangedSubview(minLabel)
//        rangeStackView.addArrangedSubview(maxLabel)
//        
//        containerView.addSubview(rangeStackView)
//        rangeStackView.translatesAutoresizingMaskIntoConstraints = false
//    }
//    
//    private func setupLayout() {
//        NSLayoutConstraint.activate([
//            // Container view
//            containerView.topAnchor.constraint(equalTo: topAnchor),
//            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
//            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
//            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
//            
//            // Difficulty labels
//            difficultyStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
//            difficultyStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//            difficultyStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//            difficultyStackView.heightAnchor.constraint(equalToConstant: 20),
//            
//            // Track view
//            trackView.topAnchor.constraint(equalTo: difficultyStackView.bottomAnchor, constant: 8),
//            trackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//            trackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//            trackView.heightAnchor.constraint(equalToConstant: 16),
//            
//            // Thumb view (will be positioned dynamically)
//            thumbView.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),
//            thumbView.widthAnchor.constraint(equalToConstant: 30),
//            thumbView.heightAnchor.constraint(equalToConstant: 30),
//            
//            // Bomb emoji inside thumb
//            bombImageView.centerXAnchor.constraint(equalTo: thumbView.centerXAnchor),
//            bombImageView.centerYAnchor.constraint(equalTo: thumbView.centerYAnchor),
//            bombImageView.widthAnchor.constraint(equalToConstant: 20),
//            bombImageView.heightAnchor.constraint(equalToConstant: 20),
//            
//            // Range labels
//            rangeStackView.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
//            rangeStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
//            rangeStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
//            rangeStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
//            rangeStackView.heightAnchor.constraint(equalToConstant: 16)
//        ])
//    }
//    
//    private func setupGestures() {
//        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
//        thumbView.addGestureRecognizer(panGesture)
//        
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
//        trackView.addGestureRecognizer(tapGesture)
//    }
//    
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        gradientLayer.frame = trackView.bounds
//        updateThumbPosition()
//    }
//    
//    // MARK: - Public Methods
//    func setValue(_ value: Float, animated: Bool = false) {
//        let clampedValue = max(minValue, min(maxValue, value))
//        
//        if animated {
//            UIView.animate(withDuration: 0.2) {
//                self.currentValue = clampedValue
//            }
//        } else {
//            self.currentValue = clampedValue
//        }
//    }
//    
//    func setRange(min: Float, max: Float) {
//        self.minValue = min
//        self.maxValue = max
//        self.minLabel.text = "\(Int(min))"
//        self.maxLabel.text = "\(Int(max))"
//        
//        // Clamp current value to new range
//        self.currentValue = Swift.max(min, Swift.min(max, currentValue))
//    }
//    
//    var value: Float {
//        return currentValue
//    }
//    
//    // MARK: - Private Methods
//    private func updateThumbPosition() {
//        let percentage = (currentValue - minValue) / (maxValue - minValue)
//        let trackWidth = trackView.bounds.width
//        let thumbWidth: CGFloat = 30
//        
//        // Calculate position accounting for thumb width
//        let availableWidth = trackWidth - thumbWidth
//        let xPosition = CGFloat(percentage) * availableWidth
//        
//        // Update constraint or transform
//        thumbView.transform = CGAffineTransform(translationX: xPosition, y: 0)
//    }
//    
//    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
//        let translation = gesture.translation(in: trackView)
//        let trackWidth = trackView.bounds.width
//        let thumbWidth: CGFloat = 30
//        let availableWidth = trackWidth - thumbWidth
//        
//        // Calculate new percentage based on translation
//        let currentPercentage = (currentValue - minValue) / (maxValue - minValue)
//        let currentX = CGFloat(currentPercentage) * availableWidth
//        let newX = max(0, min(availableWidth, currentX + translation.x))
//        let newPercentage = newX / availableWidth
//        
//        // Convert back to value
//        let newValue = minValue + Float(newPercentage) * (maxValue - minValue)
//        
//        // Round to nearest even number (as in your original code)
//        let roundedValue = Float(Int(round(newValue / 2)) * 2)
//        let clampedValue = max(minValue, min(maxValue, roundedValue))
//        
//        currentValue = clampedValue
//        
//        // Reset translation
//        gesture.setTranslation(.zero, in: trackView)
//        
//        // Add haptic feedback
//        if gesture.state == .changed {
//            let impactGenerator = UIImpactFeedbackGenerator(style: .light)
//            impactGenerator.impactOccurred()
//        }
//    }
//    
//    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
//        let location = gesture.location(in: trackView)
//        let trackWidth = trackView.bounds.width
//        let thumbWidth: CGFloat = 30
//        let availableWidth = trackWidth - thumbWidth
//        
//        // Calculate percentage from tap location
//        let tappedX = max(0, min(availableWidth, location.x - thumbWidth/2))
//        let percentage = tappedX / availableWidth
//        
//        // Convert to value
//        let newValue = minValue + Float(percentage) * (maxValue - minValue)
//        let roundedValue = Float(Int(round(newValue / 2)) * 2)
//        let clampedValue = max(minValue, min(maxValue, roundedValue))
//        
//        setValue(clampedValue, animated: true)
//        
//        // Add haptic feedback
//        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
//        impactGenerator.impactOccurred()
//    }
//}
