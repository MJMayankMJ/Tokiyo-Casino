//
//  TDPMomentEffects.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The fanfare for a first cut or a steal (`TDPMoments`).
//
//  A first cut gets two beats:
//
//  • slam — after Marvel Snap's card plays: the card flies up out of your
//    hand, then smashes down onto the felt. At impact the world freezes for
//    70 ms (hit-stop), the card squashes and springs back with its area kept
//    (squash & stretch), the table shakes with a touch of rotation that dies
//    off fast, a ring rolls out and debris kicks up — and a heavy haptic
//    boom lands on the same frame.
//  • burst — after Clash Royale's chest: the card lifts and wobbles harder
//    and harder while light leaks from behind it, then the screen flashes
//    and it bursts: rays wheel out, sparks fly, a callout pops, a shimmer
//    runs through the phone. Then it settles back into the trick.
//
//  A steal waits until the point is confirmed — the trick being taken:
//
//  • claim — Balatro's score flying to the total, Clash Royale's crown
//    flying to its counter: a foil sheen crosses your winning card, the
//    trick gathers onto it and arcs down into your trick count leaving a
//    trail of sparks; the count ticks up with a bump, "+1" floats off, a
//    small shake and a coin-collect haptic.
//
//  The effects run on stand-ins ("ghosts") of the cards in an overlay, so
//  the table underneath stays exactly as the host sees it; the host holds
//  a cut trick a little longer (`TDPHostService.momentHold`).
//  Reduce Motion keeps the light and the haptics and drops the shake,
//  the throw and the particles. The pieces are shared with Poker's
//  moments (`MomentKit`).
//

import UIKit

final class TDPMomentEffects {

    private let kit: MomentKit
    private let compact: Bool
    private var generation = 0
    private var hidden: [UIView] = []

    /// `stage` is everything that shakes; `overlay` sits above it and holds
    /// the effects.
    init(stage: UIView, overlay: UIView, compact: Bool = false) {
        self.compact = compact
        kit = MomentKit(stage: stage, overlay: overlay,
                        style: .init(gold: TDPTheme.momentGold, hairline: TDPTheme.hairline,
                                     typeScale: compact ? 1 : TDPTheme.scale))
    }


    /// The home tile uses the real cut beats, with a shorter hold.
    func previewCut(_ source: UIView, card: Card, trump: Suit, completion: @escaping () -> Void) {
        slam(source, card: card, trump: trump)
        burst(source, card: card, callout: "FIRST CUT")
        kit.run { finish in
            finish()
            completion()
        }
    }

    /// Invalidate delayed work before a home preview disappears or is reset.
    func cancel() {
        generation += 1
        kit.cancelAll()
        hidden.forEach { $0.alpha = 1 }
        hidden.removeAll()
        kit.stage?.layer.removeAllAnimations()
        kit.overlay?.subviews.forEach { $0.removeFromSuperview() }
        kit.overlay?.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    private func after(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.generation == token else { return }
            work()
        }
    }

    // MARK: Slam

    /// Throws `source` — a card at rest on the table — down hard.
    func slam(_ source: UIView, card: Card, trump: Suit) {
        kit.run { [weak self] finish in
            guard let self, let overlay = self.kit.overlay,
                  let ghost = self.ghost(of: source, card: card, in: overlay) else { finish(); return }
            let token = self.generation
            let rest = ghost.transform
            let spot = ghost.center
            self.hidden.append(source)
            source.alpha = 0
            GameHaptics.shared.play(.slam)

            guard !self.kit.reduceMotion else {
                GameAudio.shared.play(.slam, delay: 0.32)
                self.after(0.32) {
                    self.kit.glowPulse(at: spot, size: ghost.bounds.width * 2.6)
                }
                self.end(ghost, source: source, after: 0.8, finish: finish)
                return
            }

            // 1. Up and out of your hand, over the table.
            GameAudio.shared.play(.deal)
            ghost.center = CGPoint(x: spot.x, y: spot.y + 170)
            ghost.transform = rest.scaledBy(x: 0.9, y: 0.9)
            let shadow = (radius: ghost.layer.shadowRadius, offset: ghost.layer.shadowOffset,
                          opacity: ghost.layer.shadowOpacity)
            UIView.animate(withDuration: self.compact ? 0.12 : 0.2, delay: 0, options: [.curveEaseOut]) {
                ghost.center = CGPoint(x: spot.x, y: spot.y - 110)
                ghost.transform = rest.rotated(by: -0.22).scaledBy(x: 1.55, y: 1.55)
                ghost.layer.shadowRadius = 22
                ghost.layer.shadowOffset = CGSize(width: 0, height: 28)
                ghost.layer.shadowOpacity = 0.3
            } completion: { _ in
                guard self.generation == token else { return }
                // 2. Smashed down, accelerating into the felt.
                UIView.animate(withDuration: self.compact ? 0.08 : 0.12, delay: 0, options: [.curveEaseIn]) {
                    ghost.center = spot
                    ghost.transform = rest
                    ghost.layer.shadowRadius = shadow.radius
                    ghost.layer.shadowOffset = shadow.offset
                    ghost.layer.shadowOpacity = shadow.opacity
                } completion: { _ in
                    guard self.generation == token else { return }
                    self.impact(ghost, rest: rest, trump: trump)
                    self.end(ghost, source: source, after: self.compact ? 0.12 : 0.62, finish: finish)
                }
            }
        }
    }

    /// The instant of contact.
    private func impact(_ ghost: UIView, rest: CGAffineTransform, trump: Suit) {
        GameAudio.shared.play(.slam)
        let w = ghost.bounds.width
        kit.flash(at: ghost.center, diameter: w * 3.4, peak: 0.9, duration: 0.34)
        kit.shockwave(at: ghost.center, from: w * 1.15, to: w * 3.2, lineWidth: 7, duration: 0.5)
        debris(at: CGPoint(x: ghost.center.x, y: ghost.center.y + ghost.bounds.height * 0.3),
               width: w, trump: trump)
        // Hit-stop: everything holds for a beat, then reacts.
        self.after(0.07) { [weak self] in
            self?.kit.squash(ghost, rest: rest)
            if let stage = self?.kit.stage { self?.kit.shake(stage, amplitude: 11, duration: 0.45) }
        }
    }

    // MARK: Burst

    /// The reward: `source` (at rest in the trick) lifts, wobbles, and
    /// bursts with light under `callout`.
    func burst(_ source: UIView, card: Card, callout: String) {
        kit.run { [weak self] finish in
            guard let self, let overlay = self.kit.overlay, source.window != nil,
                  let ghost = self.ghost(of: source, card: card, in: overlay) else { finish(); return }
            let kit = self.kit
            let rest = ghost.transform
            let spot = ghost.center
            let w = ghost.bounds.width
            self.hidden.append(source)
            source.alpha = 0
            GameHaptics.shared.play(.reveal)

            // Light behind the card: a glow that leaks during the build-up,
            // then rays that wheel out at the burst.
            let glow = kit.glowLayer(diameter: w * 3.6)
            glow.position = spot
            glow.opacity = 0
            let rays = kit.raysLayer(diameter: w * 5.2)
            rays.position = spot
            rays.opacity = 0
            overlay.layer.insertSublayer(glow, below: ghost.layer)
            overlay.layer.insertSublayer(rays, below: glow)

            let lifted = rest.translatedBy(x: 0, y: -12).scaledBy(x: 1.14, y: 1.14)
            let buildUp: TimeInterval = kit.reduceMotion ? 0.2 : (self.compact ? 0.14 : 0.42)
            let rewardHold: TimeInterval = self.compact ? 0.32 : 0.85

            // 1. Build-up: lift, a wobble that grows, light leaking out.
            UIView.animate(withDuration: self.compact ? 0.12 : 0.22, delay: 0, options: [.curveEaseOut]) {
                ghost.transform = lifted
            }
            if !kit.reduceMotion {
                let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                wobble.values = [0, 0.045, -0.06, 0.08, -0.095, 0.07, 0]
                wobble.keyTimes = [0, 0.18, 0.36, 0.54, 0.72, 0.88, 1]
                wobble.duration = buildUp
                wobble.isAdditive = true
                ghost.layer.add(wobble, forKey: "wobble")
            }
            kit.animate(glow, key: "opacity", from: 0, to: 0.7, duration: buildUp, timing: .easeIn)

            // 2. Release.
            self.after(buildUp) {
                GameAudio.shared.play(.sweep, volume: 0.9)
                kit.animate(rays, key: "opacity", from: 0, to: 1, duration: 0.14, timing: .easeOut)
                if !kit.reduceMotion {
                    kit.screenFlash(peak: self.compact ? 0.22 : (kit.isDark ? 0.45 : 0.6), duration: 0.3)
                    let grow = CASpringAnimation(keyPath: "transform.scale")
                    grow.fromValue = 0.3
                    grow.toValue = 1
                    grow.damping = 11
                    grow.initialVelocity = 6
                    grow.duration = grow.settlingDuration
                    rays.add(grow, forKey: "grow")
                    let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                    spin.byValue = CGFloat.pi / 3
                    spin.duration = 4
                    spin.isAdditive = true
                    rays.add(spin, forKey: "spin")
                    kit.sparks(at: spot, width: w, behind: ghost)
                    kit.shockwave(at: spot, from: w * 1.2, to: w * 3.0, lineWidth: 5, duration: 0.55)
                }
                UIView.animate(withDuration: self.compact ? 0.25 : 0.5, delay: 0, usingSpringWithDamping: 0.45,
                               initialSpringVelocity: 0.9, options: []) {
                    ghost.transform = lifted.scaledBy(x: 1.08, y: 1.08)
                }
                // Above the whole trick, clear of the other two cards.
                kit.showCallout(callout, at: CGPoint(x: spot.x, y: spot.y - ghost.bounds.height * 1.6 - 18),
                                size: 19, hold: rewardHold)
            }

            // 3. Settle back into the trick.
            let settleAt = buildUp + rewardHold
            let settleDuration: TimeInterval = self.compact ? 0.2 : 0.38
            self.after(settleAt) {
                kit.animate(rays, key: "opacity", from: 1, to: 0, duration: 0.35, timing: .easeIn)
                kit.animate(glow, key: "opacity", from: 0.7, to: 0, duration: 0.35, timing: .easeIn)
                UIView.animate(withDuration: self.compact ? 0.18 : 0.35, delay: 0, usingSpringWithDamping: 0.8,
                               initialSpringVelocity: 0, options: []) {
                    ghost.transform = rest
                }
            }
            self.after(settleAt + settleDuration) {
                rays.removeFromSuperlayer()
                glow.removeFromSuperlayer()
            }
            self.end(ghost, source: source, after: settleAt + settleDuration, finish: finish)
        }
    }

    // MARK: Claim

    /// The steal, once the trick is taken: `cards` (the trick, `winner` among
    /// them) gather and fly into `target` — your trick count. `landed` runs
    /// as they arrive, so the new count appears on the hit.
    func claim(_ cards: [TDPCardButton], winner: TDPCardButton, into target: UIView,
               callout: String, landed: @escaping () -> Void) {
        kit.run { [weak self] finish in
            guard let self, let overlay = self.kit.overlay, let targetParent = target.superview else {
                cards.forEach { $0.removeFromSuperview() }
                landed()
                finish()
                return
            }
            let kit = self.kit
            let pairs = cards.compactMap { view -> (TDPCardButton, Bool)? in
                guard let face = view.card, let ghost = self.ghost(of: view, card: face, in: overlay) else { return nil }
                return (ghost, view === winner)
            }
            cards.forEach { $0.removeFromSuperview() }
            guard let top = pairs.first(where: { $0.1 })?.0 else {
                pairs.forEach { $0.0.removeFromSuperview() }
                landed()
                finish()
                return
            }
            overlay.bringSubviewToFront(top)
            let ghosts = pairs.map(\.0)
            let destination = overlay.convert(target.center, from: targetParent)
            GameHaptics.shared.play(.claim)

            guard !kit.reduceMotion else {
                UIView.animate(withDuration: 0.25, animations: { ghosts.forEach { $0.alpha = 0 } }) { _ in
                    ghosts.forEach { $0.removeFromSuperview() }
                    landed()
                    self.scoreHit(at: destination, target: target, callout: callout)
                    self.after(1.0) { finish() }
                }
                return
            }

            // 1. The winning card catches the light; the trick gathers onto it.
            kit.sheen(across: top, cornerRadius: top.bounds.width * 0.145, duration: 0.42)
            let stack = top.center
            let rest = top.transform
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut]) {
                for (index, ghost) in ghosts.enumerated() where ghost !== top {
                    let nudge = CGFloat(index) * 3 - 3
                    ghost.center = CGPoint(x: stack.x + nudge, y: stack.y - 3)
                    ghost.transform = rest.rotated(by: nudge * 0.02).scaledBy(x: 0.96, y: 0.96)
                }
                top.transform = rest.scaledBy(x: 1.08, y: 1.08)
            }

            // 2. Into your pile, along an arc, trailing sparks.
            let fly: TimeInterval = 0.42
            let bend = CGPoint(x: stack.x + (destination.x - stack.x) * 0.2 + 56, y: min(stack.y, destination.y) - 36)
            self.after(0.2) {
                let arc = UIBezierPath()
                arc.move(to: stack)
                arc.addQuadCurve(to: destination, controlPoint: bend)
                for ghost in ghosts {
                    let move = CAKeyframeAnimation(keyPath: "position")
                    move.path = arc.cgPath
                    let shrink = CABasicAnimation(keyPath: "transform")
                    shrink.toValue = NSValue(caTransform3D: CATransform3DMakeAffineTransform(
                        rest.rotated(by: 0.6).scaledBy(x: 0.22, y: 0.22)))
                    let group = CAAnimationGroup()
                    group.animations = [move, shrink]
                    group.duration = fly
                    group.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0, 0.85, 0.4)
                    group.fillMode = .forwards
                    group.isRemovedOnCompletion = false
                    ghost.layer.add(group, forKey: "claim")
                }
                for step in 1...7 {
                    let t = CGFloat(step) / 8
                    let point = kit.point(onQuad: stack, bend, destination, at: pow(t, 1.6))
                    self.after(fly * Double(pow(t, 1.6))) {
                        kit.trailSpark(at: point, size: 13 - CGFloat(step))
                    }
                }
            }

            // 3. The point lands.
            self.after(0.2 + fly) {
                ghosts.forEach { $0.removeFromSuperview() }
                GameAudio.shared.play(.play, volume: 0.8)
                landed()
                self.scoreHit(at: destination, target: target, callout: callout)
                if let stage = kit.stage { kit.shake(stage, amplitude: 3.5, duration: 0.22) }
            }
            self.after(0.2 + fly + 1.0) { finish() }
        }
    }

    /// What happens at the count: a bump, a gold ring, sparks, "+1" floating
    /// off, and the callout rising beside it.
    private func scoreHit(at point: CGPoint, target: UIView, callout: String) {
        let bump = CAKeyframeAnimation(keyPath: "transform.scale")
        bump.values = [1, 1.75, 0.9, 1.06, 1]
        bump.keyTimes = [0, 0.22, 0.52, 0.78, 1]
        bump.duration = 0.5
        target.layer.add(bump, forKey: "bump")
        if !kit.reduceMotion {
            kit.shockwave(at: point, from: 26, to: 92, lineWidth: 4, duration: 0.45)
            var bits: [(MomentKit.Bit, UIColor, CGFloat)] = Array(repeating: (.spark, kit.gold, 11), count: 8)
            bits += Array(repeating: (.dot, kit.gold, 5), count: 6)
            kit.throwBits(bits.shuffled(), from: point, across: 10, toward: -.pi / 2, spread: .pi,
                          distance: 24...54, fall: 14, duration: 0.45...0.7, below: nil)
        }
        kit.floatText("+1", at: CGPoint(x: point.x + 20, y: point.y - 6))
        kit.showCallout(callout, at: CGPoint(x: point.x, y: point.y - 58), size: 15, hold: 1.0)
    }

    // MARK: Pieces

    /// A stand-in for `source`, drawn in the overlay in exactly its pose.
    private func ghost(of source: UIView, card: Card, in overlay: UIView) -> TDPCardButton? {
        guard let parent = source.superview else { return nil }
        let ghost = TDPCardButton(card: card, elevation: .table, design: (source as? TDPCardButton)?.design)
        ghost.isUserInteractionEnabled = false
        ghost.bounds = source.bounds
        ghost.center = overlay.convert(source.center, from: parent)
        ghost.transform = source.transform
        overlay.addSubview(ghost)
        ghost.layoutIfNeeded()
        return ghost
    }

    /// Hands the card back to the table once the ghost is at rest; if the
    /// trick has already gone, the ghost fades with it.
    private func end(_ ghost: UIView, source: UIView, after delay: TimeInterval, finish: @escaping () -> Void) {
        self.after(delay) {
            self.hidden.removeAll { $0 === source }
            if source.window != nil {
                source.alpha = 1
                ghost.removeFromSuperview()
            } else {
                UIView.animate(withDuration: 0.25, animations: { ghost.alpha = 0 }) { _ in
                    ghost.removeFromSuperview()
                }
            }
            finish()
        }
    }

    /// Card chips, sparks and a few trump pips kicked up off the felt.
    private func debris(at point: CGPoint, width: CGFloat, trump: Suit) {
        let traits = kit.overlay?.traitCollection ?? .current
        let pip = (TDPTheme.isRed(trump) ? TDPTheme.trumpRed : TDPTheme.ink).resolvedColor(with: traits)
        let paper = TDPTheme.cardFace.resolvedColor(with: traits)
        var bits: [(MomentKit.Bit, UIColor, CGFloat)] = []
        bits += Array(repeating: (.shard, paper, 9), count: 14)
        bits += Array(repeating: (.spark, kit.gold, 12), count: 12)
        bits += Array(repeating: (.pip(trump), pip, 11), count: 5)
        kit.throwBits(bits.shuffled(), from: point, across: width * 0.7,
                      toward: -.pi / 2, spread: 1.1, distance: 60...150, fall: 150,
                      duration: 0.55...0.85, below: nil)
    }
}
