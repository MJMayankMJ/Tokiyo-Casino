//
//  JKGamePreferences.swift
//  Tokiyo Casino — Jackaroo (Phase 6)
//
//  Per-device gameplay preferences (not per-session). Lives in
//  UserDefaults so it survives relaunch.
//

import Foundation

/// Marble animation speed, surfaced on the in-game gear menu.
enum JKMoveSpeed: String, CaseIterable {
    case slow, medium, fast

    /// Higher = faster: the per-cell step duration is divided by this.
    var multiplier: Double {
        switch self {
        case .slow:   return 1.0
        case .medium: return 1.5
        case .fast:   return 2.0
        }
    }

    var label: String {
        switch self {
        case .slow:   return "1×"
        case .medium: return "1.5×"
        case .fast:   return "2×"
        }
    }
}

enum JKGamePreferences {
    private static let moveSpeedKey = "jackaroo.moveSpeed"
    private static let activeStakeKey = "jackaroo.activeStake"

    /// Selectable solo-vs-AI wagers (Tokyo Coins). Settled at game end:
    /// the human's team winning pays +stake, losing costs −stake.
    static let stakeTiers: [Int] = [1_000, 5_000, 25_000]

    /// The wager riding on the in-progress solo game, persisted so a
    /// resumed game still settles correctly. 0 means no wager (hot-seat
    /// or a fun game).
    static var activeStake: Int {
        get { UserDefaults.standard.integer(forKey: activeStakeKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeStakeKey) }
    }

    static var moveSpeed: JKMoveSpeed {
        get {
            guard let raw = UserDefaults.standard.string(forKey: moveSpeedKey),
                  let speed = JKMoveSpeed(rawValue: raw) else { return .slow }
            return speed
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: moveSpeedKey) }
    }

    /// The per-cell animation duration for the current speed setting.
    /// Base is 120 ms/cell (JACKAROO_DESIGN §6).
    static var marbleStepDuration: TimeInterval {
        0.12 / moveSpeed.multiplier
    }
}
