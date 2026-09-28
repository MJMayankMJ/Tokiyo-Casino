//
//  PokerMomentEffects.swift
//  Poker
//
//  How the poker moments (`PokerMoments`) look — each after a game that
//  does that beat best:
//
//  • Monster hand — Balatro's scoring: your five cards gather in a row over
//    the board and score one by one, each popping to a chip click a little
//    higher than the last, then the hand's name bursts in with rays. A
//    royal flush adds Clash Royale's legendary chest: the row trembles
//    harder and harder before a bigger flash, a foil sheen and confetti.
//  • Runner-runner / river miracle — poker TV's all-in odds: a chip shows
//    what you had to win, the card that did it is squeezed over like a
//    baccarat card through two heartbeats, and the odds flip to WIN.
//  • Hero call — Ace Attorney's "OBJECTION!": a jagged bubble slams in, the
//    table jolts, and the hand you called down flinches and dims.
//  • The Hammer — Marvel Snap's slam, the one 5-3-2's first cut uses: your
//    7 and 2 thrown down onto the felt one after the other.
//  • Knockout — Street Fighter's K.O.: a stamp slams onto the player you
//    knocked out, the lights go out on their seat, and their chips arc into
//    your stack like a bounty.
//
//  Effects run on stand-ins ("ghosts") in an overlay above the table while
//  the real cards hide under them, so nothing on the table changes; if the
//  table moves on first (a new hand or a new game), `cancel()` puts it
//  back at once. Reduce Motion keeps the light, the callouts and the
//  haptics, fades what would fly, flip or pop, and drops the shake and the
//  particles.
//

import UIKit

final class PokerMomentEffects {

    private let kit: MomentKit
    private weak var table: PokerTableView?
    /// Bumped by `cancel()`: anything scheduled before it is dropped.
    private var generation = 0
    /// What a cancel has to put back: cards hidden under stand-ins, cards
    /// dimmed, and the dimming sheets.
    private var hidden: [UIView] = []
    private var dimmed: [(view: UIView, alpha: CGFloat)] = []
    private var scrims: [UIView] = []

    /// `table` shakes; `overlay` sits above everything and holds the effects.
    init(table: PokerTableView, overlay: UIView) {
        self.table = table
        kit = MomentKit(stage: table, overlay: overlay,
                        style: .init(gold: PokerTheme.momentGold, hairline: PokerTheme.borderStrong,
                                     typeScale: DeviceLayout.pick(1.0, pad: 1.3)))
    }

    /// A small stage can reuse the royal's score, tremble, and burst without
    /// manufacturing a game table or changing any hand state.
    init(previewStage: UIView, overlay: UIView) {
        kit = MomentKit(stage: previewStage, overlay: overlay,
                        style: .init(gold: PokerTheme.momentGold, hairline: PokerTheme.borderStrong,
                                     typeScale: 1))
    }

    func previewRoyalFlush(_ sources: [CardView], completion: @escaping () -> Void) {
        kit.run { [weak self] finish in
            guard let self, let overlay = self.kit.overlay, sources.count == 5 else { finish(); completion(); return }
            let ghosts = sources.compactMap { source in source.card.flatMap { self.ghost(of: source, card: $0) } }
            guard ghosts.count == 5 else {
                ghosts.forEach { $0.removeFromSuperview() }
                finish()
                completion()
                return
            }
            self.hide(sources)
            let width: CGFloat = 52
            let gap: CGFloat = 7
            let rowWidth = width * 5 + gap * 4
            let row = CGPoint(x: overlay.bounds.midX, y: overlay.bounds.maxY - 98)
            let poses = ghosts.enumerated().map { index, card in
                (center: CGPoint(x: row.x + CGFloat(index - 2) * (width + gap), y: row.y),
                 transform: CGAffineTransform(scaleX: width / card.bounds.width, y: width / card.bounds.width))
            }
            GameHaptics.shared.play(.legendary)
            GameAudio.shared.play(.sweep, volume: 0.6)
            for (index, ghost) in ghosts.enumerated() {
                UIView.animate(withDuration: 0.14, delay: Double(index) * 0.02, options: [.curveEaseOut]) {
                    ghost.center = poses[index].center
                    ghost.transform = poses[index].transform
                }
                self.after(0.12 + Double(index) * 0.07) {
                    self.score(ghost, pose: poses[index].transform, index: index)
                }
            }
            let glow = self.tremble(ghosts, around: row, width: rowWidth, from: 0.43, until: 0.58)
            self.after(0.58) {
                self.burst(.royalFlush, ghosts: ghosts, poses: poses.map(\.transform), at: row,
                           width: rowWidth, top: row.y - 38, hold: 0.38, compact: true)
                if let glow {
                    self.kit.animate(glow, key: "opacity", from: 0.75, to: 0, duration: 0.35, timing: .easeIn) {
                        glow.removeFromSuperlayer()
                    }
                }
            }
            self.after(1.0) {
                ghosts.forEach { $0.removeFromSuperview() }
                self.show(sources)
                finish()
                completion()
            }
        }
    }

    /// Plays a won hand's `moments` one after another for the player in
    /// `seat`; `completion` runs once the last has finished.
    func play(_ moments: [PokerMoment], hand: PokerHandRecord, seat: Int,
              completion: @escaping () -> Void) {
        for moment in moments {
            kit.run { [weak self] finish in
                guard let self else { finish(); return }
                switch moment {
                case .royalFlush, .straightFlush, .fourOfAKind:
                    self.monster(moment, hand: hand, seat: seat, finish: finish)
                case .runnerRunner(let odds):
                    self.comeback(odds: odds, runnerRunner: true, hand: hand, seat: seat, finish: finish)
                case .riverMiracle(let odds):
                    self.comeback(odds: odds, runnerRunner: false, hand: hand, seat: seat, finish: finish)
                case .heroCall:
                    self.heroCall(hand: hand, seat: seat, finish: finish)
                case .hammer:
                    self.hammer(hand: hand, seat: seat, finish: finish)
                case .knockout:
                    self.knockout(hand: hand, seat: seat, finish: finish)
                }
            }
        }
        kit.run { finish in
            completion()
            finish()
        }
    }

    /// Stops whatever is playing or waiting, at once: the real cards come
    /// back, everything drawn goes, and the pending `completion` is dropped.
    /// For when the table moves on under a moment — a new hand or a new
    /// game.
    func cancel() {
        generation += 1
        kit.cancelAll()
        show(hidden)
        for (view, alpha) in dimmed { view.alpha = alpha }
        dimmed.removeAll()
        scrims.forEach { $0.removeFromSuperview() }
        scrims.removeAll()
        guard let overlay = kit.overlay else { return }
        overlay.subviews.forEach { $0.removeFromSuperview() }
        overlay.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    // MARK: Monster hand

    private func monster(_ moment: PokerMoment, hand: PokerHandRecord, seat: Int,
                         finish: @escaping () -> Void) {
        guard let table, let overlay = kit.overlay, hand.board.count >= 3,
              let middle = table.communityCardViews.dropFirst(2).first else { finish(); return }
        let cards = ordered(HandEvaluator.evaluateBestHand(from: hand.hole + hand.board))
        let sources = cards.compactMap { slot(of: $0, in: hand, seat: seat) }
        let ghosts = zip(cards, sources).compactMap { ghost(of: $1, card: $0) }
        guard sources.count == cards.count, ghosts.count == cards.count else {
            ghosts.forEach { $0.removeFromSuperview() }
            finish()
            return
        }
        hide(sources)
        let royal = moment == .royalFlush
        let homes = ghosts.map { (center: $0.center, transform: $0.transform) }

        // The row they gather into, over the board.
        let unit = overlay.convert(middle.frame, from: table)
        let gap: CGFloat = 8
        let grow = min(1.55, (overlay.bounds.width - 48) / (unit.width * 5 + gap * 4))
        let width = unit.width * grow
        let rowWidth = width * 5 + gap * 4
        let row = CGPoint(x: unit.midX, y: unit.midY)
        let slots = ghosts.enumerated().map { index, ghost in
            (center: CGPoint(x: row.x + (CGFloat(index) - 2) * (width + gap), y: row.y),
             transform: CGAffineTransform(scaleX: width / ghost.bounds.width, y: width / ghost.bounds.width))
        }
        // With Reduce Motion the cards score where they lie.
        let poses = kit.reduceMotion ? homes : slots

        let scrim = self.scrim(alpha: kit.isDark ? 0.55 : 0.4)
        GameHaptics.shared.play(royal ? .legendary : .scoring)
        GameAudio.shared.play(.sweep, volume: 0.7)

        // 1. Your hand gathers in a row over the board.
        for (index, ghost) in ghosts.enumerated() {
            UIView.animate(withDuration: 0.34, delay: Double(index) * 0.03, usingSpringWithDamping: 0.82,
                           initialSpringVelocity: 0.3, options: []) {
                ghost.center = poses[index].center
                ghost.transform = poses[index].transform
            }
        }
        // 2. They score one by one, each click a little higher.
        for index in ghosts.indices {
            after(0.45 + Double(index) * 0.16) {
                self.score(ghosts[index], pose: poses[index].transform, index: index)
            }
        }
        // 3. A royal trembles harder and harder with light leaking out.
        let reveal: TimeInterval = royal ? 1.9 : 1.3
        let glow = royal && !kit.reduceMotion
            ? tremble(ghosts, around: row, width: rowWidth, from: 1.25, until: reveal) : nil
        // 4. The name bursts in.
        let hold: TimeInterval = royal ? 1.6 : moment == .straightFlush ? 1.4 : 1.2
        after(reveal) {
            self.burst(moment, ghosts: ghosts, poses: poses.map(\.transform), at: row, width: rowWidth,
                       top: row.y - unit.height * grow / 2, hold: hold)
            if let glow {
                self.kit.animate(glow, key: "opacity", from: 0.75, to: 0, duration: 0.5, timing: .easeIn) {
                    glow.removeFromSuperlayer()
                }
            }
        }
        // 5. Back where they were.
        after(reveal + hold) {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
                for (ghost, home) in zip(ghosts, homes) {
                    ghost.center = home.center
                    ghost.transform = home.transform
                }
            }
            self.clear(scrim)
        }
        after(reveal + hold + 0.34) {
            ghosts.forEach { $0.removeFromSuperview() }
            self.show(sources)
            finish()
        }
    }

    /// One card scoring: a pop and a wobble, a flash of light, a click.
    private func score(_ ghost: CardView, pose: CGAffineTransform, index: Int) {
        GameAudio.shared.play(.bet, volume: 0.75, pitch: 0.92 + Float(index) * 0.07)
        kit.glowPulse(at: ghost.center, size: ghost.frame.width * 2.6)
        guard !kit.reduceMotion else { return }
        let tilt: CGFloat = index.isMultiple(of: 2) ? 0.1 : -0.1
        let pop = CAKeyframeAnimation(keyPath: "transform")
        pop.values = [pose, pose.scaledBy(x: 1.3, y: 1.3).rotated(by: tilt),
                      pose.scaledBy(x: 0.96, y: 0.96).rotated(by: -tilt / 2), pose]
            .map { NSValue(caTransform3D: CATransform3DMakeAffineTransform($0)) }
        pop.keyTimes = [0, 0.3, 0.65, 1]
        pop.duration = 0.32
        ghost.layer.add(pop, forKey: "score")
        var bits: [(MomentKit.Bit, UIColor, CGFloat)] = Array(repeating: (.spark, kit.gold, 10), count: 5)
        bits += Array(repeating: (.dot, kit.gold, 5), count: 3)
        kit.throwBits(bits.shuffled(), from: ghost.center, across: ghost.frame.width * 0.5,
                      toward: -.pi / 2, spread: 1.2, distance: 22...48, fall: 12,
                      duration: 0.35...0.55, below: ghost.layer)
    }

    /// The row shakes harder and harder while light leaks from behind it.
    /// Returns the light, to fade once it bursts.
    private func tremble(_ ghosts: [CardView], around point: CGPoint, width: CGFloat,
                         from start: TimeInterval, until end: TimeInterval) -> CALayer? {
        guard let overlay = kit.overlay else { return nil }
        let glow = kit.glowLayer(diameter: width * 1.3)
        glow.position = point
        glow.opacity = 0
        overlay.layer.insertSublayer(glow, at: 0)
        after(start) {
            self.kit.animate(glow, key: "opacity", from: 0, to: 0.75, duration: end - start, timing: .easeIn)
            for (index, ghost) in ghosts.enumerated() {
                let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
                let shake = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                shake.values = [0, 0.02, -0.03, 0.04, -0.05, 0.06, -0.07, 0.08, 0].map { $0 * sign }
                shake.duration = end - start
                shake.isAdditive = true
                ghost.layer.add(shake, forKey: "tremble")
            }
        }
        return glow
    }

    /// The hand's name bursts in over the row.
    private func burst(_ moment: PokerMoment, ghosts: [CardView], poses: [CGAffineTransform],
                       at point: CGPoint, width: CGFloat, top: CGFloat, hold: TimeInterval, compact: Bool = false) {
        let royal = moment == .royalFlush
        GameAudio.shared.play(.slam, volume: 0.7)
        GameAudio.shared.play(.pot, delay: 0.05)
        kit.rays(at: point, diameter: width * (royal ? 1.9 : 1.6), hold: hold - 0.2, below: ghosts.first?.layer)
        if !kit.reduceMotion {
            kit.screenFlash(peak: compact ? 0.20 : (kit.isDark ? 0.42 : 0.58), duration: royal ? 0.45 : 0.3)
            kit.shockwave(at: point, from: width * 0.45, to: width * 1.35, lineWidth: 6, duration: 0.6)
            kit.sparks(at: point, width: width, behind: ghosts.first)
            for (ghost, pose) in zip(ghosts, poses) {
                let bump = CAKeyframeAnimation(keyPath: "transform")
                bump.values = [pose, pose.scaledBy(x: 1.12, y: 1.12), pose]
                    .map { NSValue(caTransform3D: CATransform3DMakeAffineTransform($0)) }
                bump.duration = 0.4
                ghost.layer.add(bump, forKey: "bump")
            }
            if royal, let traits = kit.overlay?.traitCollection {
                let colors = [PokerTheme.momentGold, PokerTheme.coral, PokerTheme.Chip.blue,
                              PokerTheme.forest, PokerTheme.Chip.purple, .white]
                kit.confetti(colors: colors.map { $0.resolvedColor(with: traits) }, count: compact ? 22 : 44, duration: compact ? 0.4...0.7 : 1.8...2.6)
            }
        }
        if moment != .fourOfAKind, !kit.reduceMotion {
            for (index, ghost) in ghosts.enumerated() {
                after(Double(index) * 0.06) {
                    self.kit.sheen(across: ghost, cornerRadius: max(4, ghost.bounds.width * 0.18), duration: 0.55)
                }
            }
        }
        kit.shakeStage(amplitude: royal ? 10 : 6, duration: royal ? 0.5 : 0.4)
        let (title, odds) = Self.name(of: moment)
        kit.showCallout(title, subtitle: compact ? nil : odds, at: CGPoint(x: point.x, y: top - 38),
                        size: royal ? 24 : 21, hold: hold - 0.25)
    }

    /// A monster hand's name and how rarely any seven cards make it — the
    /// hand's odds, not the odds of winning a pot with it.
    static func name(of moment: PokerMoment) -> (title: String, odds: String?) {
        switch moment {
        case .royalFlush:    return ("ROYAL FLUSH", "1 IN 30,940 SEVEN-CARD HANDS")
        case .straightFlush: return ("STRAIGHT FLUSH", "1 IN 3,590 SEVEN-CARD HANDS")
        case .fourOfAKind:   return ("FOUR OF A KIND", "1 IN 595 SEVEN-CARD HANDS")
        default:             return ("", nil)
        }
    }

    // MARK: Runner-runner / river miracle

    private func comeback(odds: Double, runnerRunner: Bool, hand: PokerHandRecord, seat: Int,
                          finish: @escaping () -> Void) {
        guard let table, let overlay = kit.overlay, hand.board.count == 5,
              table.communityCardViews.count == 5 else { finish(); return }
        let turned = runnerRunner ? [3, 4] : [4]
        let sources = turned.map { table.communityCardViews[$0] }
        let ghosts = zip(turned, sources).compactMap { ghost(of: $1, card: hand.board[$0]) }
        guard ghosts.count == sources.count, let river = ghosts.last else {
            ghosts.forEach { $0.removeFromSuperview() }
            finish()
            return
        }
        hide(sources)
        let still = kit.reduceMotion
        let homes = ghosts.map { (center: $0.center, transform: $0.transform) }
        let board = overlay.convert(table.communityCardViews[2].center, from: table)
        let scrim = self.scrim(alpha: kit.isDark ? 0.5 : 0.36)
        GameHaptics.shared.play(.sweat)

        // The odds you had, poker-TV style, over your cards.
        let chip = OddsChip(odds: odds, typeScale: kit.style.typeScale)
        chip.center = oddsSpot(seat: seat, below: board)
        overlay.addSubview(chip)
        chip.popIn(still: still)

        // 1. The card that won it turns face down again and lifts.
        after(0.1) {
            GameAudio.shared.play(.flip, volume: 0.6)
            ghosts.forEach { self.turn($0, faceUp: false, duration: 0.2) }
        }
        after(0.3) {
            guard !still else { return }
            GameAudio.shared.play(.deal, volume: 0.6)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.72,
                           initialSpringVelocity: 0.4, options: []) {
                for (ghost, home) in zip(ghosts, homes) {
                    ghost.center.y = home.center.y - 18
                    ghost.transform = home.transform.scaledBy(x: 1.6, y: 1.6)
                }
            }
        }
        // 2. Two heartbeats.
        for beat in [0.55, 0.95] {
            after(beat) { self.heartbeat(ghosts + [chip]) }
        }
        // 3. Squeezed over: the turn first if it took both.
        if runnerRunner, let turnCard = ghosts.first {
            after(0.95) {
                GameAudio.shared.play(.flip, volume: 0.7)
                self.turn(turnCard, faceUp: true, duration: 0.3)
            }
        }
        after(1.2) {
            GameAudio.shared.play(.flip)
            self.turn(river, faceUp: true, duration: 0.45)
        }
        // 4. It lands: the odds flip to WIN.
        after(1.65) {
            let spot = river.center
            let w = river.frame.width
            GameAudio.shared.play(.sweep, volume: 0.9)
            GameAudio.shared.play(.pot, volume: 0.8, delay: 0.05)
            self.kit.rays(at: spot, diameter: w * 5, hold: 0.8, below: ghosts.first?.layer)
            if !still {
                self.kit.screenFlash(peak: self.kit.isDark ? 0.42 : 0.58, duration: 0.3)
                self.kit.shockwave(at: spot, from: w * 1.1, to: w * 3, lineWidth: 5, duration: 0.55)
                self.kit.sparks(at: spot, width: w, behind: ghosts.first)
            }
            self.kit.shakeStage(amplitude: 6, duration: 0.35)
            chip.win(gold: self.kit.gold, still: still)
            let top = ghosts.map(\.frame.minY).min() ?? spot.y
            self.kit.showCallout(runnerRunner ? "RUNNER-RUNNER" : "RIVER MIRACLE",
                                 subtitle: "\(OddsChip.percent(odds)) ON THE \(runnerRunner ? "FLOP" : "TURN")",
                                 at: CGPoint(x: board.x, y: top - 34), size: 21, hold: 0.8)
        }
        // 5. Back into the board.
        after(2.55) {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
                for (ghost, home) in zip(ghosts, homes) {
                    ghost.center = home.center
                    ghost.transform = home.transform
                }
                chip.alpha = 0
            }
            self.clear(scrim)
        }
        after(2.89) {
            ghosts.forEach { $0.removeFromSuperview() }
            chip.removeFromSuperview()
            self.show(sources)
            finish()
        }
    }

    /// Just above your cards — where poker TV puts a player's odds.
    private func oddsSpot(seat: Int, below board: CGPoint) -> CGPoint {
        guard let overlay = kit.overlay,
              let cards = table?.playerView(for: seat)?.holeCardViews.filter({ $0.bounds.width > 0 }),
              let first = cards.first, let parent = first.superview else {
            return CGPoint(x: board.x, y: board.y + 90)
        }
        let area = cards.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        let frame = overlay.convert(area, from: parent)
        return CGPoint(x: frame.midX, y: frame.minY - 26)
    }

    private func heartbeat(_ views: [UIView]) {
        for view in views {
            kit.glowPulse(at: view.center, size: view.frame.width * 2.8)
            guard !kit.reduceMotion else { continue }
            let thump = CAKeyframeAnimation(keyPath: "transform.scale")
            thump.values = [0, 0.08, 0, 0.045, 0]
            thump.keyTimes = [0, 0.14, 0.38, 0.52, 1]
            thump.duration = 0.36
            thump.isAdditive = true
            view.layer.add(thump, forKey: "heartbeat")
        }
    }

    private func turn(_ ghost: CardView, faceUp: Bool, duration: TimeInterval) {
        guard let card = ghost.card else { return }
        let flip: UIView.AnimationOptions = kit.reduceMotion ? .transitionCrossDissolve
            : faceUp ? .transitionFlipFromBottom : .transitionFlipFromLeft
        UIView.transition(with: ghost, duration: duration, options: [flip, .curveEaseIn]) {
            ghost.setCard(card, faceUp: faceUp)
        }
    }

    // MARK: Hero call

    private func heroCall(hand: PokerHandRecord, seat: Int, finish: @escaping () -> Void) {
        guard let table, let overlay = kit.overlay, table.communityCardViews.count > 2 else { finish(); return }
        let caught = hand.shownDown.flatMap { table.playerView(for: $0.seat)?.holeCardViews ?? [] }
        let mine = table.playerView(for: seat)?.holeCardViews ?? []
        let still = kit.reduceMotion
        let board = overlay.convert(table.communityCardViews[2].center, from: table)

        // "OBJECTION!" — a jagged bubble slams in. A bluff only if the hand
        // you beat had nothing; otherwise your call simply held.
        let bubble = JaggedBubble(title: "HERO CALL!",
                                  subtitle: PokerMoments.caughtBluff(hand) ? "YOU CAUGHT THE BLUFF" : "YOUR CALL HELD UP",
                                  fill: kit.gold, typeScale: kit.style.typeScale)
        bubble.center = CGPoint(x: board.x, y: board.y - 6)
        overlay.addSubview(bubble)
        let rest = CGAffineTransform(rotationAngle: -0.07)
        bubble.alpha = 0
        bubble.transform = still ? rest : rest.scaledBy(x: 2.6, y: 2.6)
        GameHaptics.shared.play(.gavel)
        UIView.animate(withDuration: 0.14, delay: 0, options: [.curveEaseIn]) {
            bubble.alpha = 1
            bubble.transform = rest
        }
        after(0.14) {
            GameAudio.shared.play(.slam)
            if !still {
                self.kit.squash(bubble, rest: rest)
                self.kit.screenFlash(peak: 0.5, duration: 0.25)
                self.kit.shockwave(at: bubble.center, from: bubble.bounds.width * 0.6,
                                   to: bubble.bounds.width * 1.3, lineWidth: 6, duration: 0.5)
            }
            self.kit.shakeStage(amplitude: 12, duration: 0.45)
        }

        // The hand you called down flinches and dims; your cards light up.
        let before = caught.map(\.alpha)
        dimmed += zip(caught, before).map { (view: $0, alpha: $1) }
        after(0.22) {
            for card in caught {
                if !still { self.kit.shake(card, amplitude: 5, duration: 0.35) }
                UIView.animate(withDuration: 0.2) { card.alpha = 0.3 }
            }
            for card in mine {
                guard let parent = card.superview else { continue }
                self.kit.glowPulse(at: overlay.convert(card.center, from: parent), size: card.frame.width * 2.4)
                guard !still else { continue }
                let bump = CAKeyframeAnimation(keyPath: "transform.scale")
                bump.values = [0, 0.16, -0.02, 0]
                bump.keyTimes = [0, 0.35, 0.7, 1]
                bump.duration = 0.35
                bump.isAdditive = true
                card.layer.add(bump, forKey: "caught")
            }
        }
        after(1.55) {
            UIView.animate(withDuration: 0.25) {
                bubble.alpha = 0
                bubble.transform = rest.scaledBy(x: 0.85, y: 0.85)
            }
            UIView.animate(withDuration: 0.3) {
                for (card, alpha) in zip(caught, before) { card.alpha = alpha }
            }
            self.dimmed.removeAll { entry in caught.contains { $0 === entry.view } }
        }
        after(1.9) {
            bubble.removeFromSuperview()
            finish()
        }
    }

    // MARK: The Hammer

    private func hammer(hand: PokerHandRecord, seat: Int, finish: @escaping () -> Void) {
        guard let table, let overlay = kit.overlay, hand.hole.count == 2,
              table.communityCardViews.count > 2,
              let sources = table.playerView(for: seat)?.holeCardViews else { finish(); return }
        let ghosts = zip(hand.hole, sources).compactMap { ghost(of: $1, card: $0) }
        guard ghosts.count == 2 else {
            ghosts.forEach { $0.removeFromSuperview() }
            finish()
            return
        }
        hide(sources)
        let homes = ghosts.map { (center: $0.center, transform: $0.transform) }
        let board = overlay.convert(table.communityCardViews[2].center, from: table)
        let w = ghosts[0].bounds.width
        let landings = [CGPoint(x: board.x - w * 0.56, y: board.y + 4), CGPoint(x: board.x + w * 0.56, y: board.y + 4)]
        let tilts: [CGFloat] = [-0.1, 0.12]
        let scrim = self.scrim(alpha: kit.isDark ? 0.4 : 0.28)
        GameHaptics.shared.play(.hammer)

        if kit.reduceMotion {
            // No throw: they fade out of your hand and in on the felt.
            for index in 0..<2 {
                ghosts[index].alpha = 0
                ghosts[index].center = landings[index]
                ghosts[index].transform = CGAffineTransform(rotationAngle: tilts[index])
            }
            UIView.animate(withDuration: 0.25) { ghosts.forEach { $0.alpha = 1 } }
        } else {
            // 7, then 2: thrown up out of your hand and smashed down.
            for index in 0..<2 {
                after(Double(index) * 0.36) { self.slam(ghosts[index], onto: landings[index], tilt: tilts[index]) }
            }
        }
        after(0.82) {
            self.kit.glowPulse(at: board, size: w * 4)
            self.kit.showCallout("THE HAMMER", subtitle: "7-2 OFFSUIT",
                                 at: CGPoint(x: board.x, y: board.y - ghosts[0].bounds.height * 0.5 - 44),
                                 size: 22, hold: 1.05)
        }
        after(2.0) {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut]) {
                for (ghost, home) in zip(ghosts, homes) {
                    if self.kit.reduceMotion {
                        ghost.alpha = 0
                    } else {
                        ghost.center = home.center
                        ghost.transform = home.transform
                    }
                }
            }
            self.clear(scrim)
        }
        after(2.34) {
            ghosts.forEach { $0.removeFromSuperview() }
            self.show(sources)
            finish()
        }
    }

    /// Up out of your hand, then smashed down onto the felt.
    private func slam(_ ghost: CardView, onto spot: CGPoint, tilt: CGFloat) {
        let generation = self.generation
        let rest = CGAffineTransform(rotationAngle: tilt)
        let shadow = (radius: ghost.layer.shadowRadius, offset: ghost.layer.shadowOffset,
                      opacity: ghost.layer.shadowOpacity)
        GameAudio.shared.play(.deal)
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            ghost.center = CGPoint(x: spot.x, y: spot.y - 120)
            ghost.transform = rest.rotated(by: -tilt * 2.2).scaledBy(x: 1.45, y: 1.45)
            ghost.layer.shadowRadius = 22
            ghost.layer.shadowOffset = CGSize(width: 0, height: 28)
            ghost.layer.shadowOpacity = 0.3
        } completion: { _ in
            guard self.generation == generation else { return }
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseIn]) {
                ghost.center = spot
                ghost.transform = rest
                ghost.layer.shadowRadius = shadow.radius
                ghost.layer.shadowOffset = shadow.offset
                ghost.layer.shadowOpacity = shadow.opacity
            } completion: { _ in
                guard self.generation == generation else { return }
                self.impact(ghost, rest: rest)
            }
        }
    }

    /// The instant of contact: a flash, a ring, chips kicked up, a beat of
    /// stillness, then the squash and the shake.
    private func impact(_ ghost: CardView, rest: CGAffineTransform) {
        GameAudio.shared.play(.slam)
        let w = ghost.bounds.width
        kit.flash(at: ghost.center, diameter: w * 3.4, peak: 0.9, duration: 0.34)
        kit.shockwave(at: ghost.center, from: w * 1.15, to: w * 3.2, lineWidth: 7, duration: 0.5)
        debris(at: CGPoint(x: ghost.center.x, y: ghost.center.y + ghost.bounds.height * 0.3), width: w)
        after(0.07) {
            self.kit.squash(ghost, rest: rest)
            self.kit.shakeStage(amplitude: 11, duration: 0.45)
        }
    }

    /// Chips, card chips and sparks kicked up off the felt.
    private func debris(at point: CGPoint, width: CGFloat) {
        let traits = kit.overlay?.traitCollection ?? .current
        let chips = [PokerTheme.Chip.red, PokerTheme.Chip.blue, PokerTheme.Chip.green, PokerTheme.Chip.purple]
            .map { $0.resolvedColor(with: traits) }
        var bits: [(MomentKit.Bit, UIColor, CGFloat)] = (0..<10).map { (.chip, chips[$0 % chips.count], 11) }
        bits += Array(repeating: (.shard, .white, 9), count: 8)
        bits += Array(repeating: (.spark, kit.gold, 12), count: 10)
        kit.throwBits(bits.shuffled(), from: point, across: width * 0.7,
                      toward: -.pi / 2, spread: 1.1, distance: 60...150, fall: 150,
                      duration: 0.55...0.85, below: nil)
    }

    // MARK: Knockout

    private func knockout(hand: PokerHandRecord, seat: Int, finish: @escaping () -> Void) {
        guard let table, let overlay = kit.overlay, let me = table.playerView(for: seat),
              let stackParent = me.stackTarget.superview else { finish(); return }
        let seats = hand.knockedOut.compactMap { table.playerView(for: $0) }
        guard !seats.isEmpty else { finish(); return }
        let still = kit.reduceMotion
        let stack = overlay.convert(me.stackTarget.center, from: stackParent)
        let red = PokerTheme.warn.resolvedColor(with: overlay.traitCollection)
        GameHaptics.shared.play(.knockout)

        var marks: [UIView] = []
        for (index, out) in seats.enumerated() {
            let face = out.portrait ?? out
            guard let parent = face.superview else { continue }
            let spot = overlay.convert(face.center, from: parent)
            let size = max(face.bounds.width, 40)

            // The lights go out on their seat…
            let veil = UIView(frame: CGRect(x: 0, y: 0, width: size * 1.12, height: size * 1.12))
            veil.center = spot
            veil.layer.cornerRadius = veil.bounds.width / 2
            veil.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            veil.isUserInteractionEnabled = false
            veil.alpha = 0
            overlay.addSubview(veil)
            // …and the stamp slams on.
            let stamp = koStamp(red: red)
            stamp.center = spot
            overlay.addSubview(stamp)
            marks += [veil, stamp]
            let rest = CGAffineTransform(rotationAngle: -0.2)
            stamp.alpha = 0
            stamp.transform = still ? rest : rest.scaledBy(x: 3, y: 3)
            UIView.animate(withDuration: 0.13, delay: 0, options: [.curveEaseIn]) {
                stamp.alpha = 1
                stamp.transform = rest
            }
            after(0.13) {
                if index == 0 { GameAudio.shared.play(.slam) }
                self.kit.flash(at: spot, diameter: size * 3, peak: 0.85, duration: 0.3)
                if !still {
                    self.kit.squash(stamp, rest: rest)
                    self.kit.shockwave(at: spot, from: size, to: size * 2.6, lineWidth: 5, duration: 0.45, color: red)
                }
                UIView.animate(withDuration: 0.25) { veil.alpha = 1 }
            }
            // Their chips arc into your stack.
            if !still { after(0.45) { self.bounty(from: spot, to: stack, quiet: index > 0) } }
        }
        after(0.13) { self.kit.shakeStage(amplitude: 9, duration: 0.4) }
        if seats.count > 1 {
            let title = seats.count == 2 ? "DOUBLE KO" : seats.count == 3 ? "TRIPLE KO" : "\(seats.count)× KO"
            let middle = table.communityCardViews.count > 2
                ? overlay.convert(table.communityCardViews[2].center, from: table)
                : CGPoint(x: overlay.bounds.midX, y: overlay.bounds.midY)
            after(0.25) { self.kit.showCallout(title, at: middle, size: 22, hold: 1.1) }
        }
        after(1.2) {
            GameAudio.shared.play(.pot, volume: 0.9)
            guard !still else { return }
            let bump = CAKeyframeAnimation(keyPath: "transform.scale")
            bump.values = [1, 1.35, 0.95, 1]
            bump.keyTimes = [0, 0.3, 0.65, 1]
            bump.duration = 0.4
            me.stackTarget.layer.add(bump, forKey: "bounty")
            self.kit.shockwave(at: stack, from: 24, to: 76, lineWidth: 4, duration: 0.45)
        }
        after(1.65) {
            UIView.animate(withDuration: 0.3) { marks.forEach { $0.alpha = 0 } }
        }
        after(1.98) {
            marks.forEach { $0.removeFromSuperview() }
            finish()
        }
    }

    /// Chips arcing from `start` into your stack at `end` — a bounty flying
    /// to whoever made the knockout.
    private func bounty(from start: CGPoint, to end: CGPoint, quiet: Bool) {
        guard let overlay = kit.overlay else { return }
        let traits = overlay.traitCollection
        let colors = [PokerTheme.Chip.red, PokerTheme.Chip.gold, PokerTheme.Chip.blue,
                      PokerTheme.Chip.green, PokerTheme.Chip.purple].map { $0.resolvedColor(with: traits) }
        let hairline = kit.style.hairline.resolvedColor(with: traits).cgColor
        let flight: TimeInterval = 0.45
        for index in 0..<7 {
            let chip = kit.shape(.chip, color: colors[index % colors.count], size: 15, hairline: hairline)
            chip.position = end
            chip.opacity = 0
            overlay.layer.addSublayer(chip)
            let bend = CGPoint(x: (start.x + end.x) / 2 + CGFloat.random(in: -30...30),
                               y: min(start.y, end.y) - 70 - CGFloat.random(in: 0...30))
            let arc = UIBezierPath()
            arc.move(to: start)
            arc.addQuadCurve(to: end, controlPoint: bend)
            let move = CAKeyframeAnimation(keyPath: "position")
            move.path = arc.cgPath
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.45, 0, 0.55, 1)
            let show = CAKeyframeAnimation(keyPath: "opacity")
            show.values = [0, 1, 1, 0]
            show.keyTimes = [0, 0.08, 0.9, 1]
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.random(in: -6...6)
            let group = CAAnimationGroup()
            group.animations = [move, show, spin]
            group.duration = flight
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.05
            group.fillMode = .backwards
            CATransaction.begin()
            CATransaction.setCompletionBlock { chip.removeFromSuperlayer() }
            chip.add(group, forKey: "bounty")
            CATransaction.commit()
            if !quiet, index.isMultiple(of: 2) {
                GameAudio.shared.play(.bet, volume: 0.45, pitch: 0.95 + Float(index) * 0.04,
                                      delay: flight + Double(index) * 0.05)
            }
        }
    }

    private func koStamp(red: UIColor) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(string: "K.O.", attributes: [
            .font: UIFont.systemFont(ofSize: 30 * kit.style.typeScale, weight: .black).italic,
            .foregroundColor: red,
            .strokeColor: UIColor.white,
            .strokeWidth: -4,
            .kern: 1
        ])
        label.sizeToFit()
        label.isUserInteractionEnabled = false
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.35
        label.layer.shadowRadius = 6
        label.layer.shadowOffset = CGSize(width: 0, height: 3)
        return label
    }

    // MARK: Pieces

    /// A stand-in for `source` showing `card`, drawn in the overlay in
    /// exactly its pose.
    private func ghost(of source: CardView, card: Card) -> CardView? {
        guard let overlay = kit.overlay, let parent = source.superview, source.bounds.width > 0 else { return nil }
        let ghost = CardView()
        ghost.design = source.design
        ghost.style = source.style
        ghost.setCard(card, faceUp: true)
        ghost.isUserInteractionEnabled = false
        ghost.bounds = source.bounds
        ghost.center = overlay.convert(source.center, from: parent)
        ghost.transform = source.transform
        overlay.addSubview(ghost)
        ghost.layoutIfNeeded()
        return ghost
    }

    /// Where `card` sits on the table: a board card by its place on the
    /// board, one of yours by its place in your hand. By place, not by face,
    /// so a debug replay's made-up hand lands where a real one would.
    private func slot(of card: Card, in hand: PokerHandRecord, seat: Int) -> CardView? {
        guard let table else { return nil }
        if let index = hand.board.firstIndex(of: card), index < table.communityCardViews.count {
            return table.communityCardViews[index]
        }
        if let index = hand.hole.firstIndex(of: card),
           let views = table.playerView(for: seat)?.holeCardViews, index < views.count {
            return views[index]
        }
        return nil
    }

    /// The five cards in reading order: quads before their kicker, a wheel
    /// with its ace low.
    private func ordered(_ hand: HandEvaluation) -> [Card] {
        let made = PokerMoments.madeCards(of: hand)
        var cards = made + hand.cards.filter { !made.contains($0) }
        if Set(cards.map(\.rank)) == [.ace, .two, .three, .four, .five],
           let ace = cards.firstIndex(where: { $0.rank == .ace }) {
            cards.append(cards.remove(at: ace))
        }
        return cards
    }

    /// The real cards hide under their stand-ins — behind an empty mask, so
    /// nothing the table does to them meanwhile brings them back early.
    private func hide(_ views: [UIView]) {
        views.forEach { $0.layer.mask = CALayer() }
        hidden += views
    }

    private func show(_ views: [UIView]) {
        views.forEach { $0.layer.mask = nil }
        hidden.removeAll { view in views.contains { $0 === view } }
    }

    /// Dims everything under the effects.
    private func scrim(alpha: CGFloat) -> UIView? {
        guard let overlay = kit.overlay, let host = overlay.superview else { return nil }
        let scrim = UIView(frame: overlay.frame)
        scrim.backgroundColor = .black
        scrim.isUserInteractionEnabled = false
        scrim.alpha = 0
        host.insertSubview(scrim, belowSubview: overlay)
        scrims.append(scrim)
        UIView.animate(withDuration: 0.25) { scrim.alpha = alpha }
        return scrim
    }

    private func clear(_ scrim: UIView?) {
        guard let scrim else { return }
        scrims.removeAll { $0 === scrim }
        UIView.animate(withDuration: 0.3, animations: { scrim.alpha = 0 }) { _ in
            scrim.removeFromSuperview()
        }
    }

    /// Runs `work` after `delay` — unless the moment is cancelled first.
    private func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let generation = self.generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == generation else { return }
            work()
        }
    }
}

// MARK: - Odds chip

/// Poker TV's odds box: what you had to win, flipping to WIN.
private final class OddsChip: UIView {

    private let value = UILabel()
    private let caption = UILabel()

    init(odds: Double, typeScale: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: 76 * typeScale, height: 46 * typeScale))
        isUserInteractionEnabled = false
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.cornerRadius = 12 * typeScale
        layer.cornerCurve = .continuous
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        layer.borderWidth = 1

        value.text = Self.percent(odds)
        value.font = .monospacedDigitSystemFont(ofSize: 20 * typeScale, weight: .heavy)
        value.textColor = .white
        value.textAlignment = .center
        caption.text = "TO WIN"
        caption.font = .systemFont(ofSize: 9 * typeScale, weight: .heavy)
        caption.textColor = UIColor.white.withAlphaComponent(0.6)
        caption.textAlignment = .center
        value.frame = CGRect(x: 0, y: 5 * typeScale, width: bounds.width, height: 24 * typeScale)
        caption.frame = CGRect(x: 0, y: 29 * typeScale, width: bounds.width, height: 12 * typeScale)
        addSubview(value)
        addSubview(caption)
    }

    required init?(coder: NSCoder) { fatalError() }

    static func percent(_ odds: Double) -> String {
        odds < 0.005 ? "<1%" : "\(Int((odds * 100).rounded()))%"
    }

    /// Springs in; with Reduce Motion (`still`) it fades in.
    func popIn(still: Bool) {
        alpha = 0
        guard !still else {
            UIView.animate(withDuration: 0.25, delay: 0.1) { self.alpha = 1 }
            return
        }
        transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        UIView.animate(withDuration: 0.45, delay: 0.1, usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.6, options: []) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func win(gold: UIColor, still: Bool) {
        UIView.transition(with: self, duration: 0.35,
                          options: [still ? .transitionCrossDissolve : .transitionFlipFromTop]) {
            self.backgroundColor = gold
            self.layer.borderWidth = 0
            self.value.text = "WIN"
            self.value.textColor = MomentKit.ink
            self.caption.text = "100%"
            self.caption.textColor = MomentKit.ink.withAlphaComponent(0.7)
        }
    }
}

// MARK: - Jagged bubble

/// Ace Attorney's "OBJECTION!" bubble: spiky, outlined, shouting.
private final class JaggedBubble: UIView {

    init(title: String, subtitle: String, fill: UIColor, typeScale: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: 280 * typeScale, height: 150 * typeScale))
        isUserInteractionEnabled = false

        let shape = CAShapeLayer()
        shape.path = Self.burst(in: bounds.insetBy(dx: 6, dy: 6)).cgPath
        shape.fillColor = fill.cgColor
        shape.strokeColor = MomentKit.ink.cgColor
        shape.lineWidth = 4
        shape.lineJoin = .round
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOpacity = 0.35
        shape.shadowRadius = 12
        shape.shadowOffset = CGSize(width: 0, height: 6)
        layer.addSublayer(shape)

        let words = UILabel()
        let text = NSMutableAttributedString(string: title, attributes: [
            .font: UIFont.systemFont(ofSize: 30 * typeScale, weight: .black).italic,
            .foregroundColor: MomentKit.ink,
            .kern: 1.5
        ])
        text.append(NSAttributedString(string: "\n" + subtitle, attributes: [
            .font: UIFont.systemFont(ofSize: 11 * typeScale, weight: .heavy),
            .foregroundColor: MomentKit.ink.withAlphaComponent(0.72),
            .kern: 1.4
        ]))
        words.attributedText = text
        words.numberOfLines = 2
        words.textAlignment = .center
        words.sizeToFit()
        words.center = CGPoint(x: bounds.midX, y: bounds.midY)
        addSubview(words)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// An oval of spikes, some longer than others, like it was inked by hand.
    static func burst(in rect: CGRect) -> UIBezierPath {
        let spikes = 16
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let path = UIBezierPath()
        for k in 0..<(spikes * 2) {
            let angle = CGFloat(k) / CGFloat(spikes * 2) * 2 * .pi - .pi / 2
            let reach = k.isMultiple(of: 2) ? 0.9 + 0.1 * abs(sin(CGFloat(k) * 1.7)) : 0.74
            let point = CGPoint(x: center.x + cos(angle) * rect.width / 2 * reach,
                                y: center.y + sin(angle) * rect.height / 2 * reach)
            if k == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.close()
        return path
    }
}

private extension UIFont {
    var italic: UIFont {
        fontDescriptor.withSymbolicTraits(fontDescriptor.symbolicTraits.union(.traitItalic))
            .map { UIFont(descriptor: $0, size: pointSize) } ?? self
    }
}
