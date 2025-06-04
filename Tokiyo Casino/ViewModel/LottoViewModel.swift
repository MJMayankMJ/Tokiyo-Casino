//
//  LottoViewModel.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/31/25.
//

import Foundation

class LottoViewModel {
        
    // MARK: – Board Configuration
    let totalRows = 6
    let totalColumns = 4
    let totalCells: Int
    
    /// How many mines the player chose (4…16)
    private(set) var mineCount: Int = 4
    
    /// Flat array of length 24. Before reveal: all .normal.
    /// After generating board: each index is either .mine or .diamond (hidden until tapped).
    private(set) var board: [CellState]
    
    /// Tracks whether a given index has already been revealed.
    var revealed: [Bool]
    
    /// Count of diamonds found so far in the current round.
    private(set) var diamondsFound: Int = 0
    
    /// Has the player hit a mine or cashed out? If true, no further taps should do anything.
    private(set) var gameOver: Bool = false
    
    
    // MARK: – Multipliers Lookup
    ///
    /// For a given mineCount (4, 6, 8, …, 16), this array
    /// shows the multiplier for each diamond the player uncovers.
    /// E.g. `baseMultipliers[4] = [1.15, 1.35, 1.6, …]`.
    private let baseMultipliers: [Int: [Double]] = [
        4:  [1.15, 1.35, 1.60, 1.90, 2.25, 2.70, 3.20, 3.80,
             4.50, 5.40, 6.50, 7.80, 9.40, 11.30, 13.60, 16.30,
             19.60, 23.50, 28.2, 33.9],
        6:  [1.25, 1.60, 2.00, 2.50, 3.20, 4.00, 5.00, 6.30,
             7.90, 9.90, 12.4, 15.5, 19.4, 24.3, 30.4, 38.0,
             47.5, 59.4],
        8:  [1.40, 1.90, 2.60, 3.50, 4.80, 6.50, 8.80, 11.9,
             16.1, 21.8, 29.5, 39.9, 54.0, 73.1, 98.9, 133.9],
        10: [1.60, 2.40, 3.60, 5.40, 8.10, 12.2, 18.3, 27.4,
             41.1, 61.7, 92.5, 138.8, 208.2, 312.3],
        12: [1.80, 3.00, 5.00, 8.30, 13.9, 23.1, 38.5, 64.2,
             107.0, 178.3, 297.2, 495.3],
        14: [2.10, 3.90, 7.30, 13.6, 25.4, 47.4, 88.5, 165.2,
             308.4, 575.8],
        16: [2.50, 5.20, 10.8, 22.5, 46.9, 97.7, 203.5, 424.1]
    ]
    
    
    // MARK: – Initialization
    init() {
        totalCells = totalRows * totalColumns
        board = Array(repeating: .normal, count: totalCells)
        revealed = Array(repeating: false, count: totalCells)
    }
    
    /// Call this once the user taps “Bet” and the coins have been deducted.
    func startNewRound(mines: Int) {
        mineCount = max(4, min(mines, 16))   // clamp 4…16
        generateBoard()
        diamondsFound = 0
        gameOver = false
        revealed = Array(repeating: false, count: totalCells)
    }
    
    /// Randomly place `mineCount` mines among 24 cells.
    /// The remaining cells become diamonds.
    private func generateBoard() {
        // 1. Start with an array of 24 “.diamond”
        var temp = Array(repeating: CellState.diamond, count: totalCells)
        
        // 2. Randomly pick `mineCount` distinct indices to become .mine
        var indices = Array(0..<totalCells)
        indices.shuffle()
        let mineIndices = Array(indices.prefix(mineCount))
        
        for idx in mineIndices {
            temp[idx] = .mine
        }
        
        board = temp
    }
    
    /// Returns the state at a given index (only valid after `startNewRound`).
    func cellState(at index: Int) -> CellState {
        guard index >= 0 && index < totalCells else { return .normal }
        return board[index]
    }
    
    /// Reveal the tapped cell at `index`. Returns a tuple:
    ///   ( newState, gameEnded: Bool, diamondsSoFar: Int, currentMultiplier: Double? )
    ///
    /// - If the tapped cell is a diamond:
    ///     • increments `diamondsFound`
    ///     • looks up `currentMultiplier = baseMultipliers[mineCount]?[diamondsFound–1]`
    ///     • returns `( .diamond, false, diamondsFound, currentMultiplier )`
    ///
    /// - If it’s a mine:
    ///     • sets `gameOver = true`
    ///     • returns `( .mine, true, diamondsFound, nil )`
    ///
    func revealCell(at index: Int) -> (newState: CellState, gameEnded: Bool, diamondsSoFar: Int, currentMultiplier: Double?) {
        guard !gameOver, index >= 0, index < totalCells, !revealed[index] else {
            return (.normal, gameOver, diamondsFound, nil)
        }
        
        revealed[index] = true
        let state = board[index]
        
        switch state {
        case .diamond:
            diamondsFound += 1
            
            // Look up the multiplier for this diamond‐count
            let multipliers = baseMultipliers[mineCount] ?? []
            let idx = diamondsFound - 1   // zero‐based index
            let multiplier = (idx < multipliers.count) ? multipliers[idx] : multipliers.last
            
            return (.diamond, false, diamondsFound, multiplier)
            
        case .mine:
            gameOver = true
            return (.mine, true, diamondsFound, nil)
            
        case .normal:
            // We never store “.normal” in `board` after `generateBoard`.
            return (.normal, gameOver, diamondsFound, nil)
        }
    }
    
    /// Reveal all cells’ true states. Caller should iterate 0..<totalCells and call:
    ///    let finalState = viewModel.cellState(at: idx)
    /// to display diamonds/mines.
    func revealAll() {
        gameOver = true
    }
    
    /// Compute the final payout if the player cashes out immediately after their last tap.
    /// - Parameter bet: the original bet amount.
    /// - Parameter finalMultiplier: the last multiplier obtained (from `revealCell`).
    ///
    /// If `finalMultiplier == nil` (meaning the user tapped a mine), returns 0.
    /// Otherwise, payout = bet × finalMultiplier.
    func finalPayout(bet: Int, finalMultiplier: Double?) -> Int {
        guard let mult = finalMultiplier else {
            return 0
        }
        return Int(round(Double(bet) * mult))
    }
}
