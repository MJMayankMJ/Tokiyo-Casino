//
//  SlotViewController.swift
//  Tokiyo Casino
//
//  Daily Spin reward screen. Casino-betting mode has been retired
//  for the public release — this controller awards free virtual coins
//  only and never deducts from the user's balance.
//

import UIKit
import CoreHaptics

class SlotViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var pickerView: UIPickerView!
    @IBOutlet weak var spinButtonImageView: UIImageView!
    @IBOutlet weak var backButton: UIImageView!
    // The following outlets remain wired in the storyboard so the
    // scene loads, but they are kept hidden in daily-reward mode.
    @IBOutlet weak var betAmountTextField: UITextField!
    @IBOutlet weak var plusButtonImageView: UIImageView!
    @IBOutlet weak var minusButtonImageView: UIImageView!

    // MARK: - Properties
    private var viewModel: SlotViewModel!

    private var winSound = SoundManager()
    private var buttonTapSound = SoundManager()

    private var isSpinning = false
    private var originalSpinButtonImage: UIImage?
    private var pressedSpinButtonImage: UIImage?
    private var isReturningHomeAfterDailySpins = false
    var impactGenerator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
    var notificationImpact: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = SlotViewModel()
        viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async { self?.updateUI() }
        }

        setupUI()
        setupSounds()
        setupGestureRecognizers()
        hideBettingControls()
        updateUI()

        let rows = viewModel.spinSlots()
        for (col, row) in rows.enumerated() {
            pickerView.selectRow(row, inComponent: col, animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.onUpdate?()
        BackgroundSoundManager.shared.setupPlayer(soundName: "bg_soothing", soundType: .mp3)
        BackgroundSoundManager.shared.play()
        BackgroundSoundManager.shared.volume(0.3)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: 0.6,
                       delay: 0.2,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5,
                       options: []) {
            self.spinButtonImageView.alpha = 1
            self.spinButtonImageView.transform = .identity
        }
    }

    // MARK: - Setup

    private func setupUI() {
        pickerView.dataSource = self
        pickerView.delegate = self

        originalSpinButtonImage = UIImage(named: "spinButton")
        pressedSpinButtonImage = UIImage(named: "spinButtonPressed")
        spinButtonImageView.image = originalSpinButtonImage

        spinButtonImageView.alpha = 0
        spinButtonImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    }

    private func setupSounds() {
        if Bundle.main.url(forResource: "grand_win", withExtension: "mp3") != nil {
            winSound.setupPlayer(soundName: "grand_win", soundType: .mp3)
            winSound.volume(0.7)
        }
        if Bundle.main.url(forResource: "Rattle", withExtension: "m4a") != nil {
            buttonTapSound.setupPlayer(soundName: "Rattle", soundType: .m4a)
            buttonTapSound.volume(0.3)
        }
    }

    private func setupGestureRecognizers() {
        let spinTap = UITapGestureRecognizer(target: self, action: #selector(spinButtonTapped))
        spinButtonImageView.addGestureRecognizer(spinTap)
        spinButtonImageView.isUserInteractionEnabled = true

        let backTap = UITapGestureRecognizer(target: self, action: #selector(backButtonTapped))
        backButton.addGestureRecognizer(backTap)
        backButton.isUserInteractionEnabled = true
    }

    private func hideBettingControls() {
        betAmountTextField.isHidden = true
        betAmountTextField.isUserInteractionEnabled = false
        plusButtonImageView.isHidden = true
        plusButtonImageView.isUserInteractionEnabled = false
        minusButtonImageView.isHidden = true
        minusButtonImageView.isUserInteractionEnabled = false
    }

    // MARK: - Actions

    @objc private func spinButtonTapped() {
        guard !isSpinning else { return }

        buttonTapSound.setupPlayer(soundName: "button_press_sound", soundType: .mp3)
        buttonTapSound.play()

        impactGenerator.prepare()
        impactGenerator.impactOccurred()

        guard viewModel.canSpinForCoins else {
            showNoDailySpinsAlert()
            return
        }

        performDailyRewardSpin()
    }

    @objc private func backButtonTapped() {
        buttonTapSound.play()
        animateButtonTap(on: backButton)
        BackgroundSoundManager.shared.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.dismiss(animated: true)
        }
    }

    // MARK: - Game Logic

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

    // MARK: - UI Updates

    private func updateUI() {
        // No bet UI to refresh in daily-spin mode; method retained for
        // onUpdate hook compatibility.
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
        let footer = "\n\nVirtual coins only. No cash value."
        let message: String
        if remaining > 0 {
            message = "You collected \(result.reward) coins.\n\(remaining) \(noun) left today." + footer
        } else {
            message = "You collected \(result.reward) coins.\nCome back tomorrow for more spins." + footer
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
        let total = pickerView.bounds.width
        let baseWidth = total / 4.0
        return baseWidth - 3.0
    }
}
