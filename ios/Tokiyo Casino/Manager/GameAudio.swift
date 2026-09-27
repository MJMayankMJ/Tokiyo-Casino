//
//  GameAudio.swift
//  Tokiyo Casino
//
//  The table's sound, shared by every game: real foley recordings of cards,
//  chips and a knock on the felt (Kenney's Casino and Impact packs — CC0,
//  trimmed and level-matched). Only what a real table makes — no chimes;
//  your turn and your wins are felt as haptics instead.
//
//  Built on AVAudioEngine with every buffer preloaded: a card has to click
//  the instant it lands, which a fresh AVAudioPlayer per sound can't do.
//  Respects the app-wide mute and the ringer switch (`.ambient`), and plays
//  under the player's own music.
//

import AVFoundation

enum GameSound: String, CaseIterable {
    // Cards
    case deal, play, flip, sweep, fan, shuffle
    // Chips and table
    case bet, raise, allIn = "allin", pot, check
    /// A card thrown down hard: a deep thud under the card's snap.
    case slam

    /// Mix level, set by ear against the others.
    fileprivate var level: Float {
        switch self {
        case .deal:     return 0.55
        case .play:     return 0.95
        case .flip:     return 0.6
        case .sweep:    return 0.5
        case .fan:      return 0.5
        case .shuffle:  return 0.45
        case .bet:      return 0.8
        case .raise:    return 0.85
        case .allIn:    return 0.9
        case .pot:      return 0.8
        case .check:    return 1.0
        case .slam:     return 1.0
        }
    }

    /// Resource names: `tk_play_1`, `tk_play_2`… or a single `tk_turn`.
    fileprivate var resources: [String] {
        let base = "tk_" + rawValue
        let numbered: [String] = (1...8).map { (index: Int) -> String in "\(base)_\(index)" }
            .filter { (name: String) -> Bool in Bundle.main.url(forResource: name, withExtension: "caf") != nil }
        return numbered.isEmpty ? [base] : numbered
    }
}

final class GameAudio {

    static let shared = GameAudio()

    /// Sound on or off, app-wide. The same switch Poker's menu has always used.
    static var isEnabled: Bool {
        get { !SoundManager.isMuted }
        set { SoundManager.setMuted(!newValue) }
    }

    private let engine = AVAudioEngine()
    private var voices: [(node: AVAudioPlayerNode, pitch: AVAudioUnitVarispeed)] = []
    private var nextVoice = 0
    private var buffers: [GameSound: [AVAudioPCMBuffer]] = [:]
    private var lastVariant: [GameSound: Int] = [:]
    private var lastPlayed: [GameSound: CFTimeInterval] = [:]
    private var prepared = false

    private init() {}

    /// Loads every sound and starts the engine. Cheap after the first call;
    /// call it as a table appears so the first card isn't late.
    func prepare() {
        guard !prepared else { startIfNeeded(); return }
        prepared = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        for sound in GameSound.allCases {
            buffers[sound] = sound.resources.compactMap { Self.load($0, as: format) }
        }
        for _ in 0..<10 {
            let node = AVAudioPlayerNode()
            let pitch = AVAudioUnitVarispeed()
            engine.attach(node)
            engine.attach(pitch)
            engine.connect(node, to: pitch, format: format)
            engine.connect(pitch, to: engine.mainMixerNode, format: format)
            voices.append((node, pitch))
        }
        engine.prepare()
        NotificationCenter.default.addObserver(self, selector: #selector(restart),
                                               name: .AVAudioEngineConfigurationChange, object: engine)
        NotificationCenter.default.addObserver(self, selector: #selector(restart),
                                               name: AVAudioSession.interruptionNotification, object: nil)
        startIfNeeded()
    }

    /// Plays `sound` now or after `delay`. `volume` scales the sound's own
    /// level — e.g. softer for the other players' cards than for yours.
    /// `pitch` sets the playback rate (1 is as recorded) for a run that
    /// should climb; otherwise every play varies a little.
    func play(_ sound: GameSound, volume: Float = 1, pitch: Float? = nil, delay: TimeInterval = 0) {
        guard Self.isEnabled else { return }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.play(sound, volume: volume, pitch: pitch)
            }
            return
        }
        prepare()
        // Two of the same sound inside 30 ms is one sound, not a stutter.
        let now = CACurrentMediaTime()
        if let last = lastPlayed[sound], now - last < 0.03 { return }
        lastPlayed[sound] = now

        guard let options = buffers[sound], !options.isEmpty, startIfNeeded() else { return }
        var pick = Int.random(in: 0..<options.count)
        if options.count > 1, pick == lastVariant[sound] { pick = (pick + 1) % options.count }
        lastVariant[sound] = pick

        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.node.stop()
        voice.node.volume = sound.level * volume
        // A real table never makes the same sound twice.
        voice.pitch.rate = pitch ?? Float.random(in: 0.96...1.04)
        voice.node.scheduleBuffer(options[pick], at: nil, options: [], completionHandler: nil)
        voice.node.play()
    }

    /// How many recordings `sound` has loaded — 0 means a missing file.
    func loadedVariants(of sound: GameSound) -> Int {
        prepare()
        return buffers[sound]?.count ?? 0
    }

    /// A short run of the same sound — a hand being dealt, a flop landing.
    func play(_ sound: GameSound, times: Int, every gap: TimeInterval, volume: Float = 1, delay: TimeInterval = 0) {
        for i in 0..<max(0, times) {
            play(sound, volume: volume, delay: delay + Double(i) * gap)
        }
    }

    @discardableResult
    private func startIfNeeded() -> Bool {
        guard !engine.isRunning else { return true }
        do {
            try engine.start()
            return true
        } catch {
            dprint("GameAudio: engine failed to start — \(error)")
            return false
        }
    }

    @objc private func restart() {
        DispatchQueue.main.async { [weak self] in self?.startIfNeeded() }
    }

    private static func load(_ name: String, as format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
              let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        return file.processingFormat == format ? buffer : nil
    }
}
