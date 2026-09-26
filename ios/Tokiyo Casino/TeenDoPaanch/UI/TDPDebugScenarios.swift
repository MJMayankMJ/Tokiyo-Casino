//
//  TDPDebugScenarios.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Debug builds only: jump straight to a settle-up moment instead of
//  playing a round to create a debt. Each scenario is a legal mid-session
//  state — earlier rounds recorded, this round's cards dealt, trump called —
//  so everything after it runs through the real engine and host.
//
//  You and "Player 2" share the device (pass & play); arranging only
//  happens when a person pulls from a person. Meera is a bot.
//

#if DEBUG
import Foundation

enum TDPDebugScenario: CaseIterable {
    case youOwe
    case youOweLocked
    case youOweTwo
    case youAreOwed

    var title: String {
        switch self {
        case .youOwe:       return "You owe Player 2 two tricks"
        case .youOweLocked: return "You owe Player 2 again (give-up locked)"
        case .youOweTwo:    return "You owe Player 2 and Meera"
        case .youAreOwed:   return "Player 2 owes you — you pull"
        }
    }

    func makeState(playerName: String) -> TDPGameState {
        let players = [
            TDPPlayer(id: "s0", name: playerName, seat: 0),
            TDPPlayer(id: "s1", name: "Player 2", seat: 1),
            TDPPlayer(id: "s2", name: "Meera", seat: 2, isAI: true)
        ]
        var state = TDPGameState(tableID: "debug-khichai",
                                 seed: UInt32.random(in: 1...UInt32.max),
                                 players: players)
        for index in state.players.indices { state.players[index].isReady = true }

        // Earlier rounds, dealt in rotation up to this round's dealer (you).
        let history: [TDPRoundScore]
        switch self {
        case .youOwe:
            history = [record(1, dealer: 2, delta: [0: -2, 1: 2, 2: 0])]
        case .youOweLocked:
            // Last round you gave Player 2 a trick instead of cards, fell
            // short again, and now owe them once more.
            history = [record(1, dealer: 1, delta: [0: -1, 1: 1, 2: 0]),
                       record(2, dealer: 2, delta: [0: -2, 1: 2, 2: 0],
                              adjust: [0: 1, 1: -1],
                              concessions: [TDPConcession(debtor: 0, creditor: 1, amount: 1)])]
        case .youOweTwo:
            history = [record(1, dealer: 2, delta: [0: -3, 1: 2, 2: 1])]
        case .youAreOwed:
            history = [record(1, dealer: 2, delta: [0: 2, 1: -2, 2: 0])]
        }
        state.roundHistory = history
        state.roundNumber = history.count + 1
        state.targetRounds = 6
        for round in history {
            for (seat, tricks) in round.tricks { state.scores[seat, default: 0] += tricks }
        }

        // This round: you deal (2), Player 2 called trump (5), Meera is third (3).
        state.dealerSeat = 0
        state.trump = .hearts
        state.trumpMethod = .choose
        var rng = state.rng
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        state.rng = rng
        for seat in 0..<3 {
            state.players[seat].hand = TDPDeck.sortHand(Array(deck[(seat * 8)..<(seat * 8 + 8)]))
        }
        state.deck = Array(deck[24..<30])
        state.phase = .dealTwo            // the last two cards go out, then settling starts
        state.message = "Debug: dealing the last two."
        return state
    }

    /// A finished round whose deltas create the debt we want.
    private func record(_ round: Int,
                        dealer: TDPSeat,
                        delta: [TDPSeat: Int],
                        adjust: [TDPSeat: Int] = [:],
                        concessions: [TDPConcession] = []) -> TDPRoundScore {
        var quotas: [String: Int] = [:]
        var tricks: [String: Int] = [:]
        var deltas: [String: Int] = [:]
        for seat in 0..<3 {
            let quota = TDPRoles.quota(seat: seat, dealerSeat: dealer) + (adjust[seat] ?? 0)
            quotas[String(seat)] = quota
            deltas[String(seat)] = delta[seat] ?? 0
            tricks[String(seat)] = quota + (delta[seat] ?? 0)
        }
        var score = TDPRoundScore(round: round, dealerSeat: dealer, trump: .spades, trumpMethod: .choose,
                                  tricks: tricks, quotas: quotas, delta: deltas)
        score.concessions = concessions
        return score
    }
}
#endif
