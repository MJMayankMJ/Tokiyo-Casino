//
//  BackgroundSoundManager.swift
//  Tokiyo Casino
//
//  Created by Hari's Mac on 18.08.2025.
//

import Foundation
import SwiftUI
import AVFoundation


private let kMutedKey = "isMuted"

final class BackgroundSoundManager {
    static let shared = BackgroundSoundManager()
    private var player: AVAudioPlayer?

    private init() {
        setupAudioSession()
    }

    // MARK: - Audio Session
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session:", error)
        }
    }

    // MARK: - Setup Player
    func setupPlayer(soundName: String, soundType: SoundType) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: soundType.rawValue) else {
            print("Sound file missing or mis-named: \(soundName).\(soundType.rawValue)")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.volume = Self.isMuted ? 0 : 0.20
        } catch {
            print("Error loading sound:", error)
        }
    }

    // MARK: - Playback
    func play(loop: Bool = true) {
        guard !Self.isMuted else { return }
        player?.numberOfLoops = loop ? -1 : 0 // -1 = infinite loop
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
        player?.stop()
    }

    func volume(_ level: Float) {
        player?.volume = Self.isMuted ? 0 : level
    }

    // MARK: - Global Mute API
    static func setMuted(_ muted: Bool) {
        UserDefaults.standard.set(muted, forKey: kMutedKey)
        NotificationCenter.default.post(name: .init("SoundSettingChanged"), object: nil)
    }

    static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: kMutedKey)
    }
}
