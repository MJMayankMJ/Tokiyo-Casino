//
//  LottoViewController.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/26/25.
//

import UIKit

class LottoViewController: UIViewController {
    
    // MARK: – IBOutlets
    
    @IBOutlet weak var imageBackButton: UIImageView!
    @IBOutlet weak var minusImageView: UIImageView!
    @IBOutlet weak var plusImageView: UIImageView!
    @IBOutlet weak var mineCountSlider: UISlider!
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
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CollectionView setup
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = false
        
        let nib = UINib(nibName: "Cell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "Cell")
        collectionView.backgroundColor = .clear
        
        // Slider: min = 4, max = 16, initial = 4
        mineCountSlider.minimumValue = 4
        mineCountSlider.maximumValue = 16
        mineCountSlider.value = 4
        mineCountSlider.isContinuous = true
        mineCountSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        
        // Bet button initial title
        betButton.setTitle("Bet", for: .normal)
        betButton.isEnabled = true
        
        // Tap gestures
        imageBackButton.isUserInteractionEnabled = true
        let backTap = UITapGestureRecognizer(target: self, action: #selector(didTapBack))
        imageBackButton.addGestureRecognizer(backTap)
        
        minusImageView.isUserInteractionEnabled = true
        let minusTap = UITapGestureRecognizer(target: self, action: #selector(didTapMinus))
        minusImageView.addGestureRecognizer(minusTap)
        
        plusImageView.isUserInteractionEnabled = true
        let plusTap = UITapGestureRecognizer(target: self, action: #selector(didTapPlus))
        plusImageView.addGestureRecognizer(plusTap)
        
        // Keyboard accessory to dismiss
        betTextField.addCancelButtonOnKeyboard()
        
        // Ensure betTextField starts with “100” by default
        betTextField.text = "100"
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Print the final collectionView bounds after layout
        print("🔍 [viewDidLayoutSubviews] collectionView.bounds = \(collectionView.bounds)")
        
        // Calculate total required height for 6 rows + spacing
        let totalRows = CGFloat(viewModel.totalRows)    // 6
        let totalColumns = CGFloat(viewModel.totalColumns) // 4
        let totalVSpacing = cellSpacing * (totalRows - 1)  // e.g. 8 * 5 = 40
        let totalHSpacing = cellSpacing * (totalColumns - 1) // e.g. 8 * 3 = 24
        
        let adjustedH = collectionView.bounds.height - totalVSpacing
        let adjustedW = collectionView.bounds.width - totalHSpacing
        
        let cellHeight = adjustedH / totalRows
        let cellWidth = adjustedW / totalColumns
        
        print("🔍 [viewDidLayoutSubviews] totalRows = \(totalRows), totalVSpacing = \(totalVSpacing)")
        print("🔍 [viewDidLayoutSubviews] adjustedH = \(adjustedH), cellHeight = \(cellHeight)")
        print("🔍 [viewDidLayoutSubviews] totalColumns = \(totalColumns), totalHSpacing = \(totalHSpacing)")
        print("🔍 [viewDidLayoutSubviews] adjustedW = \(adjustedW), cellWidth = \(cellWidth)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    // MARK: – IBActions & Tap Handlers
    
    @objc private func didTapBack() {
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
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        let raw = Int(round(sender.value / 2)) * 2
        let clamped = max(4, min(raw, 16))
        sender.setValue(Float(clamped), animated: false)
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
        print("⇢ [didSelectItemAt] index = \(indexPath.item), isRoundActive = \(isRoundActive)")
        guard isRoundActive else {
            print("   → Ignoring tap because round is not active.")
            return
        }
        
        let idx = indexPath.item
        let (newState, ended, diamondsSoFar, currentMultiplier) = viewModel.revealCell(at: idx)
        
        if let cell = collectionView.cellForItem(at: indexPath) as? Cell {
            cell.configureCell(state: newState)
        }
        
        if ended {
            hitMineGameOver()
            return
        }
        
        if newState == .diamond {
            lastMultiplier = currentMultiplier
            if diamondsSoFar == 1 {
                let title = String(format: "Cash Out x%.2f", currentMultiplier ?? 1.0)
                betButton.setTitle(title, for: .normal)
                betButton.isEnabled = true
            } else {
                let title = String(format: "Cash Out x%.2f", currentMultiplier ?? 1.0)
                betButton.setTitle(title, for: .normal)
            }
        }
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
        
        // Print out each calculation for debugging:
        print("⇢ [sizeForItemAt \(indexPath.item)]")
        print("     collectionView.bounds.width = \(collectionView.bounds.width)")
        print("     collectionView.bounds.height = \(collectionView.bounds.height)")
        print("     totalHorizontalSpacing = \(totalHorizontalSpacing)")
        print("     totalVerticalSpacing = \(totalVerticalSpacing)")
        print("     adjustedWidth = \(adjustedWidth), adjustedHeight = \(adjustedHeight)")
        print("     cellWidth = \(cellWidth), cellHeight = \(cellHeight)")
        
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
