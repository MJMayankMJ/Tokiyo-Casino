//
//  TDPViewBuilder.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Turns the host's full `TDPGameState` into a per-seat redacted
//  `TDPClientView`.
//
//  This is the single choke point for hidden information. Nothing else may
//  build a client payload, and this file must never copy another seat's
//  `hand`, `privateTrumpCard`, or an un-owned `khichaiCurrent.drawnCard`.
//

import Foundation

enum TDPViewBuilder {

    static func view(from state: TDPGameState,
                     for seat: TDPSeat,
                     isHost: Bool,
                     connectedSeats: Set<TDPSeat>? = nil) -> TDPClientView {

        let me = state.player(at: seat)
        let hand = me?.hand ?? []

        let seats: [TDPSeatView] = state.players
            .sorted { $0.seat < $1.seat }
            .map { player in
                let kind: String
                if player.seat == seat { kind = "you" }
                else if player.isAI { kind = "ai" }
                else { kind = "remote" }
                return TDPSeatView(
                    seat: player.seat,
                    name: player.name,
                    kind: kind,
                    handCount: player.hand.count,        // count only — never cards
                    tricksWon: player.tricksWon,
                    quota: state.quota(at: player.seat),
                    score: state.score(at: player.seat),
                    role: state.role(at: player.seat)?.rawValue,
                    isDealer: state.dealerSeat == player.seat,
                    isConnected: connectedSeats.map { $0.contains(player.seat) } ?? true,
                    drawnCard: player.drawnCard          // public by nature
                )
            }

        let legal = TDPLegalMoves.legalCards(state, seat: seat)

        return TDPClientView(
            tableId: state.tableID,
            phase: state.phase,
            roundNumber: state.roundNumber,
            trickNumber: state.trickNumber,
            targetRounds: state.targetRounds,
            mySeat: seat,
            myHand: hand,
            myLegalCardIDs: legal.map(\.tdpID),
            prompt: prompt(state: state, seat: seat),
            isMyTurn: state.currentTurnSeat == seat,
            // Only the selector learns which card set trump under
            // highest-of-three; the suit alone is public.
            myPrivateTrumpCard: state.trumpSelectorSeat == seat ? state.privateTrumpCard : nil,
            seats: seats,
            dealerSeat: state.dealerSeat,
            trump: state.trump,
            trumpMethod: state.trumpMethod,
            revealedTrumpCard: state.revealedTrumpCard,
            currentTrick: state.currentTrick,
            leadSuit: state.leadSuit,
            currentTurnSeat: state.currentTurnSeat,
            leaderSeat: state.leaderSeat,
            lastTrick: state.lastTrick,
            lastTrickWinnerSeat: state.lastTrickWinnerSeat,
            debts: state.debts,
            khichai: khichaiView(state: state, seat: seat, hand: hand),
            roundHistory: state.roundHistory,
            canEndSession: state.canEndSession,
            isHost: isHost,
            message: state.message
        )
    }

    // MARK: Khichai redaction

    private static func khichaiView(state: TDPGameState, seat: TDPSeat, hand: [Card]) -> TDPKhichaiView? {
        guard let step = state.khichaiCurrent else { return nil }
        let isCreditor = step.creditorSeat == seat

        // The drawn card — and therefore the legal returns, which would
        // leak it — go to the creditor and nobody else.
        let drawn: Card? = isCreditor ? step.drawnCard : nil
        var legalReturnIDs: [String]?
        if isCreditor, let drawnCard = step.drawnCard {
            legalReturnIDs = TDPKhichai
                .legalReturns(hand: hand, drawn: drawnCard)
                .map(\.tdpID)
        }

        return TDPKhichaiView(
            creditorSeat: step.creditorSeat,
            debtorSeat: step.debtorSeat,
            fanCount: step.fanOrder.count,
            iAmCreditor: isCreditor,
            iAmDebtor: step.debtorSeat == seat,
            drawnCard: drawn,
            legalReturnIDs: legalReturnIDs
        )
    }

    // MARK: Prompt

    /// What this seat is being asked for right now.
    static func prompt(state: TDPGameState, seat: TDPSeat) -> TDPPrompt {
        switch state.phase {
        case .lobby:
            return (state.player(at: seat)?.isReady ?? false) ? .none : .ready
        case .trumpSelect:
            return state.trumpSelectorSeat == seat ? .chooseTrump : .none
        case .khichai:
            guard let step = state.khichaiCurrent, step.creditorSeat == seat else { return .none }
            return step.drawnCard == nil ? .khichaiDraw : .khichaiReturn
        case .play:
            return state.currentTurnSeat == seat ? .playCard : .none
        case .roundEnd, .sessionEnd:
            return .roundEnd
        default:
            return .none
        }
    }
}
