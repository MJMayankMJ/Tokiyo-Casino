//
//  GameTypes.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Game Phase
enum GamePhase {
    case waiting
    case preFlop
    case flop
    case turn
    case river
    case showdown
    
    var description: String {
        switch self {
        case .waiting: return "Waiting"
        case .preFlop: return "Pre-Flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .showdown: return "Showdown"
        }
    }
}

// MARK: - Pot Structure
struct Pot {
    var amount: Int = 0
    
    mutating func add(_ chips: Int) {
        amount += chips
    }
    
    mutating func reset() {
        amount = 0
    }
}

// MARK: - Game Manager Protocol
protocol GameManagerDelegate: AnyObject {
    func gameDidStart()
    func gamePhaseDidChange(_ phase: GamePhase)
    func playerDidAct(_ player: Player, action: PlayerAction)
    func playerDidWin(_ player: Player, amount: Int, handDescription: String)
    func gameDidEnd()
    func cardsDealt()
    func potDidUpdate(_ amount: Int)
    func currentPlayerChanged(_ player: Player)
}
