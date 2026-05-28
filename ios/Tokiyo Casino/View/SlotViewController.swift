//
//  HomeViewController.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 5/25/25.
//

import UIKit
import CoreHaptics

enum SlotViewControllerMode {
    case casinoGame
    case dailyReward
}

class SlotViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var spinButtonImageView: UIImageView!
    @IBOutlet weak var backButton: UIImageView!       // Back arrow
    @IBOutlet weak var betAmountTextField: UITextField!
    @IBOutlet weak var plusButtonImageView: UIImageView!
    @IBOutlet weak var minusButtonImageView: UIImageView!

    // MARK: - Properties
    private var viewModel: SlotViewModel!

    private var winSound = SoundManager()
    private var loseSound = SoundManager()
    private var buttonTapSound = SoundManager()

    private var isSpinning = false
    private var originalSpinButtonImage: UIImage?
    private var pressedSpinButtonImage: UIImage?
    private var toolbar: UIToolbar!
    private var isReturningHomeAfterDailySpins = false
    var mode: SlotViewControllerMode = .casinoGame
    var impactGenerator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    var notificationImpact: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Only UI setup here; all bet logic lives in viewModel
        viewModel = SlotViewModel()
        viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async { self?.updateUI() }
        }

        setupUI()
        setupSounds()
        setupGestureRecognizers()
        setupTextFieldToolbar()
        configureModeVisibility()
        updateUI()

        // Pick random rows at start
        let rows = viewModel.spinSlots()
        for (col, row) in rows.enumerated() {
            pickerView.selectRow(row, inComponent: col, animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.onUpdate?() // Refresh UI with latest coins
        BackgroundSoundManager.shared.setupPlayer(soundName: "bg_soothing", soundType: .mp3)
        BackgroundSoundManager.shared.play()
        BackgroundSoundManager.shared.volume(0.3)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Animate spin button in
        UIView.animate(withDuration: 0.6,
                       delay: 0.2,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5,
                       options: []) {
            self.spinButtonImageView.transform = .identity
            self.spinButtonImageView.alpha = 1.0
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        BackgroundSoundManager.shared.stop()
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Picker styling
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.layer.cornerRadius = 15
        pickerView.layer.masksToBounds = true

        // Spin button images (if asset names differ, adjust here)
        originalSpinButtonImage = UIImage(named: "spinButton")
        pressedSpinButtonImage = UIImage(named: "spinButtonPressed")
        spinButtonImageView.image = originalSpinButtonImage

        // Hide and shrink initial state
        spinButtonImageView.alpha = 0
        spinButtonImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        // Bet text field
        betAmountTextField.keyboardType = .numberPad
        betAmountTextField.textAlignment = .center
        betAmountTextField.layer.cornerRadius = 8
        betAmountTextField.layer.borderWidth = 2
        betAmountTextField.layer.borderColor = UIColor.systemBlue.cgColor
        betAmountTextField.delegate = self

        // Dismiss keyboard on tap outside
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupSounds() {
        // Use "grand_win.mp3" for win, "loose_sound.mp3" for lose & tap
        if Bundle.main.url(forResource: "grand_win", withExtension: "mp3") != nil {
            winSound.setupPlayer(soundName: "grand_win", soundType: .mp3)
            winSound.volume(0.7)
        }
        if Bundle.main.url(forResource: "loose_sound", withExtension: "mp3") != nil {
            loseSound.setupPlayer(soundName: "loose_sound", soundType: .mp3)
            loseSound.volume(0.5)
            buttonTapSound.setupPlayer(soundName: "rattle", soundType: .m4a)
            buttonTapSound.volume(0.3)
        }
    }

    private func setupGestureRecognizers() {
        // Spin button
        let spinTap = UITapGestureRecognizer(target: self, action: #selector(spinButtonTapped))
        spinButtonImageView.addGestureRecognizer(spinTap)
        spinButtonImageView.isUserInteractionEnabled = true

        // Plus button
        let plusTap = UITapGestureRecognizer(target: self, action: #selector(plusButtonTapped))
        plusButtonImageView.addGestureRecognizer(plusTap)
        plusButtonImageView.isUserInteractionEnabled = true

        // Minus button
        let minusTap = UITapGestureRecognizer(target: self, action: #selector(minusButtonTapped))
        minusButtonImageView.addGestureRecognizer(minusTap)
        minusButtonImageView.isUserInteractionEnabled = true

        // Back button
        let backTap = UITapGestureRecognizer(target: self, action: #selector(backButtonTapped))
        backButton.addGestureRecognizer(backTap)
        backButton.isUserInteractionEnabled = true
    }

    private func setupTextFieldToolbar() {
        toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [spacer, done]
        betAmountTextField.inputAccessoryView = toolbar
    }

    private func configureModeVisibility() {
        let shouldShowBetControls = mode == .casinoGame
        betAmountTextField.isHidden = !shouldShowBetControls
        betAmountTextField.isUserInteractionEnabled = shouldShowBetControls
        plusButtonImageView.isHidden = !shouldShowBetControls
        plusButtonImageView.isUserInteractionEnabled = shouldShowBetControls
        minusButtonImageView.isHidden = !shouldShowBetControls
        minusButtonImageView.isUserInteractionEnabled = shouldShowBetControls
    }

    // MARK: - Actions

    @objc private func spinButtonTapped() {
        guard !isSpinning else { return }
        
        buttonTapSound.setupPlayer(soundName: "button_press_sound", soundType: .mp3)
        buttonTapSound.play()
        
        impactGenerator.prepare()
        impactGenerator.impactOccurred()

        if mode == .dailyReward {
            guard viewModel.canSpinForCoins else {
                showNoDailySpinsAlert()
                return
            }

            performDailyRewardSpin()
            return
        }
        
        // Validate the typed bet
        let validation = viewModel.validateBetInput(betAmountTextField.text)
        updateUI() // Reflect clamped amount if needed

        if let error = validation.error {
            showBetError(message: error.message)
            return
        }
        
        performSpin()
    }

    @objc private func plusButtonTapped() {
        guard mode == .casinoGame else { return }

        buttonTapSound.setupPlayer(soundName: "button_press_sound", soundType: .mp3)
        buttonTapSound.play()
        
        notificationImpact.prepare()
        notificationImpact.notificationOccurred(.success)
        
        animateButtonTap(on: plusButtonImageView)
        viewModel.increaseBet()
        updateUI()
    }

    @objc private func minusButtonTapped() {
        guard mode == .casinoGame else { return }

        buttonTapSound.setupPlayer(soundName: "button_press_sound", soundType: .mp3)
        buttonTapSound.play()
        
        animateButtonTap(on: minusButtonImageView)

        notificationImpact.prepare()
        notificationImpact.notificationOccurred(.success)
        
        let oldAmount = viewModel.currentBetAmount
        viewModel.decreaseBet()
        if viewModel.currentBetAmount == oldAmount {
            // Already at minimum, give a shake
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .linear)
            shake.duration = 0.4
            shake.values = [-5, 5, -5, 5, 0]
            minusButtonImageView.layer.add(shake, forKey: "shake")
            notificationImpact.notificationOccurred(.warning)
        }
        updateUI()
    }

    @objc private func backButtonTapped() {
        buttonTapSound.play()
        animateButtonTap(on: backButton)
        BackgroundSoundManager.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.dismiss(animated: true)
        }
    }

    @objc private func doneButtonTapped() {
        guard mode == .casinoGame else {
            dismissKeyboard()
            return
        }

        let validation = viewModel.validateBetInput(betAmountTextField.text)
        updateUI()
        if let error = validation.error {
            showBetError(message: error.message)
        }
        dismissKeyboard()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Game Logic

    private func performSpin() {
        isSpinning = true
        buttonTapSound.play()

        spinButtonImageView.image = pressedSpinButtonImage
        UIView.animate(withDuration: 0.1, animations: {
            self.spinButtonImageView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.spinButtonImageView.transform = .identity
            }
        }

        let rows = viewModel.spinSlots()
        for (col, row) in rows.enumerated() {
            pickerView.selectRow(row, inComponent: col, animated: true)
        }

        // Delay outcome until after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.viewModel.checkWinOrLose(selectedRows: rows) { message, reward, playWin, success in
                DispatchQueue.main.async {
                    if success {
                        self.handleSpinResult(message: message, reward: reward, playWinSound: playWin)
                    } else {
                        self.showErrorAlert(message: "Something went wrong. Try again.")
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.spinButtonImageView.image = self.originalSpinButtonImage
                        self.isSpinning = false
                        self.updateUI()
                    }
                }
            }
        }
    }

    private func performDailyRewardSpin() {
        isSpinning = true
        buttonTapSound.play()

        spinButtonImageView.image = pressedSpinButtonImage
        UIView.animate(withDuration: 0.1, animations: {
            self.spinButtonImageView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.spinButtonImageView.transform = .identity
            }
        }

        let rows = viewModel.spinSlots()
        for (col, row) in rows.enumerated() {
            pickerView.selectRow(row, inComponent: col, animated: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.viewModel.performDailyRewardSpin { [weak self] result in
                guard let self else { return }

                DispatchQueue.main.async {
                    self.spinButtonImageView.image = self.originalSpinButtonImage
                    self.isSpinning = false
                    self.updateUI()

                    switch result {
                    case .success(let spinResult):
                        self.handleDailySpinResult(spinResult)
                    case .failure(let error):
                        if (error as? DailySpinError) == .noSpinsRemaining {
                            self.showNoDailySpinsAlert()
                        } else {
                            self.showErrorAlert(message: "Something went wrong. Try again.")
                        }
                    }
                }
            }
        }
    }

    private func handleSpinResult(message: String, reward: Int, playWinSound: Bool) {
        let bet = viewModel.currentBetAmount

        if reward > bet {
            if playWinSound { winSound.play() }
            showResultAlert(title: "🎉 " + message,
                            message: "You won \(reward - bet) coins!\nTotal: \(reward) coins",
                            isWin: true)
        } else if reward == bet {
            showResultAlert(title: "😊 " + message,
                            message: "You got your bet back!\n\(reward) coins",
                            isWin: false)
        } else {
            loseSound.play()
            showResultAlert(title: "😔 " + message,
                            message: "You lost \(bet) coins.\nBetter luck next time!",
                            isWin: false)
        }
    }

    // MARK: - UI Updates

    private func updateUI() {
        betAmountTextField.text = "\(viewModel.currentBetAmount)"
        betAmountTextField.font = UIFont(name: "Pocket Monk", size: 16)
    }

    // MARK: - Alerts & Animations

    private func animateButtonTap(on view: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                view.transform = .identity
            }
        }
    }

    private func showResultAlert(title: String, message: String, isWin: Bool) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let buttonTitle = isWin ? "Awesome!" : "Try Again"
        alert.addAction(UIAlertAction(title: buttonTitle, style: .default))

        present(alert, animated: true) {
            if isWin {
                let shake = CAKeyframeAnimation(keyPath: "transform.translation.y")
                shake.timingFunction = CAMediaTimingFunction(name: .linear)
                shake.duration = 0.6
                shake.values = [-5, 5, -5, 5, -2.5, 2.5, 0]
                alert.view.layer.add(shake, forKey: "celebrate")
            }
        }
    }

    private func showBetError(message: String) {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.timingFunction = CAMediaTimingFunction(name: .linear)
        shake.duration = 0.6
        shake.values = [-20, 20, -20, 20, -10, 10, -5, 5, 0]

        betAmountTextField.layer.add(shake, forKey: "shake")
        spinButtonImageView.layer.add(shake, forKey: "shake")

        let alert = UIAlertController(title: "Invalid Bet", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func handleDailySpinResult(_ result: DailySpinResult) {
        winSound.play()
        notificationImpact.prepare()
        notificationImpact.notificationOccurred(.success)

        let remaining = result.remainingSpins
        let noun = remaining == 1 ? "spin" : "spins"
        let message: String
        if remaining > 0 {
            message = "You collected \(result.reward) coins.\n\(remaining) \(noun) left today."
        } else {
            message = "You collected \(result.reward) coins.\nCome back tomorrow for more spins."
        }

        let alert = UIAlertController(
            title: "Coins Collected",
            message: message,
            preferredStyle: .alert
        )

        if remaining > 0 {
            alert.addAction(UIAlertAction(title: "Spin Again", style: .default))
            alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        } else {
            alert.addAction(UIAlertAction(title: "Back Home", style: .default) { [weak self, weak alert] _ in
                self?.returnHomeAfterDailySpins(from: alert)
            })
        }

        present(alert, animated: true) {
            guard remaining == 0 else { return }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak alert] in
                self?.returnHomeAfterDailySpins(from: alert)
            }
        }
    }

    private func returnHomeAfterDailySpins(from alert: UIAlertController?) {
        guard !isReturningHomeAfterDailySpins else { return }
        isReturningHomeAfterDailySpins = true

        let dismissSlotScreen: () -> Void = { [weak self] in
            self?.dismiss(animated: true)
        }

        if alert?.presentingViewController != nil {
            alert?.dismiss(animated: true, completion: dismissSlotScreen)
        } else if presentedViewController != nil {
            presentedViewController?.dismiss(animated: true, completion: dismissSlotScreen)
        } else {
            dismissSlotScreen()
        }
    }

    private func showNoDailySpinsAlert() {
        let alert = UIAlertController(
            title: "Daily Spins",
            message: "No spins left today. Come back tomorrow.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Back Home", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - UIPickerView DataSource & Delegate

extension SlotViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 4 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { 100 }
    func pickerView(_ pickerView: UIPickerView,
                    rowHeightForComponent component: Int) -> CGFloat { 100 }

    func pickerView(_ pickerView: UIPickerView,
                    viewForRow row: Int,
                    forComponent component: Int,
                    reusing view: UIView?) -> UIView {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.font = UIFont(name: K.emojiFont, size: 35)
        let idx = viewModel.dataArray[component][row]
        label.text = K.imageArray[idx]
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView,
                       widthForComponent component: Int) -> CGFloat {
           // Calculate a “base” width for each component:
           let total = pickerView.bounds.width
           let baseWidth = total / 4.0

           // Subtract a small amount so that UIPickerView will
           // leave equal spacing between columns.
           //
           // For instance, if you subtract 10 points from each column,
           // you’ll end up with ~40 points total “empty space” distributed
           // as padding between the 4 reels.
        return baseWidth - 3.0
       }
}

// MARK: - UITextFieldDelegate

extension SlotViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        // Only digits
        let allowed = CharacterSet.decimalDigits
        return allowed.isSuperset(of: CharacterSet(charactersIn: string))
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard mode == .casinoGame else {
            updateUI()
            return
        }

        let validation = viewModel.validateBetInput(textField.text)
        updateUI()
        if let error = validation.error {
            showBetError(message: error.message)
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        doneButtonTapped()
        return true
    }
}
