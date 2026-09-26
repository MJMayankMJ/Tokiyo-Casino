//
//  TDPScoring.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Deltas and the creditor/debtor pairing that drives khichai.
//
//  Quotas sum to 10, which is the number of tricks, so the three deltas
//  always sum to zero. `computeDebts` relies on that: supply of owed
//  tricks always exactly matches demand.
//

import Foundation

enum TDPScoring {

    static func delta(tricks: Int, quota: Int) -> Int { tricks - quota }

    /// Pairs the previous round's negative deltas (debtors) with its positive
    /// deltas (creditors). Pulling order follows the classic role order:
    /// selector, third, dealer for creditors; dealer, third, selector for
    /// debtors. Expressing this by role keeps it correct for our clockwise
    /// mirror of the traditional counter-clockwise table.
    static func computeDebts(players: [TDPPlayer],
                             deltas: [String: Int],
                             dealerSeat: TDPSeat) -> [TDPDebt] {
        let selector = TDPRoles.nextSeat(dealerSeat)
        let third = TDPRoles.prevSeat(dealerSeat)
        let creditorOrder = [selector, third, dealerSeat]
        let debtorOrder = [dealerSeat, third, selector]
        let validSeats = Set(players.map(\.seat))

        var creditors = creditorOrder
            .filter { validSeats.contains($0) }
            .map { (seat: $0, amount: deltas[String($0)] ?? 0) }
            .filter { $0.amount > 0 }

        var debtors = debtorOrder
            .filter { validSeats.contains($0) }
            .map { (seat: $0, amount: -(deltas[String($0)] ?? 0)) }
            .filter { $0.amount > 0 }

        var debts: [TDPDebt] = []
        var i = 0
        var j = 0
        while i < creditors.count && j < debtors.count {
            let take = min(creditors[i].amount, debtors[j].amount)
            if take > 0 {
                debts.append(TDPDebt(from: debtors[j].seat, to: creditors[i].seat, amount: take))
                creditors[i].amount -= take
                debtors[j].amount -= take
            }
            if creditors[i].amount == 0 { i += 1 }
            if debtors[j].amount == 0 { j += 1 }
        }
        return debts
    }

    /// Expands each debt into one mandatory pull task per owed trick.
    static func expandKhichaiQueue(debts: [TDPDebt]) -> [(creditor: TDPSeat, debtor: TDPSeat)] {
        var queue: [(creditor: TDPSeat, debtor: TDPSeat)] = []
        for debt in debts {
            for _ in 0..<debt.amount {
                queue.append((creditor: debt.to, debtor: debt.from))
            }
        }
        return queue
    }

}
