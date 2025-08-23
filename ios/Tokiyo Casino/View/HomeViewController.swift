//
//  HomeViewController.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 5/28/25.
//

import UIKit

class HomeViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    // MARK: - Outlets
    @IBOutlet weak var labelTotalCoins: UILabel!
    @IBOutlet weak var imageTokioSlots: UIImageView!
    @IBOutlet weak var imageTokioLotto: UIImageView!
    @IBOutlet weak var imageTokioCoino: UIImageView!
    @IBOutlet weak var buttonPlaySlots: UIImageView!
    @IBOutlet weak var buttonPlayLotto: UIImageView!
    @IBOutlet weak var buttonPlayCoino: UIImageView!
    @IBOutlet weak var treasureChestImage: UIImageView!
    
    private var viewModel = HomeViewModel()
    private var hasShownDailyRewardAlert = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViewModel()
        setupTapGestures()
        setupInitialAnimations()
        
        // Listen for coin changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coinsDidChange),
            name: CoinsManager.coinsDidChangeNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.fetchUserStats()
        updateUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Show daily reward alert if available and not shown yet
        if !hasShownDailyRewardAlert && viewModel.canCollectCoins {
            showDailyRewardAlert()
            hasShownDailyRewardAlert = true
        }
        
        // Start idle animations
        startIdleAnimations()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopIdleAnimations()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    private func setupViewModel() {
        viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async { self?.updateUI() }
        }
        viewModel.fetchUserStats()
        viewModel.checkDailyReward()
        updateUI()
    }

    private func setupTapGestures() {
        // Game card tap gestures
        [imageTokioSlots, imageTokioLotto, imageTokioCoino].forEach { iv in
            iv?.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapGameCard(_:)))
            iv?.addGestureRecognizer(tap)
        }
        
        // Play button tap gestures
        [buttonPlaySlots, buttonPlayLotto, buttonPlayCoino].forEach { iv in
            iv?.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapPlayButton(_:)))
            iv?.addGestureRecognizer(tap)
        }
        
        // Treasure chest tap
        treasureChestImage.isUserInteractionEnabled = true
        let chestTap = UITapGestureRecognizer(target: self, action: #selector(didTapTreasureChest))
        treasureChestImage.addGestureRecognizer(chestTap)
    }
    
    private func setupInitialAnimations() {
        // Set initial transforms for entrance animations
        [imageTokioSlots, imageTokioLotto, imageTokioCoino].forEach { imageView in
            imageView?.transform = CGAffineTransform(translationX: 0, y: 50).scaledBy(x: 0.8, y: 0.8)
            imageView?.alpha = 0
        }
        
        treasureChestImage.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        treasureChestImage.alpha = 0
        
        // Animate entrance
        UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.imageTokioSlots.transform = .identity
            self.imageTokioSlots.alpha = 1
        }
        
        UIView.animate(withDuration: 0.8, delay: 0.4, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.imageTokioLotto.transform = .identity
            self.imageTokioLotto.alpha = 1
        }
        
        UIView.animate(withDuration: 0.8, delay: 0.6, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.imageTokioCoino.transform = .identity
            self.imageTokioCoino.alpha = 1
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.8, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.3) {
            self.treasureChestImage.transform = .identity
            self.treasureChestImage.alpha = 1
        }
    }

    // MARK: - UI Update
    private func updateUI() {
        // Animate coin counter update
        let newCoinText = "\(viewModel.totalCoins)"
        if labelTotalCoins.text != newCoinText {
            animateCoinUpdate(to: newCoinText)
        }
        
        // Update treasure chest availability
        let canClaim = viewModel.canCollectCoins
        treasureChestImage.alpha = canClaim ? 1.0 : 0.6
        treasureChestImage.isUserInteractionEnabled = canClaim
        
        if canClaim {
            addGlowEffect(to: treasureChestImage)
        } else {
            removeGlowEffect(from: treasureChestImage)
        }
    }
    
    @objc private func coinsDidChange() {
        viewModel.fetchUserStats()
        updateUI()
    }

    // MARK: - Actions
    @objc private func didTapGameCard(_ sender: UITapGestureRecognizer) {
        guard let iv = sender.view as? UIImageView else { return }
        animateGameCardTap(iv) {
            switch iv {
            case self.imageTokioSlots:
                self.performSegue(withIdentifier: K.toSlotVC, sender: nil)
            case self.imageTokioLotto:
                self.performSegue(withIdentifier: K.toLottoVC, sender: nil)
            case self.imageTokioCoino:
                self.performSegue(withIdentifier: K.toCoinoVC, sender: nil)
            default: break
            }
        }
    }
    
    @objc private func didTapPlayButton(_ sender: UITapGestureRecognizer) {
        guard let iv = sender.view as? UIImageView else { return }
        animateImageButtonTap(iv) {
            switch iv {
            case self.buttonPlaySlots:
                self.performSegue(withIdentifier: K.toSlotVC, sender: nil)
            case self.buttonPlayLotto:
                self.performSegue(withIdentifier: K.toLottoVC, sender: nil)
            case self.buttonPlayCoino:
                self.performSegue(withIdentifier: K.toCoinoVC, sender: nil)
            default: break
            }
        }
    }
    
    @objc private func didTapTreasureChest() {
        guard viewModel.canCollectCoins else { return }
        
        animateTreasureChestTap {
            self.showDailyRewardAlert()
        }
    }

    // MARK: - Animations
    private func animateGameCardTap(_ view: UIView, completion: @escaping () -> Void) {
        // Scale and rotation animation
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).rotated(by: -0.02)
        }) { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                view.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    view.transform = .identity
                } completion: { _ in
                    completion()
                }
            }
        }
    }
    
    private func animateImageButtonTap(_ imageView: UIImageView, completion: @escaping () -> Void) {
        // Pulse animation for play button images
        UIView.animate(withDuration: 0.08, animations: {
            imageView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            imageView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.12, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
                imageView.transform = .identity
                imageView.alpha = 1.0
            } completion: { _ in
                completion()
            }
        }
    }
    
    private func animateTreasureChestTap(completion: @escaping () -> Void) {
        // Treasure chest shake and scale animation
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        shakeAnimation.values = [0, -0.1, 0.1, -0.05, 0.05, 0]
        shakeAnimation.duration = 0.3
        shakeAnimation.repeatCount = 1
        
        UIView.animate(withDuration: 0.1, animations: {
            self.treasureChestImage.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { _ in
            self.treasureChestImage.layer.add(shakeAnimation, forKey: "shake")
            UIView.animate(withDuration: 0.2) {
                self.treasureChestImage.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }
    
    private func animateCoinUpdate(to newText: String) {
        // Scale up and fade animation for coin counter
        UIView.animate(withDuration: 0.15, animations: {
            self.labelTotalCoins.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.labelTotalCoins.alpha = 0.7
        }) { _ in
            self.labelTotalCoins.text = newText
            self.labelTotalCoins.font = UIFont(name: "Pocket Monk", size: 30)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.labelTotalCoins.transform = .identity
                self.labelTotalCoins.alpha = 1.0
            }
        }
    }
    
    // MARK: - Idle Animations
    private func startIdleAnimations() {
        // Gentle floating animation for game cards
        animateFloating(imageTokioSlots, delay: 0)
        animateFloating(imageTokioLotto, delay: 1.0)
        animateFloating(imageTokioCoino, delay: 2.0)
        
        // Treasure chest glow animation if available
        if viewModel.canCollectCoins {
            animateTreasureChestGlow()
        }
    }
    
    private func stopIdleAnimations() {
        imageTokioSlots.layer.removeAllAnimations()
        imageTokioLotto.layer.removeAllAnimations()
        imageTokioCoino.layer.removeAllAnimations()
        treasureChestImage.layer.removeAllAnimations()
    }
    
    private func animateFloating(_ view: UIView, delay: TimeInterval) {
        UIView.animate(withDuration: 2.0, delay: delay, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            view.transform = CGAffineTransform(translationX: 0, y: -8)
        }
    }
    
    private func animateTreasureChestGlow() {
        UIView.animate(withDuration: 1.5, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.treasureChestImage.alpha = 0.7
        }
    }
    
    // MARK: - Visual Effects
    private func addGlowEffect(to view: UIView) {
        view.layer.shadowColor = UIColor.systemYellow.cgColor
        view.layer.shadowRadius = 10
        view.layer.shadowOpacity = 0.6
        view.layer.shadowOffset = .zero
    }
    
    private func removeGlowEffect(from view: UIView) {
        view.layer.shadowOpacity = 0
    }

    // MARK: - Daily Reward Alert
    private func showDailyRewardAlert() {
        let alert = UIAlertController(
            title: "🎁 Daily Reward!",
            message: "Claim your daily 1000 coins now!",
            preferredStyle: .alert
        )
        
        // Collect Now action
        let collectAction = UIAlertAction(title: "Collect Now! 🪙", style: .default) { _ in
            self.collectDailyReward()
        }
        
        // Not Now action
        let laterAction = UIAlertAction(title: "Not Now", style: .cancel, handler: nil)
        
        alert.addAction(collectAction)
        alert.addAction(laterAction)
        
        // Make the collect button more prominent
        alert.preferredAction = collectAction
        
        present(alert, animated: true)
    }
    
    private func collectDailyReward() {
        // Animate coin collection
        viewModel.collectCoins()
        
        // Show celebration animation
        showCoinCollectionCelebration()
        
        // Show success feedback
        let successAlert = UIAlertController(
            title: "🎉 Reward Claimed!",
            message: "You've successfully claimed 1000 coins!",
            preferredStyle: .alert
        )
        successAlert.addAction(UIAlertAction(title: "Awesome!", style: .default))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.present(successAlert, animated: true)
        }
    }
    
    private func showCoinCollectionCelebration() {
        // Create floating coins animation
        for i in 0..<5 {
            let coinLabel = UILabel()
            coinLabel.text = "🪙"
            coinLabel.font = UIFont.systemFont(ofSize: 24)
            coinLabel.frame = CGRect(x: treasureChestImage.center.x, y: treasureChestImage.center.y, width: 30, height: 30)
            view.addSubview(coinLabel)
            
            let randomX = CGFloat.random(in: -100...100)
            let randomY = CGFloat.random(in: -150...(-50))
            
            UIView.animate(withDuration: 1.5, delay: Double(i) * 0.1, options: .curveEaseOut, animations: {
                coinLabel.center = CGPoint(x: coinLabel.center.x + randomX, y: coinLabel.center.y + randomY)
                coinLabel.alpha = 0
                coinLabel.transform = CGAffineTransform(scaleX: 2, y: 2)
            }) { _ in
                coinLabel.removeFromSuperview()
            }
        }
    }
}
