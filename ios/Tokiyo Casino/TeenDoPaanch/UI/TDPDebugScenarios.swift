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
// MARK: - Big moments

/// Debug builds: sit down at the exact trick where a first cut or a steal
/// is one tap away. You play with two bots, who have already played to the
/// trick; you play last. Everything after runs through the real engine.
enum TDPMomentScenario: CaseIterable {
    /// Spades led for the first time this round; you have none. Play a heart.
    case firstCut
    /// Clubs led low; you hold A♣ and Q♣, Meera holds K♣. Play the Q♣.
    case steal

    var title: String {
        switch self {
        case .firstCut: return "First cut — trump the first spade"
        case .steal:    return "Steal — win with Q♣ (K♣ is out)"
        }
    }

    func makeState(playerName: String) -> TDPGameState {
        let players = [
            TDPPlayer(id: "s0", name: playerName, seat: 0),
            TDPPlayer(id: "s1", name: "Ravi", seat: 1, isAI: true),
            TDPPlayer(id: "s2", name: "Meera", seat: 2, isAI: true)
        ]
        var state = TDPGameState(tableID: "debug-moment",
                                 seed: UInt32.random(in: 1...UInt32.max),
                                 players: players)
        for index in state.players.indices { state.players[index].isReady = true }

        // Round 1: Meera deals, you called trump (hearts) and led the first
        // three tricks; Ravi won the third and has led the fourth.
        let (earlier, onTable, hands) = deal()
        state.roundNumber = 1
        state.targetRounds = 3
        state.dealerSeat = 2
        state.trump = .hearts
        state.trumpMethod = .choose
        state.deck = []
        for seat in 0..<3 { state.players[seat].hand = TDPDeck.sortHand(hands[seat]) }
        state.roundTricks = earlier
        for trick in earlier {
            if let lead = trick.first?.card.suit,
               let winner = TDPLegalMoves.trickWinner(plays: trick, trump: .hearts, leadSuit: lead),
               let index = state.players.firstIndex(where: { $0.seat == winner }) {
                state.players[index].tricksWon += 1
                state.lastTrickWinnerSeat = winner
            }
        }
        state.lastTrick = earlier.last ?? []
        state.trickNumber = earlier.count
        state.currentTrick = onTable
        state.leadSuit = onTable.first?.card.suit
        state.leaderSeat = 1
        state.currentTurnSeat = 0
        state.phase = .play
        state.message = "Debug: your play."
        return state
    }

    private func cards(_ ids: String) -> [Card] {
        ids.split(separator: " ").compactMap { Card(tdpID: String($0)) }
    }

    private func plays(_ ids: String, from seats: [TDPSeat]) -> [TDPTrickPlay] {
        zip(seats, cards(ids)).map { TDPTrickPlay(seat: $0, card: $1) }
    }

    /// Earlier tricks, the two cards already on the table, and what's left
    /// in each hand — all 30 cards accounted for.
    private func deal() -> ([[TDPTrickPlay]], [TDPTrickPlay], [[Card]]) {
        let youLead: [TDPSeat] = [0, 1, 2]
        switch self {
        case .firstCut:
            let earlier = [plays("AD 8D 9D", from: youLead),       // you win
                           plays("AC 8C 9C", from: youLead),       // you win
                           plays("10C QC JC", from: youLead)]      // Ravi wins, leads next
            let onTable = plays("KS 8S", from: [1, 2])             // spades, for the first time
            return (earlier, onTable, [cards("9H JH KH KD QD KC 10D"),           // you: no spades
                                       cards("AS QS JS 7H 10H JD"),              // Ravi
                                       cards("7S 9S 10S 8H QH AH")])             // Meera
        case .steal:
            let earlier = [plays("AD 8D 9D", from: youLead),
                           plays("KD 10D JD", from: youLead),
                           plays("7H QH 8H", from: youLead)]       // Ravi wins, leads next
            let onTable = plays("9C 10C", from: [1, 2])            // Meera keeps her K♣ back
            return (earlier, onTable, [cards("AC QC QD AH KH 9S 10S"),           // you: A♣ Q♣, no K♣
                                       cards("8C JC 7S 8S JS 9H"),               // Ravi
                                       cards("KC QS KS AS 10H JH")])             // Meera
        }
    }
}
#endif
