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

// MARK: - Errors

struct TDPError: Error, LocalizedError, Equatable {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
