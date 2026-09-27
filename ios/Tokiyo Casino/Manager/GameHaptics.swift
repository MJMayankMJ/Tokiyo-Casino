//
//  GameHaptics.swift
//  Tokiyo Casino
//
//  Haptics for the tables, used sparingly: only for what *you* do and what
//  happens *to you* — never for other players' moves. Each has its own
//  Core Haptics pattern shaped like the sound it goes with (the check is a
//  double knock, chips are a clink), falling back to the standard
//  generators on devices without Core Haptics.
//

import CoreHaptics
import UIKit

enum GameHaptic {
    /// You put a card down.
    case cardPlay
    /// A card lifts or a choice changes.
    case select
    /// Two knocks on the felt.
    case check
    /// A chip clink — call, bet or raise.
    case chips
    /// A soft slide away.
    case fold
    /// It's your move.
    case yourTurn
    /// You took the trick.
    case trickWon
    /// You won the hand, the round or the game.
    case win
    /// That isn't allowed.
    case invalid
    /// A card thrown up and slammed down: a light release, then a heavy
    /// boom at 0.32 s with a rumble and two aftershocks. Timed to
    /// `TDPMomentEffects.slam`.
    case slam
    /// A build-up of quickening taps, then a burst at 0.42 s with a
    /// shimmer — the reward reveal. Timed to `TDPMomentEffects.burst`.
    case reveal
    /// A tick as the trick gathers, quickening ticks as it flies, and a
    /// coin-drop thump at 0.62 s as it lands in your pile. Timed to
    /// `TDPMomentEffects.claim`.
    case claim
    /// Five ticks climbing as a monster hand's cards score, then a boom and
    /// a shimmer as its name bursts in at 1.3 s. Timed to
    /// `PokerMomentEffects.monster`.
    case scoring
    /// The same five ticks, a tremble that quickens, and a bigger boom at
    /// 1.9 s — the royal flush. Timed to `PokerMomentEffects.monster`.
    case legendary
    /// Two heartbeats while the card is squeezed over, then a boom at
    /// 1.65 s as it lands face up. Timed to `PokerMomentEffects.comeback`.
    case sweat
    /// One hard knock, a fist on the desk, at 0.14 s. Timed to
    /// `PokerMomentEffects.heroCall`.
    case gavel
    /// Two cards smashed down: booms at 0.32 s and 0.68 s. Timed to
    /// `PokerMomentEffects.hammer`.
    case hammer
    /// A punch at 0.13 s as the stamp lands, then chips dropping into your
    /// stack. Timed to `PokerMomentEffects.knockout`.
    case knockout
}

final class GameHaptics {

    static let shared = GameHaptics()

    private static let enabledKey = "tokiyo.haptics.enabled"

    /// Haptics on or off, app-wide (Profile). On unless turned off.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var engine: CHHapticEngine?
    private let supportsCore = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    func prepare() {
        selection.prepare()
        guard supportsCore, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.playsHapticsOnly = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            dprint("GameHaptics: no Core Haptics — \(error)")
        }
    }

    func play(_ haptic: GameHaptic) {
        guard Self.isEnabled else { return }
        if haptic == .select {
            selection.selectionChanged()
            return
        }
        prepare()
        guard let engine, let pattern = try? CHHapticPattern(events: Self.events(for: haptic), parameters: []) else {
            fallback(haptic)
            return
        }
        do {
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback(haptic)
        }
    }

    // MARK: Patterns

    private static func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    private static func hum(_ time: TimeInterval, _ duration: TimeInterval,
                            _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            CHHapticEventParameter(parameterID: .decayTime, value: Float(duration)),
            CHHapticEventParameter(parameterID: .sustained, value: 0)
        ], relativeTime: time, duration: duration)
    }

    private static func events(for haptic: GameHaptic) -> [CHHapticEvent] {
        switch haptic {
        case .cardPlay: return [tap(0, 0.6, 0.75)]
        case .select:   return [tap(0, 0.3, 0.6)]
        case .check:    return [tap(0, 0.55, 0.3), tap(0.115, 0.4, 0.25)]
        case .chips:    return [tap(0, 0.5, 0.9), tap(0.045, 0.28, 0.95)]
        case .fold:     return [hum(0, 0.14, 0.3, 0.1)]
        case .yourTurn: return [tap(0, 0.4, 0.45)]
        case .trickWon: return [tap(0, 0.4, 0.5), tap(0.08, 0.65, 0.6)]
        case .win:      return [tap(0, 0.45, 0.4), tap(0.07, 0.65, 0.5), tap(0.14, 0.95, 0.6),
                                hum(0.14, 0.3, 0.35, 0.2)]
        case .invalid:  return [tap(0, 0.5, 0.1), tap(0.08, 0.35, 0.1)]
        case .slam:     return [tap(0, 0.3, 0.8),
                                tap(0.32, 1.0, 0.35), hum(0.32, 0.34, 0.85, 0.12),
                                tap(0.47, 0.45, 0.25), tap(0.6, 0.25, 0.2)]
        case .reveal:   return [tap(0, 0.16, 0.7), tap(0.1, 0.22, 0.72), tap(0.18, 0.3, 0.75),
                                tap(0.25, 0.38, 0.8), tap(0.31, 0.48, 0.85), tap(0.36, 0.6, 0.9),
                                tap(0.42, 1.0, 0.6), hum(0.42, 0.5, 0.45, 0.9),
                                tap(0.62, 0.3, 0.95), tap(0.76, 0.2, 0.95)]
        case .claim:    return [tap(0, 0.3, 0.6),
                                tap(0.3, 0.18, 0.85), tap(0.4, 0.24, 0.88), tap(0.48, 0.32, 0.9), tap(0.55, 0.42, 0.92),
                                tap(0.62, 0.95, 0.55), hum(0.62, 0.16, 0.4, 0.35),
                                tap(0.74, 0.3, 0.95)]
        case .scoring:  return scoreTicks + [tap(1.3, 1.0, 0.55), hum(1.3, 0.45, 0.5, 0.85),
                                             tap(1.5, 0.3, 0.95), tap(1.64, 0.2, 0.95)]
        case .legendary: return scoreTicks + [tap(1.3, 0.3, 0.7), tap(1.46, 0.38, 0.72), tap(1.59, 0.46, 0.75),
                                              tap(1.69, 0.55, 0.8), tap(1.77, 0.65, 0.85), tap(1.84, 0.75, 0.9),
                                              tap(1.9, 1.0, 0.5), hum(1.9, 0.7, 0.6, 0.8),
                                              tap(2.15, 0.35, 0.95), tap(2.32, 0.25, 0.95), tap(2.5, 0.18, 0.95)]
        case .sweat:    return [tap(0.55, 0.7, 0.15), tap(0.67, 0.42, 0.12),
                                tap(0.95, 0.85, 0.15), tap(1.07, 0.5, 0.12),
                                tap(1.65, 1.0, 0.55), hum(1.65, 0.4, 0.5, 0.8), tap(1.85, 0.28, 0.95)]
        case .gavel:    return [tap(0.14, 1.0, 0.45), hum(0.14, 0.22, 0.8, 0.15), tap(0.3, 0.4, 0.3)]
        case .hammer:   return [tap(0, 0.3, 0.8),
                                tap(0.32, 1.0, 0.35), hum(0.32, 0.3, 0.8, 0.12), tap(0.36, 0.3, 0.8),
                                tap(0.68, 1.0, 0.3), hum(0.68, 0.36, 0.9, 0.1),
                                tap(0.83, 0.45, 0.25), tap(0.96, 0.25, 0.2)]
        case .knockout: return [tap(0.13, 1.0, 0.5), hum(0.13, 0.22, 0.75, 0.2),
                                tap(0.92, 0.3, 0.9), tap(1.0, 0.34, 0.9), tap(1.08, 0.38, 0.92), tap(1.16, 0.5, 0.95)]
        }
    }

    /// A monster hand's five cards scoring, 0.16 s apart from 0.45 s.
    private static var scoreTicks: [CHHapticEvent] {
        (0..<5).map { tap(0.45 + Double($0) * 0.16, 0.3 + Float($0) * 0.09, 0.85) }
    }

    private func fallback(_ haptic: GameHaptic) {
        switch haptic {
        case .select:
            selection.selectionChanged()
        case .win:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .invalid:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .check, .fold, .yourTurn:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .cardPlay, .chips, .trickWon:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .slam:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        case .reveal:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        case .claim:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        case .scoring, .legendary:
            DispatchQueue.main.asyncAfter(deadline: .now() + (haptic == .legendary ? 1.9 : 1.3)) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        case .sweat, .gavel, .hammer, .knockout:
            let hits: [TimeInterval]
            switch haptic {
            case .sweat:  hits = [1.65]
            case .gavel:  hits = [0.14]
            case .hammer: hits = [0.32, 0.68]
            default:      hits = [0.13]
            }
            for hit in hits {
                DispatchQueue.main.asyncAfter(deadline: .now() + hit) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
        }
    }
}
