//
//  FlipGameViewController.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 6/9/25.
//

import UIKit

class FlipGameViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var backImageView: UIImageView!
    @IBOutlet weak var plusImageView: UIImageView!
    @IBOutlet weak var minusImageView: UIImageView!
    @IBOutlet weak var betTextField: UITextField!
    @IBOutlet weak var choiceControl: UISegmentedControl!
    @IBOutlet weak var coinImageView: UIImageView!
    @IBOutlet weak var betButton: UIButton!
    
    private var soundManager = SoundManager()
    //@IBOutlet weak var coinsLabel: UILabel!

    // MARK: - Properties
    private let viewModel = FlipGameViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        refreshUI()
        setupGestures()
        BackgroundSoundManager.shared.setupPlayer(soundName: "bg_coino", soundType: .mp3)
           BackgroundSoundManager.shared.volume(0.2)
           BackgroundSoundManager.shared.play()
    }

    private func setupUI() {
        betTextField.keyboardType = .numberPad
        betTextField.text = "\(viewModel.currentBet)"
        betTextField.font = UIFont(name: "Pocket Monk", size: 24)
        betButton.layer.cornerRadius = 8
        coinImageView.image = UIImage(named: "Heads")
        
        // ✅ Change font of Segmented Control (Heads / Tails)
        let font = UIFont(name: "Pocket Monk", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        choiceControl.setTitleTextAttributes(normalAttributes, for: .normal)
        choiceControl.setTitleTextAttributes(selectedAttributes, for: .selected)
    }


    private func setupGestures() {
        [backImageView, plusImageView, minusImageView].forEach { imgView in
            imgView?.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleImageTap(_:)))
            imgView?.addGestureRecognizer(tap)
        }
    }

    
    private func refreshUI() {
        //coinsLabel.text = "Coins: \(viewModel.totalCoins)"
        betTextField.text = "\(viewModel.currentBet)"
    }

    @objc private func handleImageTap(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        animateTap(on: view)
        switch view {
        case backImageView:
            dismiss(animated: true)
            BackgroundSoundManager.shared.pause()
        case plusImageView:
            viewModel.updateBet(by: viewModel.minBet)
            soundManager.setupPlayer(soundName: "button_tap", soundType: .mp3)
            soundManager.play()
            
        case minusImageView:
            viewModel.updateBet(by: -viewModel.minBet)
            soundManager.setupPlayer(soundName: "button_tap", soundType: .mp3)
            soundManager.play()
            
        default: break
        }
        refreshUI()
    }

    @IBAction func betButtonTapped(_ sender: UIButton) {
        let validation = viewModel.validate(betString: betTextField.text)
        
        soundManager.setupPlayer(soundName: "coin_flip_sound", soundType: .mp3)
        soundManager.play()
        
        viewModel.currentBet = validation.amount
        refreshUI()
        if let err = validation.errorMessage {
            shakeField()
            showAlert(title: "Invalid Bet", message: err)
            return
        }

        performFlipAnimation(times: 6, totalDuration: 0.6) {
            let index = self.choiceControl.selectedSegmentIndex
            let choice: FlipChoice = (index == 0) ? .heads : .tails

            
            self.viewModel.performFlip(choice: choice) { [self] result, won, reward in
               // let face = won ? "Heads" : "Tails"
                self.coinImageView.image = UIImage(named: result == .heads ? "Heads" : "Tails")
                let title = won ? "🎉 You Win!" : "☹️ You Lose"
                let msg = won
                    ? "You won \(reward) coins!"
                    : "You lost \(self.viewModel.currentBet) coins."
                if won {
                    self.soundManager.setupPlayer(soundName: "coino_win_sound", soundType: .wav)
                    soundManager.play()
                }
                self.showAlert(title: title, message: msg)
                self.refreshUI()
            }
        }
        
    }

    private func performFlipAnimation(times: Int, totalDuration: TimeInterval, completion: @escaping () -> Void) {
        guard times > 0 else {
            completion()
            return
        }
        let singleDuration = totalDuration / Double(times)
        UIView.transition(with: coinImageView, duration: singleDuration,
                          options: .transitionFlipFromLeft,
                          animations: {
            let current = self.coinImageView.image == UIImage(named: "Heads")
            self.coinImageView.image = UIImage(named: current ? "Tails" : "Heads")
        }) { _ in
            self.performFlipAnimation(times: times - 1, totalDuration: totalDuration, completion: completion)
        }
    }

    private func animateTap(on view: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                view.transform = .identity
            }
        }
    }

    private func shakeField() {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.duration = 0.5
        shake.values = [-8, 8, -8, 8, 0]
        betTextField.layer.add(shake, forKey: "shake")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
