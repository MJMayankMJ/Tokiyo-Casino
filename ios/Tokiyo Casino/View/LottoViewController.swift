//
//  LottoViewController.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/26/25.
//

import UIKit
import AudioToolbox

class LottoViewController: UIViewController {
    
    // MARK: – IBOutlets
    
    @IBOutlet weak var imageBackButton: UIImageView!
    @IBOutlet weak var minusImageView: UIImageView!
    @IBOutlet weak var plusImageView: UIImageView!
    
    @IBOutlet private weak var mineCountSlider: UISlider!
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var betTextField: UITextField!
    @IBOutlet weak var betButton: UIButton!
    
    // MARK: – Internal Properties
    
    private let viewModel = LottoViewModel()
    private var isRoundActive = false
    private var currentBet: Int = 0
    private var lastMultiplier: Double? = nil
    
    // Spacing for grid cells
    private let cellSpacing: CGFloat = 8
    
    // build these subviews/layers at runtime
    private let gradientLayer = CAGradientLayer()
    private let safeLabel = UILabel()
    private let riskyLabel = UILabel()
    private let minValueLabel = UILabel()
    private let maxValueLabel = UILabel()
    private let thumbValueLabel = UILabel()
    private var betButtonTitle = "Bet"
    
    private var soundManager = SoundManager()
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = false
        
        let nib = UINib(nibName: "Cell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "Cell")
        collectionView.backgroundColor = .clear
        
        // ─── SLIDER: min = 4, max = 16, initial = 4 ───
        mineCountSlider.minimumValue = 4
        mineCountSlider.maximumValue = 16
        mineCountSlider.value = 4
        mineCountSlider.isContinuous = true
        mineCountSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        configureCustomSliderUI()
        
//        betButtonTitle = "Bet"
//        betButtonTitle.exported(as: .font) { $0.font = UIFont(name: "Pocker Monk", size: 28) }
        betButton.setTitle("Bet", for: .normal)
        betButton.isEnabled = true
        
        // ─── Tap gestures ─────────────────────────────────────
        imageBackButton.isUserInteractionEnabled = true
        let backTap = UITapGestureRecognizer(target: self, action: #selector(didTapBack))
        imageBackButton.addGestureRecognizer(backTap)
        
        minusImageView.isUserInteractionEnabled = true
        let minusTap = UITapGestureRecognizer(target: self, action: #selector(didTapMinus))
        minusImageView.addGestureRecognizer(minusTap)
        
        plusImageView.isUserInteractionEnabled = true
        let plusTap = UITapGestureRecognizer(target: self, action: #selector(didTapPlus))
        plusImageView.addGestureRecognizer(plusTap)
        
        // ─── Keyboard accessory to dismiss ─────────────────────
        betTextField.addCancelButtonOnKeyboard()
        
        // Ensure betTextField starts with “100” by default
        betTextField.text = "100"
        betTextField.font = UIFont(name: "Pocket Monk", size: 24)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Each time the layout updates, we must adjust:
        // 1) The gradient layer’s frame (so it always sits exactly behind the slider’s track)
        // 2) The positions of our “Safe”/“Risky”/min/max labels
        // 3) The position of the thumbValueLabel over the thumb
        layoutCustomSliderUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        BackgroundSoundManager.shared.setupPlayer(soundName: "bg_rock", soundType: .mp3)
        BackgroundSoundManager.shared.volume(0.15)
        BackgroundSoundManager.shared.play()
    }
    
    private func configureCustomSliderUI() {
        // 1) Make the native slider track “invisible” so our gradient shows through
        mineCountSlider.minimumTrackTintColor = .clear
        mineCountSlider.maximumTrackTintColor = .clear
        
        // 2) Add our gradient layer underneath the slider’s track
        gradientLayer.colors = [
            UIColor.systemGreen.cgColor,
            UIColor.systemYellow.cgColor,
            UIColor.systemRed.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = 4 // make track slightly rounded
        mineCountSlider.layer.insertSublayer(gradientLayer, at: 0)
        
        // 3) Set SF Symbol “bomb.fill” as the thumb image
        if let bombImage = UIImage(systemName: "bomb.fill") {
            mineCountSlider.setThumbImage(bombImage, for: .normal)
        }
        
        safeLabel.text = "💣 Easy"
        safeLabel.font = UIFont(name: "Pocket Monk", size: 14)
        safeLabel.textColor = .black
        safeLabel.sizeToFit()
        mineCountSlider.addSubview(safeLabel)
        
        riskyLabel.text = "💣💣💣 Hard"
        riskyLabel.font = UIFont(name: "Pocket Monk", size: 14)
        riskyLabel.textColor = .black
        riskyLabel.sizeToFit()
        mineCountSlider.addSubview(riskyLabel)
        
        minValueLabel.text = "4"
        minValueLabel.font = UIFont(name: "Pocket Monk", size: 14)
        minValueLabel.textColor = .black
        minValueLabel.sizeToFit()
        mineCountSlider.addSubview(minValueLabel)
        
        maxValueLabel.text = "16"
        maxValueLabel.font = UIFont(name: "Pocket Monk", size: 14)
        maxValueLabel.textColor = .black
        maxValueLabel.sizeToFit()
        mineCountSlider.addSubview(maxValueLabel)
        
        // ─── Build the “callout” label above the thumb ───────
        thumbValueLabel.textAlignment = .center
        thumbValueLabel.font = UIFont(name: "Pocket Monk", size: 14)
        thumbValueLabel.textColor = .white
        thumbValueLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        thumbValueLabel.layer.cornerRadius = 4
        thumbValueLabel.clipsToBounds = true
        
        // Give it an initial size (we’ll update text & frame later)
        thumbValueLabel.text = "\(Int(mineCountSlider.value))"
        thumbValueLabel.frame.size = CGSize(width:  30.0, height:  20.0)
        mineCountSlider.addSubview(thumbValueLabel)
    }
    
    private func layoutCustomSliderUI() {
        let trackRect = mineCountSlider.trackRect(forBounds: mineCountSlider.bounds)
        let trackFrame = CGRect(
            x: trackRect.origin.x,
            y: trackRect.origin.y + (mineCountSlider.bounds.height - trackRect.height) / 2,
            width: trackRect.width,
            height: trackRect.height
        )
        
        gradientLayer.frame = trackFrame
        
        let safeLabelX = trackFrame.minX
        let safeLabelY = trackFrame.minY - safeLabel.bounds.height - 2
        safeLabel.frame.origin = CGPoint(x: safeLabelX, y: safeLabelY)
        
        let riskyLabelX = trackFrame.maxX - riskyLabel.bounds.width
        let riskyLabelY = safeLabelY
        riskyLabel.frame.origin = CGPoint(x: riskyLabelX, y: riskyLabelY)
        
        let minLabelX = trackFrame.minX
        let minLabelY = trackFrame.maxY + 2
        minValueLabel.frame.origin = CGPoint(x: minLabelX, y: minLabelY)
        
        let maxLabelX = trackFrame.maxX - maxValueLabel.bounds.width
        let maxLabelY = minLabelY
        maxValueLabel.frame.origin = CGPoint(x: maxLabelX, y: maxLabelY)
        
        let thumbRect = mineCountSlider.thumbRect(
            forBounds: mineCountSlider.bounds,
            trackRect: trackRect,
            value: mineCountSlider.value
        )
        let thumbCenterX = thumbRect.midX
        let thumbLabelWidth: CGFloat = 30.0
        let thumbLabelHeight: CGFloat = 20.0
        thumbValueLabel.frame.size = CGSize(width: thumbLabelWidth, height: thumbLabelHeight)
        
        let thumbLabelX = thumbCenterX - (thumbLabelWidth / 2)
        let thumbLabelY = trackFrame.minY - thumbLabelHeight - 4
        thumbValueLabel.frame.origin = CGPoint(x: thumbLabelX, y: thumbLabelY)
        thumbValueLabel.text = "\(Int(mineCountSlider.value))"
        thumbValueLabel.font = UIFont(name: "Pocket Monk", size: 18)
    }
    
    // ──────────────────────────────────────────────────────
    
    // MARK: – IBActions & Tap Handlers
    
    @objc private func didTapBack() {
        BackgroundSoundManager.shared.pause()
        UIView.animate(withDuration: 0.08, animations: {
            self.imageBackButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.08, animations: {
                self.imageBackButton.transform = .identity
            }) { _ in
                if let nav = self.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            }
        }
    }
    
    @objc private func didTapMinus() {
        let currentText = Int(betTextField.text ?? "") ?? 0
        let newVal = max(100, currentText - 100)
        betTextField.text = "\(newVal)"
    }
    
    @objc private func didTapPlus() {
        let currentText = Int(betTextField.text ?? "") ?? 0
        let availableCoins = Int(CoinsManager.shared.userStats?.totalCoins ?? 0)
        let newVal = min(availableCoins, currentText + 100)
        betTextField.text = "\(newVal)"
    }
    
    // ──────────────────────────────────────────────────────
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        // Snap to an even integer
        let raw = Int(round(sender.value / 2)) * 2
        let clamped = max(4, min(raw, 16))
        sender.setValue(Float(clamped), animated: false)
        
        // Each time the slider moves, update the thumbValueLabel’s text & position
        layoutCustomSliderUI()
    }
    
    @IBAction func betButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        
        if !isRoundActive {
            guard let betText = betTextField.text,
                  let betValue = Int(betText),
                  betValue >= 100 else {
                print("❗️ [betButtonTapped] Invalid bet text: '\(betTextField.text ?? "")'")
                return
            }
            
            let available = Int(CoinsManager.shared.userStats?.totalCoins ?? 0)
            guard betValue <= available else {
                print("❗️ [betButtonTapped] Insufficient coins (have \(available), tried \(betValue))")
                let alert = UIAlertController(title: "Insufficient Coins",
                                              message: "You only have \(available) coins.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            
            print("✅ [betButtonTapped] Deducting \(betValue) coins…")
            CoinsManager.shared.deductCoins(amount: Int64(betValue)) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success():
                        print("✅ [betButtonTapped] Deducted successfully. beginRound()")
                        self.currentBet = betValue
                        self.beginRound()
                    case .failure(let error):
                        print("❗️ [betButtonTapped] DeductCoins failed: \(error.localizedDescription)")
                        let alert = UIAlertController(title: "Error",
                                                      message: error.localizedDescription,
                                                      preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
            
        } else {
            print("ℹ️ [betButtonTapped] Cash Out pressed")
            cashOutRound()
        }
    }
    
    // MARK: – Game Flow
    
    private func beginRound() {
        print("⇢ [beginRound] Round is starting…")
        isRoundActive = true
        lastMultiplier = nil
        
        mineCountSlider.isEnabled = false
        betTextField.isEnabled = false
        minusImageView.isUserInteractionEnabled = false
        plusImageView.isUserInteractionEnabled = false
        
        let chosenMines = Int(mineCountSlider.value)
        viewModel.startNewRound(mines: chosenMines)
        print("⇢ [beginRound] New board with \(chosenMines) mines generated.")
        
        collectionView.reloadData()
        print("⇢ [beginRound] collectionView.reloadData() called")
        
        betButton.setTitle("Tap a Cell", for: .normal)
        betButton.isEnabled = false
    }
    
    private func cashOutRound() {
        print("⇢ [cashOutRound] Revealing all…")
        viewModel.revealAll()
        collectionView.reloadData()
        
        let payout = viewModel.finalPayout(bet: currentBet, finalMultiplier: lastMultiplier)
        let netGain = payout - currentBet
        
        print("⇢ [cashOutRound] payout = \(payout), netGain = \(netGain)")
        if payout > currentBet {
            CoinsManager.shared.addCoins(amount: Int64(payout)) { _ in }
        }
        
        // ——— ADD SUCCESS HAPTIC FOR CASHOUT ———
        triggerCashOutHaptic()
        
        let title = "You Cashed Out!"
        let msg = """
                  Bet: \(currentBet)
                  Diamonds: \(viewModel.diamondsFound)
                  Payout: \(payout)
                  Net Gain: \(netGain)
                  """
        let alert = UIAlertController(title: title,
                                      message: msg,
                                      preferredStyle: .alert)
        
        let homeAction = UIAlertAction(title: "Home", style: .default) { _ in
            self.resetToHome()
        }
        let replayAction = UIAlertAction(title: "Replay", style: .default) { _ in
            self.replayRound()
        }
        alert.addAction(homeAction)
        alert.addAction(replayAction)
        present(alert, animated: true)
        
        isRoundActive = false
    }
    
    private func hitMineGameOver() {
        print("⇢ [hitMineGameOver] Hit a mine after \(viewModel.diamondsFound) diamonds.")
        viewModel.revealAll()
        collectionView.reloadData()
        
        let title = "Game Over"
        let msg = "You hit a mine after collecting \(viewModel.diamondsFound) diamond(s)."
        let alert = UIAlertController(title: title,
                                      message: msg,
                                      preferredStyle: .alert)
        let homeAction = UIAlertAction(title: "Home", style: .default) { _ in
            self.resetToHome()
        }
        let replayAction = UIAlertAction(title: "Replay", style: .default) { _ in
            self.replayRound()
        }
        alert.addAction(homeAction)
        alert.addAction(replayAction)
        present(alert, animated: true)
        
        isRoundActive = false
    }
    
    private func resetToHome() {
        print("⇢ [resetToHome] Resetting to initial state.")
        mineCountSlider.isEnabled = true
        betTextField.isEnabled = true
        minusImageView.isUserInteractionEnabled = true
        plusImageView.isUserInteractionEnabled = true
        
        betButton.setTitle("Bet", for: .normal)
        betButton.titleLabel?.font = UIFont(name: "Pocket Monk", size: 28)
        betButton.isEnabled = true
        collectionView.reloadData()
        
        let text = Int(betTextField.text ?? "") ?? 0
        if text < 100 {
            betTextField.text = "100"
        }
    }
    
    private func replayRound() {
        print("⇢ [replayRound] Deducting same bet again (\(currentBet)).")
        let betValue = currentBet
        CoinsManager.shared.deductCoins(amount: Int64(betValue)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self.beginRound()
                case .failure(let error):
                    print("❗️ [replayRound] DeductCoins failed: \(error.localizedDescription)")
                    let alert = UIAlertController(title: "Error",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: – Haptic Feedback Helpers
    
    private func triggerDiamondHaptic() {
        if #available(iOS 13.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } else if #available(iOS 10.0, *) {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } else {
            //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    private func triggerMineHaptic() {
        if #available(iOS 10.0, *) {
            soundManager.setupPlayer(soundName: "error_sound", soundType: .mp3)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        } else {
            //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    private func triggerCashOutHaptic() {
        if #available(iOS 10.0, *) {
            soundManager.setupPlayer(soundName: "lotto_win_sound", soundType: .mp3)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
    
    private func triggerGameOverHaptic() {
        if #available(iOS 10.0, *) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        } else {
            //AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
    }
}

// MARK: – UICollectionViewDataSource

extension LottoViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.totalCells
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell
        
        if isRoundActive {
            if viewModel.revealed[indexPath.item] {
                let state = viewModel.cellState(at: indexPath.item)
                cell.configureCell(state: state)
            } else {
                cell.configureCell(state: .normal)
            }
        } else {
            cell.configureCell(state: .normal)
        }
        
        return cell
    }
}

// MARK: – UICollectionViewDelegate

extension LottoViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard isRoundActive else { return }
        
        let idx = indexPath.item
        let (newState, ended, diamondsSoFar, currentMultiplier) = viewModel.revealCell(at: idx)
        
        // 1) Immediately update just that one cell
        if let cell = collectionView.cellForItem(at: indexPath) as? Cell {
            cell.configureCell(state: newState)
        }
        
        // 2) If it was a mine → play error haptic, then schedule reveal+alert
        if ended {
            triggerMineHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.revealAllThenGameOver()
            }
            return
        }
        
        // 3) If it was a diamond → play light impact haptic, update “Cash Out” button
        if newState == .diamond {
            triggerDiamondHaptic()
            lastMultiplier = currentMultiplier
            
            if diamondsSoFar == 1 {
                //let title = String(format: "Cash Out x%.2f", currentMultiplier ?? 1.0)
                let title = String("Cash Out")
                betButton.setTitle(title, for: .normal)
                betButton.isEnabled = true
            } else {
                //                let title = String(format: "Cash Out x%.2f", currentMultiplier ?? 1.0)
                let title = String("Cash Out")
                betButton.setTitle(title, for: .normal)
            }
        }
    }
    
    /// After hitting a mine, reveal the entire board with a cross‐fade, then show “Game Over”.
    private func revealAllThenGameOver() {
        viewModel.revealAll()
        UIView.transition(with: self.collectionView,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: {
            self.collectionView.reloadData()
        }, completion: { _ in
            // ——— ADD WARNING HAPTIC BEFORE “Game Over” ALERT ———
            self.triggerGameOverHaptic()
            self.showGameOverAlertAfterBomb()
        })
    }
    
    private func showGameOverAlertAfterBomb() {
        let title = "Game Over"
        let msg = "You hit a mine after collecting \(viewModel.diamondsFound) diamond(s)."
        
        let alert = UIAlertController(title: title,
                                      message: msg,
                                      preferredStyle: .alert)
        
        let homeAction = UIAlertAction(title: "Home", style: .default) { _ in
            self.resetToHome()
        }
        let replayAction = UIAlertAction(title: "Replay", style: .default) { _ in
            self.replayRound()
        }
        alert.addAction(homeAction)
        alert.addAction(replayAction)
        present(alert, animated: true)
        
        isRoundActive = false
    }
}

// MARK: – UICollectionViewDelegateFlowLayout

extension LottoViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalColumns = CGFloat(viewModel.totalColumns) // 4 columns
        let totalRows = CGFloat(viewModel.totalRows)       // 6 rows
        
        let totalHorizontalSpacing = cellSpacing * (totalColumns - 1)
        let totalVerticalSpacing = cellSpacing * (totalRows - 1)
        
        let adjustedWidth = collectionView.bounds.width - totalHorizontalSpacing
        let adjustedHeight = collectionView.bounds.height - totalVerticalSpacing
        
        let cellWidth = adjustedWidth / totalColumns
        let cellHeight = adjustedHeight / totalRows
        
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return cellSpacing
    }
}

// MARK: – UITextField Extension for “Cancel” button

extension UITextField {
    func addCancelButtonOnKeyboard() {
        let doneToolbar = UIToolbar(frame: CGRect(x: 0,
                                                  y: 0,
                                                  width: UIScreen.main.bounds.width,
                                                  height: 44))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace,
                                        target: nil,
                                        action: nil)
        let done = UIBarButtonItem(title: "Cancel",
                                   style: .done,
                                   target: self,
                                   action: #selector(doneButtonAction))
        
        doneToolbar.items = [flexSpace, done]
        doneToolbar.sizeToFit()
        
        inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction() {
        resignFirstResponder()
    }
}
