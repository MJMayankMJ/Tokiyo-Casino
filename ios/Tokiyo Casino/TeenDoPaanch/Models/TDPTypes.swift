//
//  TDPTypes.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Small shared enums. Raw values are on the wire, so renaming one is a
//  breaking protocol change.
//

import Foundation

typealias TDPSeat = Int

// MARK: - Roles and quotas

enum TDPRole: String, Codable, CaseIterable {
    case trumpSelector
    case third
    case dealer

    /// Tricks this seat must win. Sums to 10 across the three roles, which
    /// is why the game is strictly zero-sum.
    var quota: Int {
        switch self {
        case .trumpSelector: return 5
        case .third:         return 3
        case .dealer:        return 2
        }
    }

    var label: String {
        switch self {
        case .trumpSelector: return "Trump (5)"
        case .third:         return "Third (3)"
        case .dealer:        return "Dealer (2)"
        }
    }
}

// MARK: - Phases

enum TDPPhase: String, Codable {
    case lobby
    case dealerDraw
    case dealFirstFive
    case trumpSelect
    case dealThree
    case dealTwo
    /// A debtor chooses, per creditor, to give up tricks or give cards.
    case settle
    case khichai
    case play
    case trickResolve
    case roundEnd
    case sessionEnd
}

// MARK: - Trump

enum TDPTrumpMethod: String, Codable {
    /// Selector named a suit outright from their first five.
    case choose
    /// The middle card of the selector's batch of three is turned up.
    case seventh
    /// The highest of the selector's batch of three sets trump, face down.
    case highestOfThree

    var label: String {
        switch self {
        case .choose:         return "Named"
        case .seventh:        return "7th card"
        case .highestOfThree: return "Highest of 3"
        }
    }
}

// MARK: - Settling up

/// How a debtor settles one debt at the start of a round.
enum TDPSettleMethod: String, Codable {
    /// No cards move; this round the debtor's target rises by the amount
    /// owed and the creditor's falls by the same amount.
    case giveTricks
    /// The creditor pulls that many cards, blind (classic khichai).
    case giveCards
}

/// A debt settled by giving up tricks. Kept per round because the same
/// debtor may not do this to the same creditor in consecutive rounds.
struct TDPConcession: Codable, Equatable {
    let debtor: TDPSeat
    let creditor: TDPSeat
    let amount: Int
}

// MARK: - Errors

struct TDPError: Error, LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
