//
//  LottoViewController.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/26/25.
//

import UIKit

class LottoViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var betTextField: UITextField!
    @IBOutlet weak var imageBackButton: UIImageView!
    @IBOutlet weak var mineSlider: UISlider!
    @IBOutlet weak var plusButtonImageView: UIImageView!
    @IBOutlet weak var minusButtonImageView: UIImageView!
    @IBOutlet weak var betCashOutButton: UIButton!
    
    // MARK: - ViewModel
    let viewModel = LottoViewModel()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        setupUI()
        setupSlider()
        setupObservers()
        setupBackButton()
        setupGestureRecognizers()
        
        // Initially set button to "Bet"
        betCashOutButton.setTitle("Bet", for: .normal)
        
        // Set initial bet amount in text field
        betTextField.text = "\(viewModel.currentBetAmount)"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Fade-in animation
        collectionView.alpha = 0
        UIView.animate(withDuration: 0.5) {
            self.collectionView.alpha = 1
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        let nib = UINib(nibName: "Cell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "Cell")
        
        collectionView.backgroundColor = .clear
        
        // Add blur effect
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = collectionView.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundView = blurView
    }
    
    private func setupUI() {
        betTextField.addCancelButtonOnKeyboard()
        
        // Style button
        betCashOutButton.layer.cornerRadius = 8
        
        // Add text field editing target
        betTextField.addTarget(self, action: #selector(betTextFieldDidChange(_:)), for: .editingChanged)
    }
    
    private func setupSlider() {
        mineSlider.minimumValue = 4
        mineSlider.maximumValue = 16
        mineSlider.value = 4
        
        // Custom slider appearance
        mineSlider.tintColor = .systemOrange
        mineSlider.thumbTintColor = .systemOrange
        
        // Ensure slider only moves in steps of 2
        mineSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(coinsDidChange), name: CoinsManager.coinsDidChangeNotification, object: nil)
        
        // Setup viewModel callback
        viewModel.onUpdate = { [weak self] in
            DispatchQueue.main.async {
                self?.betTextField.text = "\(self?.viewModel.currentBetAmount ?? 100)"
            }
        }
    }
    
    private func setupGestureRecognizers() {
        // Plus button
        let plusTap = UITapGestureRecognizer(target: self, action: #selector(plusButtonTapped))
        plusButtonImageView.addGestureRecognizer(plusTap)
        plusButtonImageView.isUserInteractionEnabled = true

        // Minus button
        let minusTap = UITapGestureRecognizer(target: self, action: #selector(minusButtonTapped))
        minusButtonImageView.addGestureRecognizer(minusTap)
        minusButtonImageView.isUserInteractionEnabled = true
    }
    
    private func setupBackButton() {
        imageBackButton.isUserInteractionEnabled = true
        let backTap = UITapGestureRecognizer(target: self, action: #selector(didTapBack))
        imageBackButton.addGestureRecognizer(backTap)
    }
    
    // MARK: - IBActions
    
    @IBAction func betCashOutButtonTapped(_ sender: UIButton) {
        view.endEditing(true)
        
        if viewModel.gameStarted {
            // Cash out
            cashOutGame()
        } else {
            // Place bet
            let validation = viewModel.validateBetInput(betTextField.text)
            if !validation.isValid {
                if let error = validation.error {
                    showAlert(title: "Invalid Bet", message: error.message)
                }
                betTextField.text = "\(validation.clampedAmount)"
                return
            }
            
            startGame()
        }
    }
    
    @objc private func plusButtonTapped() {
        guard !viewModel.gameStarted else { return }
        
        // Animate button tap
        animateButtonTap(on: plusButtonImageView)
        
        // Add 50 to current bet amount
        let currentAmount = viewModel.currentBetAmount
        let newAmount = currentAmount + 50
        
        // Validate the new amount and update
        let validation = viewModel.validateBetInput("\(newAmount)")
//        if validation.isValid {
//            viewModel.updateCurrentBetAmount(newAmount)
//        } else {
//            // Use the clamped amount if validation failed
//            viewModel.updateCurrentBetAmount(validation.clampedAmount)
//        }
        
        // Update UI
        betTextField.text = "\(viewModel.currentBetAmount)"
    }
    
    @objc private func minusButtonTapped() {
        guard !viewModel.gameStarted else { return }
        
        // Animate button tap
        animateButtonTap(on: minusButtonImageView)
        
        // Subtract 50 from current bet amount
        let currentAmount = viewModel.currentBetAmount
        let newAmount = max(currentAmount - 50, 1) // Ensure minimum of 1
        
        if newAmount == currentAmount {
            // Already at minimum, give a shake animation
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.timingFunction = CAMediaTimingFunction(name: .linear)
            shake.duration = 0.4
            shake.values = [-5, 5, -5, 5, 0]
            minusButtonImageView.layer.add(shake, forKey: "shake")
        } else {
            // Validate the new amount and update
            let validation = viewModel.validateBetInput("\(newAmount)")
//            if validation.isValid {
//                viewModel.updateCurrentBetAmount(newAmount)
//            } else {
//                // Use the clamped amount if validation failed
//                viewModel.updateCurrentBetAmount(validation.clampedAmount)
//            }
        }
        
        // Update UI
        betTextField.text = "\(viewModel.currentBetAmount)"
    }
    
    @objc private func sliderValueChanged(_ sender: UISlider) {
        guard !viewModel.gameStarted else {
            sender.value = Float(viewModel.numberOfMines)
            return
        }
        
        // Ensure slider moves in steps of 2
        let roundedValue = round(sender.value / 2) * 2
        sender.value = Float(roundedValue)
        
        viewModel.numberOfMines = Int(roundedValue)
    }
    
    @objc private func betTextFieldDidChange(_ textField: UITextField) {
        guard !viewModel.gameStarted else { return }
        
        let validation = viewModel.validateBetInput(textField.text)
        if validation.isValid {
            // Valid input - no need to change anything
        } else {
            // Invalid input - will be handled when bet button is tapped
        }
    }
    
    // MARK: - Button Animations
    
    private func animateButtonTap(on view: UIView) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                view.transform = .identity
            }
        }
    }
    
    // MARK: - Game Logic
    
    private func startGame() {
        viewModel.startGame { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    self?.updateUIForGameStart()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func updateUIForGameStart() {
        // Update UI
        betCashOutButton.setTitle("Cash Out", for: .normal)
        mineSlider.isEnabled = false
        plusButtonImageView.isUserInteractionEnabled = false
        minusButtonImageView.isUserInteractionEnabled = false
        betTextField.isEnabled = false
        
        collectionView.reloadData()
    }
    
    private func cashOutGame() {
        viewModel.cashOut { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self?.showCashOutAlert(finalAmount: data.finalAmount, netGain: data.netGain)
                case .failure(let error):
                    self?.showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func handleCellTap(at index: Int) {
        guard !viewModel.gameOver && viewModel.gameStarted else { return }
        
        let outcome = viewModel.revealCell(at: index)
        
        UIView.transition(with: collectionView,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: {
            self.collectionView.reloadData()
        }, completion: { _ in
            if outcome == .mine {
                // Game over - hit mine
                self.showGameOverAlert(won: false)
            } else if self.viewModel.isGameWon() {
                // Game won - all diamonds found
                self.showGameOverAlert(won: true)
            }
        })
    }
    
    // MARK: - Alerts
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showGameOverAlert(won: Bool) {
        let bet = viewModel.currentBetAmount
        let finalAmount = viewModel.finalAmount()
        let netGain = viewModel.netGain()
        
        let title = won ? "🎉 JACKPOT! 🎉" : "💥 Game Over"
        let message = won ?
            "Amazing! You found all diamonds!\nBet: \(bet)\nWinnings: \(Int(finalAmount))\nNet Gain: \(Int(netGain))" :
            "You hit a mine!\nBet: \(bet)\nLost: \(bet)"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let homeAction = UIAlertAction(title: "Home", style: .default) { _ in
            if won {
                // Add winnings if game was won
                CoinsManager.shared.addCoins(amount: Int64(finalAmount)) { _ in }
            }
            self.resetGameAndGoHome()
        }
        
        let replayAction = UIAlertAction(title: "Replay", style: .default) { _ in
            if won {
                // Add winnings if game was won
                CoinsManager.shared.addCoins(amount: Int64(finalAmount)) { _ in }
            }
            self.resetGameForReplay()
        }
        
        alert.addAction(homeAction)
        alert.addAction(replayAction)
        present(alert, animated: true)
    }
    
    private func showCashOutAlert(finalAmount: Double, netGain: Double) {
        let bet = viewModel.currentBetAmount
        let message = "Successfully cashed out!\nBet: \(bet)\nWinnings: \(Int(finalAmount))\nNet Gain: \(Int(netGain))"
        
        let alert = UIAlertController(title: "💰 Cashed Out", message: message, preferredStyle: .alert)
        
        let homeAction = UIAlertAction(title: "Home", style: .default) { _ in
            self.resetGameAndGoHome()
        }
        
        let replayAction = UIAlertAction(title: "Replay", style: .default) { _ in
            self.resetGameForReplay()
        }
        
        alert.addAction(homeAction)
        alert.addAction(replayAction)
        present(alert, animated: true)
    }
    
    // MARK: - Game Reset
    
    private func resetGameAndGoHome() {
        viewModel.resetGame()
        navigationController?.popViewController(animated: true)
    }
    
    private func resetGameForReplay() {
        viewModel.resetGame()
        resetUI()
        collectionView.reloadData()
        
        // Set bet amount back to current amount
        betTextField.text = "\(viewModel.currentBetAmount)"
    }
    
    private func resetUI() {
        betCashOutButton.setTitle("Bet", for: .normal)
        mineSlider.isEnabled = true
//        plusButton.isEnabled = true
//        minusButton.isEnabled = true
        betTextField.isEnabled = true
    }
    
    // MARK: - Observers
    
    @objc private func coinsDidChange() {
        // ViewModel will handle updating bet amount if needed
    }
    
    @objc private func didTapBack() {
        UIView.animate(withDuration: 0.08, animations: {
            self.imageBackButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.08, animations: {
                self.imageBackButton.transform = .identity
            }, completion: { _ in
                if let nav = self.navigationController {
                    nav.popViewController(animated: true)
                } else {
                    self.dismiss(animated: true)
                }
            })
        })
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: - UICollectionViewDataSource
extension LottoViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.numberOfCells
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! Cell
        if let cellData = viewModel.cellData(at: indexPath.item) {
            cell.configureCell(state: cellData.state)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension LottoViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        handleCellTap(at: indexPath.item)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension LottoViewController: UICollectionViewDelegateFlowLayout {
    
    private var cellSpacing: CGFloat { return 8 }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalColumns = CGFloat(viewModel.totalColumns)  // 4 columns
        let totalRows = CGFloat(viewModel.totalRows)        // 6 rows
        
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

// MARK: - UITextField Extension (for keyboard dismissal)
extension UITextField {
    func addCancelButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(doneButtonAction))
        
        doneToolbar.items = [flexSpace, done]
        doneToolbar.sizeToFit()
        
        self.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction() {
        self.resignFirstResponder()
    }
}
