//
//  SoundManager.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 3/19/25.
//

import Foundation
import AVFoundation

private let kMutedKey = "isMuted"

enum SoundType: String {
    case mp3, wav, m4a
}

struct SoundManager {
    private var player: AVAudioPlayer?

    // MARK: – Setup
    mutating func setupPlayer(soundName: String, soundType: SoundType) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: soundType.rawValue) else {
            #if DEBUG
            print("Sound file missing or mis-named: \(soundName).\(soundType.rawValue)")
            #endif
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.volume = SoundManager.isMuted ? 0 : 1
        } catch {
            #if DEBUG
            print("Error loading sound \(soundName):", error)
            #endif
        }
    }

    // MARK: – Playback
    func play(_ numberOfLoops: Int = 0) {
        guard !SoundManager.isMuted else { return }
        player?.numberOfLoops = numberOfLoops
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func stop() {
        player?.stop()
    }
    
    func volume(_ level: Float) {
        //respect mute even if someone manually tweaks volume
        player?.volume = SoundManager.isMuted ? 0 : level
    }

    // MARK: – Global Mute API
    // Toggle mute on / off
    static func setMuted(_ muted: Bool) {
        UserDefaults.standard.set(muted, forKey: kMutedKey)
        NotificationCenter.default.post(name: .init("SoundSettingChanged"), object: nil)
    }
    
    // Read current mute state
    static var isMuted: Bool {
        UserDefaults.standard.bool(forKey: kMutedKey)
    }
    
}
