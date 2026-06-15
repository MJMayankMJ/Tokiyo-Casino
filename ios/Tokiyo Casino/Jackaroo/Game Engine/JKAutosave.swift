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

    /// Returns a resumable (not-yet-finished) saved game, if one exists.
    static func load() -> JKGameState? {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(JKGameState.self, from: data),
              state.winner == nil else { return nil }
        return state
    }

    static var hasResumableGame: Bool { load() != nil }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
