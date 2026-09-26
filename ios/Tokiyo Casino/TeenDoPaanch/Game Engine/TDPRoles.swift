//
//  TDPRoles.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Seat → role → quota mapping. Play runs clockwise: 0 → 1 → 2 → 0.
//  With the dealer at D, the trump selector sits at D+1 (dealer's left)
//  and the third player at D+2 (dealer's right).
//

import Foundation

enum TDPRoles {

    static let seatCount = 3

    static func nextSeat(_ seat: TDPSeat) -> TDPSeat { (seat + 1) % seatCount }
    static func prevSeat(_ seat: TDPSeat) -> TDPSeat { (seat + 2) % seatCount }

    static func role(seat: TDPSeat, dealerSeat: TDPSeat) -> TDPRole {
        if seat == dealerSeat { return .dealer }
        if seat == nextSeat(dealerSeat) { return .trumpSelector }
        return .third
    }

    static func quota(seat: TDPSeat, dealerSeat: TDPSeat) -> Int {
        role(seat: seat, dealerSeat: dealerSeat).quota
    }

    /// Dealer rotates clockwise — the outgoing trump selector deals next.
    static func rotateDealer(_ seat: TDPSeat) -> TDPSeat { nextSeat(seat) }
}

extension TDPGameState {

    var trumpSelectorSeat: TDPSeat? {
        guard let dealerSeat else { return nil }
        return TDPRoles.nextSeat(dealerSeat)
    }

    var thirdSeat: TDPSeat? {
        guard let dealerSeat else { return nil }
        return TDPRoles.prevSeat(dealerSeat)
    }

    func role(at seat: TDPSeat) -> TDPRole? {
        guard let dealerSeat else { return nil }
        return TDPRoles.role(seat: seat, dealerSeat: dealerSeat)
    }

    /// This round's target: the role quota plus any tricks given up to or
    /// by this seat while settling. Can dip below zero for a creditor owed
    /// more than their whole quota; the three still sum to 10.
    func quota(at seat: TDPSeat) -> Int {
        baseQuota(at: seat) + (targetAdjust[String(seat)] ?? 0)
    }

    /// The role quota alone (5, 3 or 2).
    func baseQuota(at seat: TDPSeat) -> Int {
        guard let dealerSeat else { return 0 }
        return TDPRoles.quota(seat: seat, dealerSeat: dealerSeat)
    }

    /// Cards are dealt trump selector → third → dealer.
    var dealOrder: [TDPSeat] {
        guard let dealerSeat, let selector = trumpSelectorSeat, let third = thirdSeat else { return [] }
        return [selector, third, dealerSeat]
    }
}
