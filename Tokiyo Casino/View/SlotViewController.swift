//
//  HomeViewController.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 5/25/25.
//

import UIKit

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

        checkDailyBonus()
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
        // Use "Slots.m4a" for win, "rattle.m4a" for lose & tap
        if Bundle.main.url(forResource: "Slots", withExtension: "m4a") != nil {
            winSound.setupPlayer(soundName: "Slots", soundType: .m4a)
            winSound.volume(0.7)
        }
        if Bundle.main.url(forResource: "rattle", withExtension: "m4a") != nil {
            loseSound.setupPlayer(soundName: "rattle", soundType: .m4a)
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

    // MARK: - Actions

    @objc private func spinButtonTapped() {
        guard !isSpinning else { return }

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
        buttonTapSound.play()
        animateButtonTap(on: plusButtonImageView)
        viewModel.increaseBet()
        updateUI()
    }

    @objc private func minusButtonTapped() {
        buttonTapSound.play()
        animateButtonTap(on: minusButtonImageView)

        let oldAmount = viewModel.currentBetAmount
        viewModel.decreaseBet()
        if viewModel.currentBetAmount == oldAmount {
            // Already at minimum, give a shake
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .linear)
            shake.duration = 0.4
            shake.values = [-5, 5, -5, 5, 0]
            minusButtonImageView.layer.add(shake, forKey: "shake")
        }
        updateUI()
    }

    @objc private func backButtonTapped() {
        buttonTapSound.play()
        animateButtonTap(on: backButton)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.dismiss(animated: true)
        }
    }

    @objc private func doneButtonTapped() {
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

    private func checkDailyBonus() {
        viewModel.checkDailyReward()

        if let stats = CoinsManager.shared.userStats, !stats.collectedCoinsToday {
            let alert = UIAlertController(title: "Daily Bonus Available!",
                                          message: "Collect 1000 coins now!",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Collect", style: .default) { _ in
                self.viewModel.collectDailyBonus { success in
                    DispatchQueue.main.async {
                        if success {
                            self.updateUI()
                            let bonusAlert = UIAlertController(title: "🎁 Bonus Collected!",
                                                               message: "You got 1000 coins!",
                                                               preferredStyle: .alert)
                            bonusAlert.addAction(UIAlertAction(title: "Sweet!", style: .default))
                            self.present(bonusAlert, animated: true)
                        } else {
                            self.showErrorAlert(message: "Couldn't collect bonus. Try again.")
                        }
                    }
                }
            })
            alert.addAction(UIAlertAction(title: "Later", style: .cancel))
            present(alert, animated: true)
        }
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

