//
//  JKAutosave.swift
//  Tokiyo Casino — Jackaroo (Phase 6)
//
//  Single-slot crash-recovery autosave. The whole `JKGameState` is
//  Codable (deterministic RNG included), so a JSON round-trip restores
//  an exact, replayable game. Written atomically after every turn and
//  cleared when a game finishes.
//

import Foundation

enum JKAutosave {
    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("jackaroo_autosave.json")
    }

    static func save(_ state: JKGameState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("Jackaroo autosave failed:", error)
            #endif
        }
    }

    /// A saved game older than this is treated as stale (TECH_SPEC §7).
    private static let maxAge: TimeInterval = 24 * 60 * 60

    /// Returns a resumable (not-yet-finished, < 24 h old) saved game.
    static func load() -> JKGameState? {
        guard isFresh,
              let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(JKGameState.self, from: data),
              state.winner == nil else { return nil }
        return state
    }

    /// True only if the save file exists and was written within `maxAge`.
    private static var isFresh: Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modified = attrs[.modificationDate] as? Date else { return false }
        return Date().timeIntervalSince(modified) < maxAge
    }

    static var hasResumableGame: Bool { load() != nil }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
