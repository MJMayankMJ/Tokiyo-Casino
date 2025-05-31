//
//  LottoViewModel.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/31/25.
//

import Foundation
import CoreData

enum LottoBetError: Error {
    case empty
    case belowMinimum
    case insufficientFunds

    var message: String {
        switch self {
        case .empty:
            return "Please enter a bet amount!"
        case .belowMinimum:
            return "Minimum bet is 100 coins!"
        case .insufficientFunds:
            return "You don't have enough coins!"
        }
    }
}

/// Result of validating a bet
struct LottoBetValidationResult {
    let isValid: Bool
    let clampedAmount: Int
    let error: LottoBetError?
}

struct LottoCellData {
    var state: CellState
}

class LottoViewModel {
    
    // MARK: - Properties
    var onUpdate: (() -> Void)?
    
    let totalRows = 6
    let totalColumns = 4
    
    // Flat array used by the collection view (24 cells)
    var cells: [LottoCellData] = []
    
    // 2D array for full board outcomes
    var board: [[CellState]] = []
    
    // Game state
    private(set) var currentBetAmount: Int = 100
    var numberOfMines: Int = 4
    var currentMultiplier: Double = 1.0
    var gameOver: Bool = false
    var gameStarted: Bool = false
    var revealedDiamonds: Int = 0
    var totalSafeCells: Int { return (totalRows * totalColumns) - numberOfMines }
    
    var totalCoins: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }
    
    // Multiplier calculation based on mines and revealed diamonds
    private let baseMultipliers: [Int: [Double]] = [
        4: [1.15, 1.35, 1.6, 1.9, 2.25, 2.7, 3.2, 3.8, 4.5, 5.4, 6.5, 7.8, 9.4, 11.3, 13.6, 16.3, 19.6, 23.5, 28.2, 33.9],
        6: [1.25, 1.6, 2.0, 2.5, 3.2, 4.0, 5.0, 6.3, 7.9, 9.9, 12.4, 15.5, 19.4, 24.3, 30.4, 38.0, 47.5, 59.4],
        8: [1.4, 1.9, 2.6, 3.5, 4.8, 6.5, 8.8, 11.9, 16.1, 21.8, 29.5, 39.9, 54.0, 73.1, 98.9, 133.9],
        10: [1.6, 2.4, 3.6, 5.4, 8.1, 12.2, 18.3, 27.4, 41.1, 61.7, 92.5, 138.8, 208.2, 312.3],
        12: [1.8, 3.0, 5.0, 8.3, 13.9, 23.1, 38.5, 64.2, 107.0, 178.3, 297.2, 495.3],
        14: [2.1, 3.9, 7.3, 13.6, 25.4, 47.4, 88.5, 165.2, 308.4, 575.8],
        16: [2.5, 5.2, 10.8, 22.5, 46.9, 97.7, 203.5, 424.1]
    ]
    
    // MARK: - Init
    init() {
        // Initialize the flat cells array with .normal state
        let totalCount = totalRows * totalColumns
        cells = Array(repeating: LottoCellData(state: .normal), count: totalCount)
        observeCoinsChange()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Observe Coin Updates
    private func observeCoinsChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coinsDidChange),
            name: CoinsManager.coinsDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func coinsDidChange() {
        // If bet is now more than available coins, clamp it
        if Int64(currentBetAmount) > totalCoins {
            currentBetAmount = max(100, Int(totalCoins))
            onUpdate?()
        }
    }
    
    var numberOfCells: Int {
        return cells.count
    }
    
    func cellData(at index: Int) -> LottoCellData? {
        guard index >= 0 && index < cells.count else { return nil }
        return cells[index]
    }
    
    // MARK: - Bet Management
    func increaseBet() {
        let next = currentBetAmount + 100
        if Int64(next) <= totalCoins {
            currentBetAmount = next
        } else {
            currentBetAmount = Int(totalCoins)
        }
        onUpdate?()
    }
    
    func decreaseBet() {
        currentBetAmount = max(100, currentBetAmount - 100)
        onUpdate?()
    }
    
    func validateBetInput(_ text: String?) -> LottoBetValidationResult {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !t.isEmpty else {
            return LottoBetValidationResult(isValid: false,
                                           clampedAmount: currentBetAmount,
                                           error: .empty)
        }
        
        guard let value = Int(t) else {
            currentBetAmount = 100
            return LottoBetValidationResult(isValid: false,
                                           clampedAmount: 100,
                                           error: .belowMinimum)
        }
        
        if value < 100 {
            currentBetAmount = 100
            return LottoBetValidationResult(isValid: false,
                                           clampedAmount: 100,
                                           error: .belowMinimum)
        }
        
        if Int64(value) > totalCoins {
            let clamped = Int(totalCoins)
            currentBetAmount = clamped
            return LottoBetValidationResult(isValid: false,
                                           clampedAmount: clamped,
                                           error: .insufficientFunds)
        }
        
        currentBetAmount = value
        return LottoBetValidationResult(isValid: true,
                                       clampedAmount: value,
                                       error: nil)
    }
    
    // MARK: - Game Setup
    func generateBoard() {
        board = []
        
        // Create flat array for easier mine placement
        var flatBoard = Array(repeating: CellState.diamond, count: totalRows * totalColumns)
        
        // Place mines randomly
        var minePositions = Set<Int>()
        while minePositions.count < numberOfMines {
            let randomPosition = Int.random(in: 0..<(totalRows * totalColumns))
            minePositions.insert(randomPosition)
        }
        
        // Set mines in flat board
        for position in minePositions {
            flatBoard[position] = .mine
        }
        
        // Convert flat board to 2D array
        for row in 0..<totalRows {
            var boardRow: [CellState] = []
            for col in 0..<totalColumns {
                let index = row * totalColumns + col
                boardRow.append(flatBoard[index])
            }
            board.append(boardRow)
        }
        
        print("DEBUG: Generated board with \(numberOfMines) mines")
    }
    
    func startGame(completion: @escaping (Result<Void, Error>) -> Void) {
        // Deduct bet first
        CoinsManager.shared.deductCoins(amount: Int64(currentBetAmount)) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success():
                self.generateBoard()
                self.currentMultiplier = 1.0
                self.gameOver = false
                self.gameStarted = true
                self.revealedDiamonds = 0
                
                // Reset flat cells array to all normal
                let totalCount = self.totalRows * self.totalColumns
                self.cells = Array(repeating: LottoCellData(state: .normal), count: totalCount)
                completion(.success(()))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Game Actions
    func revealCell(at index: Int) -> CellState {
        guard index >= 0 && index < cells.count && !gameOver else { return .normal }
        
        let row = index / totalColumns
        let col = index % totalColumns
        let cellOutcome = board[row][col]
        
        cells[index].state = cellOutcome
        
        if cellOutcome == .diamond {
            revealedDiamonds += 1
            updateMultiplier()
        } else if cellOutcome == .mine {
            gameOver = true
            revealAllMines()
        }
        
        return cellOutcome
    }
    
    private func updateMultiplier() {
        if let multipliers = baseMultipliers[numberOfMines], revealedDiamonds > 0 && revealedDiamonds <= multipliers.count {
            currentMultiplier = multipliers[revealedDiamonds - 1]
        }
    }
    
    func revealAllMines() {
        for row in 0..<totalRows {
            for col in 0..<totalColumns {
                let index = row * totalColumns + col
                if board[row][col] == .mine {
                    cells[index].state = .mine
                }
            }
        }
    }
    
    func isGameWon() -> Bool {
        return revealedDiamonds == totalSafeCells && !gameOver
    }
    
    func cashOut(completion: @escaping (Result<(finalAmount: Double, netGain: Double), Error>) -> Void) {
        let finalAmount = Double(currentBetAmount) * currentMultiplier
        let netGain = finalAmount - Double(currentBetAmount)
        
        gameOver = true
        
        // Add winnings
        CoinsManager.shared.addCoins(amount: Int64(finalAmount)) { result in
            switch result {
            case .success():
                completion(.success((finalAmount: finalAmount, netGain: netGain)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Calculations
    func finalAmount() -> Double {
        return Double(currentBetAmount) * currentMultiplier
    }
    
    func netGain() -> Double {
        return finalAmount() - Double(currentBetAmount)
    }
    
    func nextMultiplier() -> Double? {
        if let multipliers = baseMultipliers[numberOfMines], revealedDiamonds < multipliers.count {
            return multipliers[revealedDiamonds]
        }
        return nil
    }
    
    // MARK: - Reset Game
    func resetGame() {
        currentMultiplier = 1.0
        gameOver = false
        gameStarted = false
        revealedDiamonds = 0
        let totalCount = totalRows * totalColumns
        cells = Array(repeating: LottoCellData(state: .normal), count: totalCount)
        board = []
    }
}
