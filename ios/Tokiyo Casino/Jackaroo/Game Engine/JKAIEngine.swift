//
//  JKAIEngine.swift
//  Tokiyo Casino — Jackaroo
//
//  Phase 1 stub. Picks the first legal move. The Phase 4 heuristic
//  scorer slots in here without touching anything else in the engine.
//

import Foundation

public struct JKAIEngine {
    public init() {}

    /// Returns `nil` if there are zero legal moves (engine should
    /// treat that as game-over-by-stuck, but the legal-move generator
    /// always emits a burn when `burnOnNoMove` is on, so this should
    /// be unreachable in practice).
    public func chooseMove(for seat: SeatID,
                           moves: [JKMove],
                           state: JKGameState) -> JKMove? {
        // Stable, deterministic: prefer the first non-burn move; if all
        // moves are burns, take the first one. Stable ordering matches
        // the generator's natural iteration order so replay is exact.
        if let firstNonBurn = moves.first(where: { !$0.isBurn }) {
            return firstNonBurn
        }
        return moves.first
    }
}
