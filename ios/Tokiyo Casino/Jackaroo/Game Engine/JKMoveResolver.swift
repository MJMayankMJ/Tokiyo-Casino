//
//  JKMoveResolver.swift
//  Tokiyo Casino — Jackaroo
//
//  Applies a JKMove to a JKGameState. Mutates state, removes consumed
//  cards from the player's hand, sends them to the Fire Pile, advances
//  marbles, captures, swaps, and emits log events.
//
//  Path computation: we re-walk the path here so the UI gets the
//  intermediate cells for marble animation. We re-run the generator's
//  walker rather than trying to encode paths inside `JKMove` because
//  state changes between move generation and apply time (in 7-split,
//  for example).
//

import Foundation

public struct JKMoveResolver {
    public let graph: JKBoardGraph
    public let generator: JKLegalMoveGenerator

    public init(graph: JKBoardGraph) {
        self.graph = graph
        self.generator = JKLegalMoveGenerator(graph: graph)
    }

    /// Apply a move. Caller is responsible for ensuring the move is
    /// legal (came from the legal-move generator). The resolver
    /// trusts that and asserts in debug.
    public mutating func apply(_ move: JKMove,
                               by seat: SeatID,
                               to state: inout JKGameState) {
        state.log.append(.played(seat: seat, move: move))

        switch move {
        case let .fieldFromHome(card, marble):
            applyFieldFromHome(card: card, marble: marble, seat: seat, state: &state)

        case let .forward(card, marble, steps):
            applyTrackMove(card: card, marble: marble, steps: steps,
                           seat: seat, backward: false, state: &state)

        case let .backward(card, marble, steps):
            applyTrackMove(card: card, marble: marble, steps: steps,
                           seat: seat, backward: true, state: &state)

        case let .anyMarble5(card, marble, steps):
            applyTrackMove(card: card, marble: marble, steps: steps,
                           seat: seat, backward: false, state: &state,
                           allowSafeEntry: false)

        case let .split7(card, allocations):
            applySplit7(card: card, allocations: allocations, seat: seat, state: &state)

        case let .swap(card, ownMarble, otherMarble):
            applySwap(card: card, ownMarble: ownMarble,
                      otherMarble: otherMarble, seat: seat, state: &state)

        case let .redQueenDiscard(card, victim):
            applyRedQueenDiscard(card: card, victim: victim, seat: seat, state: &state)

        case let .burnHand(cards):
            applyBurnHand(cards: cards, seat: seat, state: &state)

        case let .burnCard(card):
            applyBurnCard(card: card, seat: seat, state: &state)
        }

        // Handoff check — engages once a seat has finished all 4 of its
        // own marbles. The bit is sticky for the rest of the game.
        for s in 0..<4 where !state.handoffEngaged[s] {
            if state.hasFinishedOwnMarbles(s) {
                state.handoffEngaged[s] = true
                state.log.append(.handoffEngaged(seat: s))
            }
        }

        // Victory check.
        if let w = state.winnerIfAny() {
            state.winner = w
            state.phase = .finished
            state.log.append(.gameOver(winner: w))
        }
    }

    // MARK: - Concrete handlers

    private func applyFieldFromHome(card: JKCard, marble: MarbleID,
                                    seat: SeatID, state: inout JKGameState) {
        guard let mIdx = state.marbles.firstIndex(where: { $0.id == marble }) else { return }
        let m = state.marbles[mIdx]
        guard let baseID = graph.baseCell[m.owner] else { return }
        let from = m.position
        // Capture anyone on the Base cell (opponent only — own marble
        // on Base is blocked by the legal-move generator).
        captureMarbleAt(cell: baseID, except: m.id, state: &state)
        state.marbles[mIdx].position = .track(baseID)
        consumeCard(card, from: seat, state: &state)
        state.log.append(.marbleMoved(marble, from: from, to: .track(baseID), via: [baseID]))
    }

    private func applyTrackMove(card: JKCard, marble: MarbleID, steps: Int,
                                seat: SeatID, backward: Bool,
                                state: inout JKGameState,
                                allowSafeEntry: Bool = true) {
        guard let mIdx = state.marbles.firstIndex(where: { $0.id == marble }) else { return }
        let m = state.marbles[mIdx]
        let outcome: JKLegalMoveGenerator.WalkOutcome?
        if backward {
            outcome = generator.walkBackward(marble: m, steps: steps, seat: seat, state: state)
        } else {
            outcome = generator.walkForward(marble: m, steps: steps, seat: seat,
                                            state: state, preferSafeEntry: allowSafeEntry)
        }
        guard let o = outcome else {
            assertionFailure("Resolver received an illegal move: \(card.debugDescription) for marble \(marble)")
            return
        }
        let from = m.position
        if let captured = o.capture {
            sendHome(marbleID: captured, state: &state)
            state.log.append(.captured(captured, by: seat))
        }
        state.marbles[mIdx].position = o.destination
        consumeCard(card, from: seat, state: &state)
        state.log.append(.marbleMoved(marble, from: from, to: o.destination, via: o.path))
    }

    private func applySplit7(card: JKCard,
                             allocations: [JKSplitAllocation],
                             seat: SeatID,
                             state: inout JKGameState) {
        for alloc in allocations {
            guard let mIdx = state.marbles.firstIndex(where: { $0.id == alloc.marble }) else { return }
            let m = state.marbles[mIdx]
            guard let o = generator.walkForward(marble: m, steps: alloc.steps,
                                                seat: seat, state: state) else {
                assertionFailure("Split-7 sub-step illegal in resolver")
                return
            }
            let from = m.position
            if let captured = o.capture {
                sendHome(marbleID: captured, state: &state)
                state.log.append(.captured(captured, by: seat))
            }
            state.marbles[mIdx].position = o.destination
            state.log.append(.marbleMoved(alloc.marble, from: from, to: o.destination, via: o.path))
        }
        consumeCard(card, from: seat, state: &state)
    }

    private func applySwap(card: JKCard,
                           ownMarble: MarbleID,
                           otherMarble: MarbleID,
                           seat: SeatID,
                           state: inout JKGameState) {
        guard let aIdx = state.marbles.firstIndex(where: { $0.id == ownMarble }),
              let bIdx = state.marbles.firstIndex(where: { $0.id == otherMarble }) else { return }
        let oldA = state.marbles[aIdx].position
        let oldB = state.marbles[bIdx].position
        state.marbles[aIdx].position = oldB
        state.marbles[bIdx].position = oldA
        consumeCard(card, from: seat, state: &state)
        state.log.append(.swapped(ownMarble, otherMarble, by: seat))
        state.log.append(.marbleMoved(ownMarble, from: oldA, to: oldB, via: []))
        state.log.append(.marbleMoved(otherMarble, from: oldB, to: oldA, via: []))
    }

    private func applyRedQueenDiscard(card: JKCard, victim: SeatID,
                                      seat: SeatID, state: inout JKGameState) {
        consumeCard(card, from: seat, state: &state)
        guard !state.players[victim].hand.isEmpty else { return }
        // Random pick from the victim's hand using state.rng — fully
        // deterministic from seed + log.
        let idx = state.rng.nextInt(in: 0...(state.players[victim].hand.count - 1))
        let discarded = state.players[victim].hand.remove(at: idx)
        state.firePile.append(discarded)
        state.log.append(.redQueenResolved(victim: victim, discardedCard: discarded))
    }

    private func applyBurnHand(cards: [JKCard], seat: SeatID,
                               state: inout JKGameState) {
        // Move every card from the player's hand to the Fire Pile.
        for c in state.players[seat].hand {
            state.firePile.append(c)
        }
        state.players[seat].hand.removeAll()
        state.log.append(.burned(seat: seat, cards: cards))
    }

    private func applyBurnCard(card: JKCard, seat: SeatID,
                               state: inout JKGameState) {
        consumeCard(card, from: seat, state: &state)
        state.log.append(.burned(seat: seat, cards: [card]))
    }

    // MARK: - Internals

    private func consumeCard(_ card: JKCard, from seat: SeatID,
                             state: inout JKGameState) {
        if let idx = state.players[seat].hand.firstIndex(of: card) {
            state.players[seat].hand.remove(at: idx)
            state.firePile.append(card)
        } else {
            assertionFailure("Tried to consume card not in hand: \(card.debugDescription)")
        }
    }

    private func captureMarbleAt(cell: CellID, except mover: MarbleID,
                                 state: inout JKGameState) {
        let idx = state.marbles.firstIndex(where: { m in
            guard m.id != mover else { return false }
            if case .track(let c) = m.position { return c == cell }
            return false
        })
        if let i = idx {
            let id = state.marbles[i].id
            sendHome(marbleID: id, state: &state)
            state.log.append(.captured(id, by: state.currentSeat))
        }
    }

    private func sendHome(marbleID: MarbleID, state: inout JKGameState) {
        guard let idx = state.marbles.firstIndex(where: { $0.id == marbleID }) else { return }
        let owner = state.marbles[idx].owner
        // Pick the lowest-numbered empty Home slot.
        let occupied: Set<Int> = Set(
            state.marbles.compactMap { m -> Int? in
                guard m.owner == owner else { return nil }
                if case .home(let slot) = m.position { return slot }
                return nil
            }
        )
        let slot = (0..<4).first(where: { !occupied.contains($0) }) ?? 0
        state.marbles[idx].position = .home(slot: slot)
    }
}
