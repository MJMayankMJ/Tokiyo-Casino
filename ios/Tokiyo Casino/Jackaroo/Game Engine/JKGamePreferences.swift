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
