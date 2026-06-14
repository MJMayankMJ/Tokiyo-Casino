//
//  JackarooEngine.swift
//  Tokiyo Casino — Jackaroo
//
//  Top-level coordinator. Owns the state, runs the turn loop, fans
//  out to the legal-move generator + resolver + AI, and notifies the
//  UI via the delegate. The engine is the only piece that mutates
//  `JKGameState`.
//
//  Threading: single-threaded, main-thread. AI is cheap so we don't
//  need a background queue in V1.
//

import Foundation

public protocol JackarooEngineDelegate: AnyObject {
    func didDeal()
    func didChangeTurn(_ seat: SeatID)
    func willResolve(_ move: JKMove, by seat: SeatID, path: [CellID])
    func didResolve(_ move: JKMove, by seat: SeatID)
    func didCapture(_ marble: MarbleID, by seat: SeatID)
    func didEngageHandoff(_ seat: SeatID)
    func didEnd(winner: JKTeam)
}

public extension JackarooEngineDelegate {
    func didDeal() {}
    func didChangeTurn(_: SeatID) {}
    func willResolve(_: JKMove, by _: SeatID, path _: [CellID]) {}
    func didResolve(_: JKMove, by _: SeatID) {}
    func didCapture(_: MarbleID, by _: SeatID) {}
    func didEngageHandoff(_: SeatID) {}
    func didEnd(winner _: JKTeam) {}
}

public final class JackarooEngine {
    public weak var delegate: JackarooEngineDelegate?

    public let graph: JKBoardGraph
    public private(set) var state: JKGameState

    private let generator: JKLegalMoveGenerator
    private var resolver: JKMoveResolver
    private let ai: JKAIEngine

    // MARK: - Init

    /// Set up a fresh game. The 4 players come from the caller; marbles
    /// are auto-generated (4 per seat, all in Home).
    public init(players: [JKPlayer],
                rules: JKRulesPreset = .jawakerBasic,
                seed: UInt64,
                cellsPerQuadrant: Int = 25,
                ai: JKAIEngine = JKAIEngine()) {
        precondition(players.count == 4, "Jackaroo needs exactly 4 players")
        self.graph = JKBoardGraph(cellsPerQuadrant: cellsPerQuadrant)
        self.ai = ai

        var marbles: [JKMarble] = []
        marbles.reserveCapacity(16)
        for seat in 0..<4 {
            for slot in 0..<4 {
                marbles.append(JKMarble(
                    id: seat * 4 + slot,
                    owner: seat,
                    position: .home(slot: slot)
                ))
            }
        }
        var rng = JKSeededRNG(seed: seed)
        let dealer = rng.nextInt(in: 0...3)
        self.state = JKGameState(players: players,
                                 marbles: marbles,
                                 dealer: dealer,
                                 rules: rules,
                                 seed: seed)
        self.generator = JKLegalMoveGenerator(graph: graph)
        self.resolver = JKMoveResolver(graph: graph)
    }

    // MARK: - Public control

    /// Start the first hand. Deals cards and begins the turn loop.
    public func start() {
        dealNewHand()
        delegate?.didDeal()
        delegate?.didChangeTurn(state.currentSeat)
    }

    /// Apply a specific move (used by the human player path). The move
    /// must be one of the moves currently legal for the active seat.
    public func play(_ move: JKMove) {
        precondition(state.phase == .playing, "Engine is not in .playing phase")
        let seat = state.currentSeat
        let priorHandoff = state.handoffEngaged

        let path = pathPreview(for: move, by: seat)
        delegate?.willResolve(move, by: seat, path: path)
        resolver.apply(move, by: seat, to: &state)
        delegate?.didResolve(move, by: seat)

        // Surface capture + handoff via the delegate (in addition to
        // having been logged inside the resolver).
        for evt in state.log.reversed() {
            switch evt {
            case .captured(let mid, let by) where by == seat:
                delegate?.didCapture(mid, by: by)
            case .played: break
            default: break
            }
            if case .played = evt { break }
        }
        for s in 0..<4 where state.handoffEngaged[s] && !priorHandoff[s] {
            delegate?.didEngageHandoff(s)
        }

        if let w = state.winner {
            delegate?.didEnd(winner: w)
            return
        }

        advanceTurn()
    }

    /// Returns the moves the current human player may pick from. Empty
    /// only when the game has ended.
    public func legalMovesForCurrentSeat() -> [JKMove] {
        generator.moves(in: state, for: state.currentSeat)
    }

    /// Drive the loop while the current seat is an AI. Caller invokes
    /// this after `start()` or after a human move. The engine resolves
    /// AI moves synchronously; UI pacing (the 600–1200 ms delay) is
    /// the view controller's job.
    public func stepAIIfNeeded() {
        guard state.phase == .playing else { return }
        guard case .ai = state.players[state.currentSeat].kind else { return }
        let moves = generator.moves(in: state, for: state.currentSeat)
        guard let pick = ai.chooseMove(for: state.currentSeat,
                                       moves: moves,
                                       state: state) else { return }
        play(pick)
    }

    // MARK: - Turn loop

    private func advanceTurn() {
        // If everyone has exhausted their hand, redeal and reset the
        // turn to the first seat after the new dealer.
        if state.players.allSatisfy({ $0.hand.isEmpty }) {
            rotateDealer()
            dealNewHand()
            delegate?.didDeal()
            state.currentSeat = firstSeatAfter(dealer: state.dealer)
            delegate?.didChangeTurn(state.currentSeat)
            return
        }
        // Otherwise, walk to the next seat that still has cards.
        let n = 4
        var next = state.currentSeat
        for _ in 0..<n {
            next = state.direction == .cw ? (next + 1) % n : (next + n - 1) % n
            if !state.players[next].hand.isEmpty { break }
        }
        state.currentSeat = next
        delegate?.didChangeTurn(next)
    }

    private func firstSeatAfter(dealer: SeatID) -> SeatID {
        state.direction == .cw ? (dealer + 1) % 4 : (dealer + 3) % 4
    }

    private func rotateDealer() {
        state.dealer = state.direction == .cw
            ? (state.dealer + 1) % 4
            : (state.dealer + 3) % 4
    }

    // MARK: - Dealing

    /// Reshuffles the Fire Pile back into the deck if empty, then
    /// deals N cards per seat according to `dealCycle`.
    public func dealNewHand() {
        state.handsDealt += 1
        let cardsPerSeat = cardsToDealThisHand()

        // Refill deck if needed (re-fold Fire Pile, reshuffle).
        ensureDeckHas(cards: cardsPerSeat * 4)

        // Clear leftover cards in hand (shouldn't be any in default).
        for i in 0..<state.players.count {
            state.players[i].hand.removeAll(keepingCapacity: true)
        }

        for _ in 0..<cardsPerSeat {
            for seat in 0..<4 {
                if let c = state.deck.popLast() {
                    state.players[seat].hand.append(c)
                }
            }
        }

        state.phase = .playing
        state.log.append(.dealStart(dealer: state.dealer, cardsPerSeat: cardsPerSeat))
    }

    private func cardsToDealThisHand() -> Int {
        switch state.rules.dealCycle {
        case .four:
            return 4
        case .fourThenFive:
            return state.handsDealt == 1 ? 4 : 5
        case .fourFourFive:
            switch state.handsDealt % 3 {
            case 1: return 4
            case 2: return 4
            default: return 5
            }
        }
    }

    private func ensureDeckHas(cards needed: Int) {
        if state.deck.count >= needed { return }
        // Fold the fire pile back and reshuffle.
        if !state.firePile.isEmpty {
            state.deck.append(contentsOf: state.firePile)
            state.firePile.removeAll(keepingCapacity: true)
            state.log.append(.reshuffled)
        }
        if state.deck.isEmpty {
            state.deck = JKCard.freshDeck()
        }
        // Swift exclusivity: pull the RNG into a local so the in-out
        // parameter and the receiver (state.deck) don't both come from
        // the same root (state).
        var rng = state.rng
        state.deck.jkShuffle(using: &rng)
        state.rng = rng
    }

    // MARK: - Path preview

    /// Re-walk the move to give the delegate a path for animation.
    /// Returns an empty array for moves with no marble movement
    /// (burn, swap, redQueenDiscard).
    private func pathPreview(for move: JKMove, by seat: SeatID) -> [CellID] {
        switch move {
        case let .fieldFromHome(_, marble):
            if let baseID = graph.baseCell[JKMarble.ownerOf(marble)] {
                return [baseID]
            }
            return []
        case let .forward(_, marble, steps),
             let .anyMarble5(_, marble, steps):
            if let m = state.marbles.first(where: { $0.id == marble }),
               let o = generator.walkForward(marble: m, steps: steps,
                                             seat: seat, state: state) {
                return o.path
            }
            return []
        case let .backward(_, marble, steps):
            if let m = state.marbles.first(where: { $0.id == marble }),
               let o = generator.walkBackward(marble: m, steps: steps,
                                              seat: seat, state: state) {
                return o.path
            }
            return []
        case .split7, .swap, .redQueenDiscard, .burnHand, .burnCard:
            return []
        }
    }
}
