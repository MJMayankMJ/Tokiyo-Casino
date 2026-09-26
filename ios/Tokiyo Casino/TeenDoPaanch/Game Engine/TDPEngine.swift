//
//  TDPEngine.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The authoritative rules engine. Every mutation of `TDPGameState` goes
//  through `apply(_:)`, which either succeeds or returns a `TDPError` and
//  leaves the state untouched. The host owns the only instance; clients
//  never run it.
//

import Foundation

// MARK: - Actions

enum TDPAction: Equatable {
    case setReady(seat: TDPSeat, ready: Bool)
    case setTargetRounds(seat: TDPSeat, rounds: Int)
    case startDealerDraw
    case drawForDealer(seat: TDPSeat)
    case resolveDealerDraw
    case dealFirstFive
    case selectTrumpSuit(seat: TDPSeat, suit: Suit)
    case selectTrumpSeventh(seat: TDPSeat)
    case selectTrumpHighestOfThree(seat: TDPSeat)
    case dealThree
    case dealTwo
    case khichaiDraw(seat: TDPSeat, fanIndex: Int?)
    case khichaiReturn(seat: TDPSeat, cardID: String)
    case playCard(seat: TDPSeat, cardID: String)
    case ackTrick
    case beginNextRound
    case extendSession(seat: TDPSeat)
    case endSession(seat: TDPSeat)
}

// MARK: - Engine

final class TDPEngine {

    private(set) var state: TDPGameState

    init(state: TDPGameState) {
        self.state = state
    }

    convenience init(tableID: String, seed: UInt32, players: [TDPPlayer]) {
        self.init(state: TDPGameState(tableID: tableID, seed: seed, players: players))
    }

    // MARK: Seating (lobby only)

    /// Seats a player. Rejected once the game has left the lobby, so the
    /// table cannot change shape mid-session.
    @discardableResult
    func addPlayer(_ player: TDPPlayer) -> TDPError? {
        guard state.phase == .lobby else { return TDPError("The game has already started.") }
        guard state.players.count < TDPRoles.seatCount else { return TDPError("The table is full.") }
        guard (0..<TDPRoles.seatCount).contains(player.seat) else {
            return TDPError("That seat does not exist.")
        }
        guard state.player(at: player.seat) == nil else { return TDPError("That seat is taken.") }
        state.players.append(player)
        state.players.sort { $0.seat < $1.seat }
        state.scores[String(player.seat)] = 0
        return nil
    }

    /// The first free seat, or nil when the table is full.
    var firstOpenSeat: TDPSeat? {
        (0..<TDPRoles.seatCount).first { state.player(at: $0) == nil }
    }

    @discardableResult
    func removePlayer(at seat: TDPSeat) -> TDPError? {
        guard state.phase == .lobby else { return TDPError("Seats are fixed once play begins.") }
        state.players.removeAll { $0.seat == seat }
        state.scores.removeValue(forKey: String(seat))
        return nil
    }

    /// Host-side configuration before anyone is seated. Gameplay changes
    /// still go through `.setTargetRounds`, which validates the actor.
    func configureTargetRounds(_ rounds: Int) {
        guard state.phase == .lobby, rounds >= 3, rounds % 3 == 0 else { return }
        state.targetRounds = rounds
    }

    // MARK: Entry point

    @discardableResult
    func apply(_ action: TDPAction) -> TDPError? {
        var draft = state
        let error: TDPError?
        switch action {
        case .setReady(let seat, let ready):            error = setReady(&draft, seat, ready)
        case .setTargetRounds(let seat, let rounds):    error = setTargetRounds(&draft, seat, rounds)
        case .startDealerDraw:                          error = startDealerDraw(&draft)
        case .drawForDealer(let seat):                  error = drawForDealer(&draft, seat)
        case .resolveDealerDraw:                        error = resolveDealerDraw(&draft)
        case .dealFirstFive:                            error = dealFirstFive(&draft)
        case .selectTrumpSuit(let seat, let suit):      error = selectTrump(&draft, seat, .choose, suit: suit)
        case .selectTrumpSeventh(let seat):             error = selectTrump(&draft, seat, .seventh, suit: nil)
        case .selectTrumpHighestOfThree(let seat):      error = selectTrump(&draft, seat, .highestOfThree, suit: nil)
        case .dealThree:                                error = dealThree(&draft)
        case .dealTwo:                                  error = dealTwo(&draft)
        case .khichaiDraw(let seat, let index):         error = khichaiDraw(&draft, seat, index)
        case .khichaiReturn(let seat, let cardID):       error = khichaiReturn(&draft, seat, cardID)
        case .playCard(let seat, let cardID):           error = playCard(&draft, seat, cardID)
        case .ackTrick:                                 error = ackTrick(&draft)
        case .beginNextRound:                           error = beginNextRound(&draft)
        case .extendSession(let seat):                  error = extendSession(&draft, seat)
        case .endSession(let seat):                     error = endSession(&draft, seat)
        }
        if error == nil { state = draft }
        return error
    }

    /// Drives every step that needs no player decision: the first-dealer
    /// draw (pure chance), the three deal batches, and collecting a
    /// completed trick. The UI calls this after its animations so phases
    /// advance at a watchable pace; headless callers call it in a loop.
    ///
    /// `skipDraw`/`skipDeals`/`skipTricks` let a UI hold a step back so it
    /// can animate it instead.
    func flushAutomatic(skipDraw: Bool = false, skipDeals: Bool = false, skipTricks: Bool = false) {
        for _ in 0..<64 {
            let action: TDPAction
            switch state.phase {
            case .dealerDraw where !skipDraw:
                // Drawing for the deal is chance alone, so the engine can
                // do it for whoever still owes a draw.
                if let seat = state.dealerDrawPending.first {
                    action = .drawForDealer(seat: seat)
                } else {
                    action = .resolveDealerDraw
                }
            case .dealFirstFive where !skipDeals: action = .dealFirstFive
            case .dealThree where !skipDeals:     action = .dealThree
            case .dealTwo where !skipDeals:       action = .dealTwo
            case .trickResolve where !skipTricks: action = .ackTrick
            default:
                return
            }
            if apply(action) != nil { return }
        }
    }

    // MARK: Lobby

    private func setReady(_ s: inout TDPGameState, _ seat: TDPSeat, _ ready: Bool) -> TDPError? {
        guard s.phase == .lobby else { return TDPError("The game has already started.") }
        guard let index = s.players.firstIndex(where: { $0.seat == seat }) else {
            return TDPError("Unknown player.")
        }
        s.players[index].isReady = ready
        if s.players.count == TDPRoles.seatCount && s.players.allSatisfy({ $0.isReady }) {
            return startDealerDraw(&s)
        }
        return nil
    }

    private func setTargetRounds(_ s: inout TDPGameState, _ seat: TDPSeat, _ rounds: Int) -> TDPError? {
        guard seat == s.hostSeat else { return TDPError("Only the host can set the round count.") }
        guard s.phase == .lobby else { return TDPError("Rounds are fixed once the game starts.") }
        guard rounds >= 3 && rounds % 3 == 0 else {
            return TDPError("A session runs 3 rounds, or a multiple of 3.")
        }
        s.targetRounds = rounds
        return nil
    }

    // MARK: First-dealer draw

    private func startDealerDraw(_ s: inout TDPGameState) -> TDPError? {
        guard s.players.count == TDPRoles.seatCount else {
            return TDPError("Three players are needed.")
        }
        guard Set(s.players.map(\.seat)) == Set(0..<TDPRoles.seatCount) else {
            return TDPError("Players must occupy seats 0, 1 and 2.")
        }
        s.deck = TDPDeck.shuffled(TDPDeck.build(), rng: &s.rng)
        let seats = s.players.map(\.seat).sorted()
        s.phase = .dealerDraw
        s.dealerDrawPending = seats
        s.dealerDrawGroup = seats
        for index in s.players.indices { s.players[index].drawnCard = nil }
        s.message = "Each player draws. Highest card deals."
        return nil
    }

    private func drawForDealer(_ s: inout TDPGameState, _ seat: TDPSeat) -> TDPError? {
        guard s.phase == .dealerDraw else { return TDPError("The draw is not open.") }
        guard s.dealerDrawPending.contains(seat) else { return TDPError("You have already drawn.") }
        guard !s.deck.isEmpty else { return TDPError("The draw pile is empty.") }
        guard let index = s.players.firstIndex(where: { $0.seat == seat }) else {
            return TDPError("Unknown player.")
        }
        let card = s.deck.removeFirst()
        s.players[index].drawnCard = card
        s.dealerDrawPending.removeAll { $0 == seat }
        s.message = "\(s.players[index].name) drew \(card.description)."
        return nil
    }

    private func resolveDealerDraw(_ s: inout TDPGameState) -> TDPError? {
        guard s.phase == .dealerDraw else { return TDPError("The draw is not open.") }
        guard s.dealerDrawPending.isEmpty else { return TDPError("Not everyone has drawn.") }

        let contenders = s.players.filter { s.dealerDrawGroup.contains($0.seat) && $0.drawnCard != nil }
        guard contenders.count == s.dealerDrawGroup.count,
              let best = TDPDeck.highest(contenders.compactMap(\.drawnCard))
        else { return TDPError("Not every contender has drawn.") }

        // Rank ties redraw — suit is deliberately not used as a tie-break
        // here, so the draw feels fair.
        let winners = contenders.filter { $0.drawnCard?.rank == best.rank }
        if winners.count > 1 {
            let tiedSeats = winners.map(\.seat)
            // Put the draw pack back together before a redraw. This prevents
            // an arbitrarily long sequence of rank ties from exhausting it.
            s.deck = TDPDeck.shuffled(TDPDeck.build(), rng: &s.rng)
            s.dealerDrawPending = tiedSeats
            s.dealerDrawGroup = tiedSeats
            for index in s.players.indices where tiedSeats.contains(s.players[index].seat) {
                s.players[index].drawnCard = nil
            }
            s.message = "Tied on \(best.rank.shortString). \(winners.map(\.name).joined(separator: " and ")) draw again."
            return nil
        }

        guard let winner = winners.first else { return TDPError("No dealer could be chosen.") }
        s.resetForNewRound()
        s.dealerSeat = winner.seat
        s.dealerDrawPending = []
        s.dealerDrawGroup = []
        s.roundNumber = 1
        s.phase = .dealFirstFive
        s.message = "\(winner.name) deals."
        return nil
    }

    // MARK: Dealing

    private func dealBatch(_ s: inout TDPGameState,
                           size: Int,
                           expected: TDPPhase,
                           next: TDPPhase,
                           message: String) -> (error: TDPError?, batches: [TDPSeat: [Card]]) {
        guard s.phase == expected else {
            return (TDPError("Cannot deal a batch of \(size) right now."), [:])
        }
        let order = s.dealOrder
        guard order.count == TDPRoles.seatCount else {
            return (TDPError("Roles are not assigned yet."), [:])
        }
        // The pack is rebuilt and shuffled at the start of every deal.
        if size == 5 {
            s.deck = TDPDeck.shuffled(TDPDeck.build(), rng: &s.rng)
        }
        guard s.deck.count >= size * TDPRoles.seatCount else {
            return (TDPError("Not enough cards left to deal."), [:])
        }

        var batches: [TDPSeat: [Card]] = [:]
        for seat in order {
            let drawn = Array(s.deck.prefix(size))
            s.deck.removeFirst(size)
            batches[seat] = drawn
            if let index = s.players.firstIndex(where: { $0.seat == seat }) {
                s.players[index].hand = TDPDeck.sortHand(s.players[index].hand + drawn)
            }
        }
        s.phase = next
        s.message = message
        return (nil, batches)
    }

    private func dealFirstFive(_ s: inout TDPGameState) -> TDPError? {
        let result = dealBatch(&s, size: 5, expected: .dealFirstFive, next: .trumpSelect,
                               message: "Choose trump from your first five.")
        return result.error
    }

    private func selectTrump(_ s: inout TDPGameState,
                             _ seat: TDPSeat,
                             _ method: TDPTrumpMethod,
                             suit: Suit?) -> TDPError? {
        guard s.phase == .trumpSelect else { return TDPError("Trump has already been set.") }
        guard let selector = s.trumpSelectorSeat else { return TDPError("No dealer yet.") }
        guard selector == seat else { return TDPError("Only the trump selector chooses trump.") }

        s.trumpMethod = method
        s.phase = .dealThree
        switch method {
        case .choose:
            guard let suit else { return TDPError("Pick a suit.") }
            s.trump = suit
            s.message = "Trump is \(suit.symbol). Dealing three more."
        case .seventh:
            s.message = "The seventh card will be opened as trump."
        case .highestOfThree:
            s.message = "The highest of the next three sets trump."
        }
        return nil
    }

    private func dealThree(_ s: inout TDPGameState) -> TDPError? {
        let result = dealBatch(&s, size: 3, expected: .dealThree, next: .dealTwo,
                               message: "Three cards dealt.")
        if let error = result.error { return error }
        guard let selector = s.trumpSelectorSeat, let batch = result.batches[selector] else {
            return TDPError("Missing the trump selector's batch.")
        }

        switch s.trumpMethod {
        case .seventh:
            // The selector's 7th card overall = the middle of this batch.
            guard batch.count == 3 else { return TDPError("Seventh card missing.") }
            let seventh = batch[1]
            s.trump = seventh.suit
            s.revealedTrumpCard = seventh
            s.message = "Seventh card \(seventh.description) — \(seventh.suit.symbol) is trump."
        case .highestOfThree:
            guard batch.count == 3, let high = TDPDeck.highest(batch) else {
                return TDPError("Need three cards to pick the highest.")
            }
            s.trump = high.suit
            s.privateTrumpCard = high
            s.message = "Highest of three sets \(high.suit.symbol) as trump."
        default:
            s.message = "Three cards dealt. Two to come."
        }
        return nil
    }

    private func dealTwo(_ s: inout TDPGameState) -> TDPError? {
        let result = dealBatch(&s, size: 2, expected: .dealTwo, next: .play,
                               message: "All ten cards dealt.")
        if let error = result.error { return error }
        for player in s.players where player.hand.count != 10 {
            return TDPError("\(player.name) does not hold 10 cards.")
        }

        // Classic khichai is mandatory and is based only on the immediately
        // preceding round, never on cumulative session scores.
        guard let dealerSeat = s.dealerSeat, let previousDeltas = s.roundHistory.last?.delta else {
            return beginPlay(&s)       // first round: no pulling
        }
        s.debts = TDPScoring.computeDebts(players: s.players,
                                          deltas: previousDeltas,
                                          dealerSeat: dealerSeat)
        return beginKhichaiOrPlay(&s)
    }

    // MARK: Khichai setup

    private func beginKhichaiOrPlay(_ s: inout TDPGameState) -> TDPError? {
        let pairs = TDPScoring.expandKhichaiQueue(debts: s.debts)
        guard !pairs.isEmpty else { return beginPlay(&s) }

        var queue: [TDPKhichaiStep] = []
        for pair in pairs {
            let count = s.player(at: pair.debtor)?.hand.count ?? 0
            queue.append(TDPKhichaiStep(creditorSeat: pair.creditor,
                                        debtorSeat: pair.debtor,
                                        drawnCard: nil,
                                        fanOrder: TDPKhichai.makeFanOrder(count: count, rng: &s.rng)))
        }
        s.khichaiCurrent = queue.removeFirst()
        s.khichaiQueue = queue
        s.phase = .khichai
        if let step = s.khichaiCurrent {
            s.message = "\(s.name(at: step.creditorSeat)) pulls from \(s.name(at: step.debtorSeat))."
        }
        return nil
    }

    // MARK: Khichai

    private func khichaiDraw(_ s: inout TDPGameState, _ seat: TDPSeat, _ fanIndex: Int?) -> TDPError? {
        guard s.phase == .khichai, var step = s.khichaiCurrent else {
            return TDPError("There is no pull in progress.")
        }
        guard step.creditorSeat == seat else { return TDPError("Only the winning player draws.") }
        guard step.drawnCard == nil else { return TDPError("A card has already been drawn.") }
        guard let debtorIndex = s.players.firstIndex(where: { $0.seat == step.debtorSeat }),
              let creditorIndex = s.players.firstIndex(where: { $0.seat == seat })
        else { return TDPError("Missing a player for the pull.") }

        let debtorHand = s.players[debtorIndex].hand
        switch TDPKhichai.resolveDraw(debtorHand: debtorHand,
                                      fanOrder: step.fanOrder,
                                      fanIndex: fanIndex,
                                      rng: &s.rng) {
        case .failure(let error):
            return error
        case .success(let card):
            s.players[debtorIndex].hand.removeAll { $0.tdpID == card.tdpID }
            s.players[creditorIndex].hand = TDPDeck.sortHand(s.players[creditorIndex].hand + [card])
            step.drawnCard = card
            s.khichaiCurrent = step
            s.message = "\(s.players[creditorIndex].name) drew a card and must return a different one."
            return nil
        }
    }

    private func khichaiReturn(_ s: inout TDPGameState,
                               _ seat: TDPSeat,
                               _ returnCardID: String) -> TDPError? {
        guard s.phase == .khichai, let step = s.khichaiCurrent else {
            return TDPError("There is no pull in progress.")
        }
        guard step.creditorSeat == seat else { return TDPError("Only the winning player decides.") }
        guard let drawn = step.drawnCard else { return TDPError("Draw a card first.") }
        guard let creditorIndex = s.players.firstIndex(where: { $0.seat == seat }),
              let debtorIndex = s.players.firstIndex(where: { $0.seat == step.debtorSeat })
        else { return TDPError("Missing a player for the pull.") }

        let hands = TDPKhichai.Hands(creditor: s.players[creditorIndex].hand,
                                     debtor: s.players[debtorIndex].hand)
        switch TDPKhichai.applyReturn(hands: hands,
                                      drawn: drawn,
                                      returnCardID: returnCardID) {
        case .failure(let error):
            return error
        case .success(let next):
            s.players[creditorIndex].hand = TDPDeck.sortHand(next.creditor)
            s.players[debtorIndex].hand = TDPDeck.sortHand(next.debtor)
            if s.khichaiQueue.isEmpty {
                s.khichaiCurrent = nil
                return beginPlay(&s)
            }
            var following = s.khichaiQueue.removeFirst()
            let count = s.player(at: following.debtorSeat)?.hand.count ?? 0
            following.fanOrder = TDPKhichai.makeFanOrder(count: count, rng: &s.rng)
            s.khichaiCurrent = following
            s.message = "\(s.name(at: following.creditorSeat)) pulls next."
            return nil
        }
    }

    // MARK: Play

    private func beginPlay(_ s: inout TDPGameState) -> TDPError? {
        guard let selector = s.trumpSelectorSeat else { return TDPError("Missing the trump selector.") }
        guard s.trump != nil else { return TDPError("Trump has not been set.") }
        s.phase = .play
        s.debts = []
        s.currentTurnSeat = selector
        s.leaderSeat = selector
        s.trickNumber = 0
        s.currentTrick = []
        s.leadSuit = nil
        s.message = "\(s.name(at: selector)) leads."
        return nil
    }

    private func playCard(_ s: inout TDPGameState, _ seat: TDPSeat, _ cardID: String) -> TDPError? {
        if let error = TDPLegalMoves.validate(s, seat: seat, cardID: cardID) { return error }
        guard let playerIndex = s.players.firstIndex(where: { $0.seat == seat }),
              let card = s.players[playerIndex].hand.first(where: { $0.tdpID == cardID })
        else { return TDPError("Card not in hand.") }

        s.players[playerIndex].hand.removeAll { $0.tdpID == cardID }
        s.currentTrick.append(TDPTrickPlay(seat: seat, card: card))
        if s.currentTrick.count == 1 { s.leadSuit = card.suit }

        if s.currentTrick.count < TDPRoles.seatCount {
            let next = TDPRoles.nextSeat(seat)
            s.currentTurnSeat = next
            s.message = "\(s.name(at: next)) to play."
            return nil
        }

        guard let trump = s.trump, let lead = s.leadSuit,
              let winner = TDPLegalMoves.trickWinner(plays: s.currentTrick, trump: trump, leadSuit: lead)
        else { return TDPError("Could not resolve the trick.") }

        if let winnerIndex = s.players.firstIndex(where: { $0.seat == winner }) {
            s.players[winnerIndex].tricksWon += 1
        }
        s.phase = .trickResolve
        s.lastTrick = s.currentTrick
        s.lastTrickWinnerSeat = winner
        s.currentTurnSeat = nil
        s.message = "\(s.name(at: winner)) takes the trick."
        return nil
    }

    private func ackTrick(_ s: inout TDPGameState) -> TDPError? {
        guard s.phase == .trickResolve else { return TDPError("No trick is waiting.") }
        let next = s.trickNumber + 1
        guard next < 10 else { return finishRound(&s) }
        s.phase = .play
        s.trickNumber = next
        s.currentTrick = []
        s.leadSuit = nil
        s.leaderSeat = s.lastTrickWinnerSeat
        s.currentTurnSeat = s.lastTrickWinnerSeat
        s.message = "\(s.name(at: s.lastTrickWinnerSeat)) leads."
        return nil
    }

    private func finishRound(_ s: inout TDPGameState) -> TDPError? {
        guard let dealerSeat = s.dealerSeat, let trump = s.trump else {
            return TDPError("Round is missing its dealer or trump.")
        }
        var tricks: [String: Int] = [:]
        var quotas: [String: Int] = [:]
        var deltas: [String: Int] = [:]
        for player in s.players {
            let quota = TDPRoles.quota(seat: player.seat, dealerSeat: dealerSeat)
            let delta = TDPScoring.delta(tricks: player.tricksWon, quota: quota)
            let key = String(player.seat)
            tricks[key] = player.tricksWon
            quotas[key] = quota
            deltas[key] = delta
            // Classic scoring awards one point per trick. The quota delta is
            // recorded separately because it drives next round's khichai.
            s.scores[key] = (s.scores[key] ?? 0) + player.tricksWon
        }
        // Quotas sum to the trick count, so the deltas must cancel out.
        assert(deltas.values.reduce(0, +) == 0, "Teen Do Paanch deltas must sum to zero")

        s.roundHistory.append(TDPRoundScore(round: s.roundHistory.count + 1,
                                            dealerSeat: dealerSeat,
                                            trump: trump,
                                            trumpMethod: s.trumpMethod ?? .choose,
                                            tricks: tricks,
                                            quotas: quotas,
                                            delta: deltas))
        let nextDealer = TDPRoles.rotateDealer(dealerSeat)
        s.debts = TDPScoring.computeDebts(players: s.players,
                                          deltas: deltas,
                                          dealerSeat: nextDealer)
        s.currentTrick = []
        s.currentTurnSeat = nil
        s.phase = .roundEnd

        if s.roundHistory.count >= s.targetRounds && s.canEndSession {
            s.phase = .sessionEnd
            s.message = "Session complete."
        } else {
            s.message = "Round \(s.roundHistory.count) complete. Roles rotate."
        }
        return nil
    }

    // MARK: Session

    private func beginNextRound(_ s: inout TDPGameState) -> TDPError? {
        guard s.phase == .roundEnd else { return TDPError("The round is not over.") }
        guard let dealerSeat = s.dealerSeat else { return TDPError("Missing dealer.") }
        let nextDealer = TDPRoles.rotateDealer(dealerSeat)
        s.resetForNewRound()
        s.dealerSeat = nextDealer
        s.roundNumber += 1
        s.phase = .dealFirstFive
        s.message = "\(s.name(at: nextDealer)) deals round \(s.roundNumber)."
        return nil
    }

    private func extendSession(_ s: inout TDPGameState, _ seat: TDPSeat) -> TDPError? {
        guard seat == s.hostSeat else { return TDPError("Only the host can add rounds.") }
        guard s.phase == .roundEnd || s.phase == .sessionEnd else {
            return TDPError("Add rounds between games.")
        }
        s.targetRounds += 3
        s.phase = .roundEnd
        s.message = "Playing through \(s.targetRounds) rounds."
        return nil
    }

    private func endSession(_ s: inout TDPGameState, _ seat: TDPSeat) -> TDPError? {
        guard seat == s.hostSeat else { return TDPError("Only the host can end the session.") }
        guard s.phase == .roundEnd || s.phase == .sessionEnd else {
            return TDPError("Finish the current round first.")
        }
        guard s.canEndSession else {
            return TDPError("A session must end on a multiple of three rounds.")
        }
        s.phase = .sessionEnd
        s.message = "Session complete."
        return nil
    }
}
