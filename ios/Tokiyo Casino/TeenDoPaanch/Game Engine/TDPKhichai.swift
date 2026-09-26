//
//  TDPKhichai.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  खिंचाई — "the pulling". The creditor draws blind from the debtor's fanned
//  hand, looks at it, then keeps it and returns a different legal card.
//
//  The draw is blind by construction: the creditor picks a *position in a
//  shuffled fan*, and only the host can map that position to a card.
//

import Foundation

enum TDPKhichai {

    /// Shuffled presentation order for a debtor's hand. Without this the
    /// creditor could infer a card from its index, because hands are stored
    /// sorted.
    static func makeFanOrder(count: Int, rng: inout TDPRNG) -> [Int] {
        var order = Array(0..<count)
        guard order.count > 1 else { return order }
        for i in stride(from: order.count - 1, to: 0, by: -1) {
            let j = rng.int(upperBound: i + 1)
            order.swapAt(i, j)
        }
        return order
    }

    /// Resolves a fan position to an actual card in the debtor's hand.
    /// `fanIndex == nil` picks at random (used by AI creditors, which must
    /// not be able to see the hand they are drawing from).
    static func resolveDraw(debtorHand: [Card],
                            fanOrder: [Int],
                            fanIndex: Int?,
                            rng: inout TDPRNG) -> Result<Card, TDPError> {
        guard !debtorHand.isEmpty else {
            return .failure(TDPError("That player has no cards to draw from."))
        }
        let expectedIndices = Set(debtorHand.indices)
        guard fanOrder.count == debtorHand.count, Set(fanOrder) == expectedIndices else {
            return .failure(TDPError("The fan is out of sync."))
        }
        let position: Int
        if let fanIndex {
            guard fanIndex >= 0 && fanIndex < fanOrder.count else {
                return .failure(TDPError("That is not a card in the fan."))
            }
            position = fanIndex
        } else {
            position = rng.int(upperBound: fanOrder.count)
        }
        let handIndex = fanOrder[position]
        guard handIndex >= 0 && handIndex < debtorHand.count else {
            return .failure(TDPError("The fan is out of sync."))
        }
        return .success(debtorHand[handIndex])
    }

    struct Hands: Equatable {
        var creditor: [Card]
        var debtor: [Card]
    }

    /// Applies the creditor's mandatory return of a different card.
    /// Called *after* the drawn card has already moved into the creditor's
    /// hand, so the creditor is holding 11 cards on entry.
    static func applyReturn(hands: Hands,
                            drawn: Card,
                            returnCardID: String) -> Result<Hands, TDPError> {

        guard hands.creditor.contains(where: { $0.tdpID == drawn.tdpID }) else {
            return .failure(TDPError("The drawn card is not in hand."))
        }
        guard let returning = hands.creditor.first(where: { $0.tdpID == returnCardID }) else {
            return .failure(TDPError("You can only return a card you hold."))
        }
        // R1 — never return the card just taken.
        guard returning.tdpID != drawn.tdpID else {
            return .failure(TDPError("The pulled card must be kept; return a different card."))
        }
        // R2 — retain at least two cards in the suit being returned.
        let remaining = hands.creditor.filter { $0.suit == returning.suit && $0.tdpID != returning.tdpID }
        if remaining.count < 2 {
            return .failure(TDPError("You'd be left with too few \(returning.suit.rawValue)."))
        }

        var next = hands
        next.creditor.removeAll { $0.tdpID == returnCardID }
        next.debtor.append(returning)
        return .success(next)
    }

    /// Cards the creditor may legally return, given the restrictions.
    static func legalReturns(hand: [Card], drawn: Card) -> [Card] {
        let candidates = hand.filter { $0.tdpID != drawn.tdpID }
        return candidates.filter { card in
            hand.filter { $0.suit == card.suit && $0.tdpID != card.tdpID }.count >= 2
        }
    }
}
