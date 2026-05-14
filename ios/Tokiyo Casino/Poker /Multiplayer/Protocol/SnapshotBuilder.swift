//
//  SnapshotBuilder.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Translates the host's `GameManager` state into a public, privacy-safe
//  `TableSnapshotPayload`. The snapshot intentionally omits opponent hole
//  cards unless `revealed` is supplied (used at showdown).
//

import Foundation

enum SnapshotBuilder {

    /// Build a snapshot for broadcast. Pass `revealedSeats` at showdown
    /// (set of seat ids whose hole cards should be embedded in the public
    /// snapshot); at every other phase pass an empty set.
    static func build(
        gameManager gm: GameManager,
        handNumber: UInt32,
        playerKindBySeat: [Int: String],
        disconnectedSeats: Set<Int>,
        aiTakenOverSeats: Set<Int>,
        revealedSeats: Set<Int> = [],
        isPaused: Bool = false,
        pausedForSeatId: Int? = nil
    ) -> TableSnapshotPayload {

        let currentSeatId: Int? = gm.currentPlayer.flatMap { current in
            gm.players.firstIndex(where: { $0.id == current.id })
        }

        let publicPlayers: [PublicPlayerStatePayload] = gm.players.map { player in
            let seatIndex = gm.players.firstIndex(where: { $0.id == player.id }) ?? player.id
            let isDealer = seatIndex == gm.dealerIndex
            let reveal = revealedSeats.contains(seatIndex) && !player.holeCards.isEmpty
            return PublicPlayerStatePayload(
                seatId: seatIndex,
                displayName: player.name,
                kind: playerKindBySeat[seatIndex] ?? (player.isHuman ? "human" : "ai"),
                chips: player.chips,
                currentBet: player.currentBet,
                totalInvested: player.totalInvested,
                isFolded: player.isFolded,
                isAllIn: player.isAllIn,
                isActive: player.isActive,
                isDealer: isDealer,
                lastAction: encodeLastAction(player.lastAction).name,
                lastActionAmount: encodeLastAction(player.lastAction).amount,
                hasCards: !player.holeCards.isEmpty,
                isDisconnected: disconnectedSeats.contains(seatIndex),
                isAITakenOver: aiTakenOverSeats.contains(seatIndex),
                revealedHoleCards: reveal ? player.holeCards.map { $0.dto } : nil
            )
        }

        return TableSnapshotPayload(
            phase: encodePhase(gm.currentPhase),
            handNumber: handNumber,
            dealerSeat: gm.dealerIndex,
            currentPlayerSeat: currentSeatId,
            smallBlind: gm.smallBlind,
            bigBlind: gm.bigBlind,
            currentBet: gm.currentBet,
            minRaise: gm.minRaise,
            pot: gm.mainPot.amount,
            communityCards: gm.communityCards.map { $0.dto },
            players: publicPlayers,
            isPaused: isPaused,
            pausedForSeatId: pausedForSeatId
        )
    }

    static func encodePhase(_ phase: GamePhase) -> String {
        switch phase {
        case .waiting: return "waiting"
        case .preFlop: return "preFlop"
        case .flop: return "flop"
        case .turn: return "turn"
        case .river: return "river"
        case .showdown: return "showdown"
        }
    }

    static func decodePhase(_ raw: String) -> GamePhase {
        switch raw {
        case "preFlop": return .preFlop
        case "flop": return .flop
        case "turn": return .turn
        case "river": return .river
        case "showdown": return .showdown
        default: return .waiting
        }
    }

    static func encodeLastAction(_ action: PlayerAction?) -> (name: String?, amount: Int?) {
        guard let action else { return (nil, nil) }
        switch action {
        case .fold: return ("fold", nil)
        case .check: return ("check", nil)
        case .call: return ("call", nil)
        case .raise(let amount): return ("raise", amount)
        case .allIn: return ("allIn", nil)
        }
    }

    static func encodeActionName(_ action: PlayerAction) -> String {
        return encodeLastAction(action).name ?? "fold"
    }

    static func decodeAction(name: String, raiseAmount: Int?) -> PlayerAction? {
        switch name {
        case "fold": return .fold
        case "check": return .check
        case "call": return .call
        case "raise":
            guard let amount = raiseAmount, amount >= 0 else { return nil }
            return .raise(amount)
        case "allIn": return .allIn
        default: return nil
        }
    }
}
