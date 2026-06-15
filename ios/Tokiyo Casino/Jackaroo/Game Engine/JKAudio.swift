//
//  JKAudio.swift
//  Tokiyo Casino — Jackaroo (Phase 6)
//
//  One-shot sound effects (original CC0 audio — see AUDIO_CREDITS.md).
//  Every play routes through SoundManager, so the app-wide mute toggle
//  is honoured.
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
        selectSfx.setupPlayer(soundName: "sfx_ui_tap",      soundType: .m4a)
        moveSfx.setupPlayer(soundName:   "sfx_marble_move", soundType: .m4a)
        captureSfx.setupPlayer(soundName: "sfx_capture",    soundType: .m4a)
        winSfx.setupPlayer(soundName:    "sfx_win",         soundType: .m4a)
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
