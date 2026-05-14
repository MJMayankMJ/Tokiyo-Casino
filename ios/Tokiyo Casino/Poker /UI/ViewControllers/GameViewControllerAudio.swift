//
//  GameViewControllerAudio.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension GameViewController {
    
    // MARK: - BGM Setup
    func setupBGM() {
        bgmManager.setupPlayer(soundName: "casino_bgm", soundType: .mp3)
        bgmManager.volume(0.3)
    }
    
    func playBGM() {
        // Loop indefinitely (-1 means infinite loop)
        bgmManager.play(-1)
    }
    
    func pauseBGM() {
        bgmManager.pause()
    }
    
    func getMuteButtonImage() -> UIImage? {
        let imageName = SoundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        return UIImage(systemName: imageName)
    }
    
    @objc func soundSettingChanged() {
        // Top-right chip is now the hand-details icon, not an audio toggle —
        // keep the legacy hidden mute button in sync for any callers that
        // still consult it.
        muteButton.setImage(getMuteButtonImage(), for: .normal)
        topInfoBar?.menuButton.tintColor = PokerTheme.ink

        // Handle BGM based on mute state
        if SoundManager.isMuted {
            pauseBGM()
        } else {
            playBGM()
        }
    }
    
    // MARK: - Haptics
    func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    func addSuccessFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    func addErrorFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}
