//
//  JKAudio.swift
//  Tokiyo Casino — Jackaroo (Phase 6)
//
//  One-shot sound effects mapped to the existing shared assets per
//  JACKAROO_DESIGN.md §6 (no new audio in V1). Every play routes
//  through SoundManager, so the app-wide mute toggle is honoured.
//

import Foundation

final class JKAudio {
    static let shared = JKAudio()

    enum Effect { case select, move, capture, win }

    private var selectSfx  = SoundManager()
    private var moveSfx     = SoundManager()
    private var captureSfx  = SoundManager()
    private var winSfx       = SoundManager()
    private var loaded = false

    private init() {}

    /// Decode the four players once, lazily. Safe to call repeatedly.
    func preload() {
        guard !loaded else { return }
        loaded = true
        selectSfx.setupPlayer(soundName: "button_tap",      soundType: .mp3)
        moveSfx.setupPlayer(soundName:   "coin_flip_sound", soundType: .mp3)
        captureSfx.setupPlayer(soundName: "success_press",  soundType: .mp3)
        winSfx.setupPlayer(soundName:    "grand_win",       soundType: .mp3)
    }

    func play(_ effect: Effect) {
        switch effect {
        case .select:  selectSfx.play()
        case .move:    moveSfx.play()
        case .capture: captureSfx.play()
        case .win:     winSfx.play()
        }
    }
}
