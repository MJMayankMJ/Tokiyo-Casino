//
//  MomentKit.swift
//  Tokiyo Casino
//
//  What the tables' special moments are made of — light, shake, particles
//  and callouts — shared by 5-3-2 (`TDPMomentEffects`) and Poker
//  (`PokerMomentEffects`). Everything is drawn in an overlay above a stage
//  (the table), so the stage can shake while the effects hold still.
//  Each game's effects decide what Reduce Motion drops; these only draw.
//

import UIKit

final class MomentKit {

    /// A game's colours for its moments.
    struct Style {
        /// Rings, rays, sparks and callouts.
        var gold: UIColor
        /// The outline that keeps card chips visible on a light table.
        var hairline: UIColor
        /// Callout type grows with the table (iPad).
        var typeScale: CGFloat
    }

    /// Dark text on gold.
    static let ink = UIColor(red: 0.2, green: 0.13, blue: 0.03, alpha: 1)

    private(set) weak var stage: UIView?
    private(set) weak var overlay: UIView?
    let style: Style
    private(set) var isBusy = false
    private var queue: [() -> Void] = []

    /// `stage` is everything that shakes; `overlay` sits above it and holds
    /// the effects.
    init(stage: UIView, overlay: UIView, style: Style) {
        self.stage = stage
        self.overlay = overlay
        self.style = style
    }

    var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    var gold: UIColor { style.gold.resolvedColor(with: overlay?.traitCollection ?? .current) }
    var isDark: Bool { overlay?.traitCollection.userInterfaceStyle == .dark }

    // MARK: Queue

    /// One moment at a time: each job calls `finish` when it's done and the
    /// next one starts.
    func run(_ job: @escaping (_ finish: @escaping () -> Void) -> Void) {
        guard !isBusy else {
            queue.append { [weak self] in self?.run(job) }
            return
        }
        isBusy = true
        job { [weak self] in
            guard let self else { return }
            self.isBusy = false
            if !self.queue.isEmpty { self.queue.removeFirst()() }
        }
    }

    // MARK: Motion

    /// Squash wide and short, stretch tall and thin, settle — area kept.
    func squash(_ view: UIView, rest: CGAffineTransform) {
        let keyframes: [(CGFloat, CGFloat)] = [(1, 1), (1.16, 0.84), (0.94, 1.07), (1.03, 0.98), (1, 1)]
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = keyframes.map {
            NSValue(caTransform3D: CATransform3DMakeAffineTransform(rest.scaledBy(x: $0.0, y: $0.1)))
        }
        animation.keyTimes = [0, 0.22, 0.5, 0.78, 1]
        animation.duration = 0.38
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeOut), count: 4)
        view.layer.add(animation, forKey: "squash")
    }

    /// A short, hard shake with a little rotation, falling off fast.
    func shake(_ view: UIView, amplitude: CGFloat, duration: TimeInterval) {
        let steps = 16
        var xs: [CGFloat] = [], ys: [CGFloat] = [], turns: [CGFloat] = []
        for step in 0...steps {
            let falloff = pow(1 - CGFloat(step) / CGFloat(steps), 2)
            let angle = CGFloat.random(in: 0..<(2 * .pi))
            xs.append(step == steps ? 0 : cos(angle) * amplitude * falloff)
            ys.append(step == steps ? 0 : sin(angle) * amplitude * falloff)
            turns.append(step == steps ? 0 : CGFloat.random(in: -1...1) * 0.012 * falloff)
        }
        for (key, values) in [("transform.translation.x", xs), ("transform.translation.y", ys),
                              ("transform.rotation.z", turns)] {
            let animation = CAKeyframeAnimation(keyPath: key)
            animation.values = values
            animation.duration = duration
            animation.isAdditive = true
            animation.calculationMode = .cubic
            view.layer.add(animation, forKey: "shake-\(key)")
        }
    }

    /// Shakes the table, unless Reduce Motion is on.
    func shakeStage(amplitude: CGFloat, duration: TimeInterval) {
        guard !reduceMotion, let stage else { return }
        shake(stage, amplitude: amplitude, duration: duration)
    }

    // MARK: Light

    func flash(at point: CGPoint, diameter: CGFloat, peak: Float, duration: TimeInterval) {
        guard let overlay else { return }
        let glow = CAGradientLayer()
        glow.type = .radial
        glow.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.4).cgColor,
                       UIColor.white.withAlphaComponent(0).cgColor]
        glow.locations = [0, 0.3, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        glow.position = point
        glow.opacity = 0
        overlay.layer.insertSublayer(glow, at: 0)
        animate(glow, key: "opacity", from: peak, to: 0, duration: duration, timing: .easeOut) {
            glow.removeFromSuperlayer()
        }
    }

    func glowPulse(at point: CGPoint, size: CGFloat) {
        guard let overlay else { return }
        let glow = glowLayer(diameter: size)
        glow.position = point
        glow.opacity = 0
        overlay.layer.insertSublayer(glow, at: 0)
        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [0, 0.8, 0]
        pulse.keyTimes = [0, 0.2, 1]
        pulse.duration = 0.6
        CATransaction.begin()
        CATransaction.setCompletionBlock { glow.removeFromSuperlayer() }
        glow.add(pulse, forKey: "pulse")
        CATransaction.commit()
    }

    /// The whole screen blinks bright for an instant.
    func screenFlash(peak: CGFloat, duration: TimeInterval) {
        guard let overlay else { return }
        let sheet = UIView(frame: overlay.bounds)
        sheet.backgroundColor = .white
        sheet.isUserInteractionEnabled = false
        sheet.alpha = peak
        overlay.addSubview(sheet)
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
            sheet.alpha = 0
        } completion: { _ in
            sheet.removeFromSuperview()
        }
    }

    func shockwave(at point: CGPoint, from start: CGFloat, to endSize: CGFloat,
                   lineWidth: CGFloat, duration: TimeInterval, color: UIColor? = nil) {
        guard let overlay else { return }
        let ring = CAShapeLayer()
        let radius = start / 2
        ring.path = UIBezierPath(ovalIn: CGRect(x: -radius, y: -radius, width: start, height: start)).cgPath
        ring.position = point
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = (color ?? gold).cgColor
        ring.lineWidth = lineWidth
        ring.opacity = 0
        overlay.layer.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = endSize / start
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.95
        fade.toValue = 0
        let thin = CABasicAnimation(keyPath: "lineWidth")
        thin.fromValue = lineWidth
        thin.toValue = 0.5
        let group = CAAnimationGroup()
        group.animations = [scale, fade, thin]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.8, 0.3, 1)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(group, forKey: "wave")
        CATransaction.commit()
    }

    func glowLayer(diameter: CGFloat) -> CAGradientLayer {
        let glow = CAGradientLayer()
        glow.type = .radial
        glow.colors = [gold.withAlphaComponent(0.95).cgColor, gold.withAlphaComponent(0.35).cgColor,
                       gold.withAlphaComponent(0).cgColor]
        glow.locations = [0, 0.35, 1]
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        return glow
    }

    /// Twelve beams of light fading outward.
    func raysLayer(diameter: CGFloat) -> CALayer {
        let box = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        let container = CALayer()
        container.bounds = box
        let beams = CAShapeLayer()
        beams.frame = box
        let center = CGPoint(x: box.midX, y: box.midY)
        let count = 12
        let half = CGFloat.pi / CGFloat(count) * 0.42
        let path = UIBezierPath()
        for i in 0..<count {
            let angle = CGFloat(i) / CGFloat(count) * 2 * .pi
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + cos(angle - half) * diameter / 2,
                                     y: center.y + sin(angle - half) * diameter / 2))
            path.addLine(to: CGPoint(x: center.x + cos(angle + half) * diameter / 2,
                                     y: center.y + sin(angle + half) * diameter / 2))
            path.close()
        }
        beams.path = path.cgPath
        beams.fillColor = gold.withAlphaComponent(isDark ? 0.55 : 0.5).cgColor
        let fade = CAGradientLayer()
        fade.type = .radial
        fade.frame = box
        fade.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.6).cgColor,
                       UIColor.white.withAlphaComponent(0).cgColor]
        fade.locations = [0, 0.3, 1]
        fade.startPoint = CGPoint(x: 0.5, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 1)
        beams.mask = fade
        container.addSublayer(beams)
        return container
    }

    /// Rays that spring out and slowly wheel round behind `point` for
    /// `hold` seconds, then fade. Returns the layer so a caller can put it
    /// under something.
    @discardableResult
    func rays(at point: CGPoint, diameter: CGFloat, hold: TimeInterval, below sibling: CALayer? = nil) -> CALayer? {
        guard let overlay else { return nil }
        let rays = raysLayer(diameter: diameter)
        rays.position = point
        rays.opacity = 0
        if let sibling, sibling.superlayer === overlay.layer {
            overlay.layer.insertSublayer(rays, below: sibling)
        } else {
            overlay.layer.insertSublayer(rays, at: 0)
        }
        animate(rays, key: "opacity", from: 0, to: 1, duration: 0.14, timing: .easeOut)
        if !reduceMotion {
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
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self] in
            self?.animate(rays, key: "opacity", from: 1, to: 0, duration: 0.35, timing: .easeIn) {
                rays.removeFromSuperlayer()
            }
        }
        return rays
    }

    /// Balatro's foil: a band of light sweeping across a card.
    func sheen(across card: UIView, cornerRadius: CGFloat, duration: TimeInterval) {
        let clip = CALayer()
        clip.frame = card.bounds
        clip.cornerRadius = cornerRadius
        clip.cornerCurve = .continuous
        clip.masksToBounds = true
        let band = CAGradientLayer()
        band.frame = card.bounds
        band.startPoint = CGPoint(x: 0, y: 0)
        band.endPoint = CGPoint(x: 1, y: 1)
        band.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                       gold.withAlphaComponent(0.55).cgColor,
                       UIColor.white.withAlphaComponent(0.9).cgColor,
                       gold.withAlphaComponent(0.55).cgColor,
                       UIColor.white.withAlphaComponent(0).cgColor]
        band.locations = [-0.4, -0.3, -0.25, -0.2, -0.1]
        clip.addSublayer(band)
        card.layer.addSublayer(clip)
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.4, -0.3, -0.25, -0.2, -0.1]
        sweep.toValue = [1.1, 1.2, 1.25, 1.3, 1.4]
        sweep.duration = duration
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        CATransaction.begin()
        CATransaction.setCompletionBlock { clip.removeFromSuperlayer() }
        band.add(sweep, forKey: "sheen")
        CATransaction.commit()
    }

    // MARK: Type

    /// A gold pill that springs in, holds, and floats away. A `subtitle`
    /// sits under the title in smaller type.
    func showCallout(_ text: String, subtitle: String? = nil, at point: CGPoint,
                     size: CGFloat, hold: TimeInterval) {
        guard let overlay else { return }
        let label = UILabel()
        let words = NSMutableAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size * style.typeScale, weight: .black),
            .kern: 2.2,
            .foregroundColor: Self.ink
        ])
        if let subtitle {
            words.append(NSAttributedString(string: "\n" + subtitle, attributes: [
                .font: UIFont.systemFont(ofSize: size * 0.52 * style.typeScale, weight: .heavy),
                .kern: 1.6,
                .foregroundColor: Self.ink.withAlphaComponent(0.72)
            ]))
            label.numberOfLines = 2
        }
        label.attributedText = words
        label.textAlignment = .center
        label.sizeToFit()
        let pill = UIView(frame: label.bounds.insetBy(dx: -16, dy: subtitle == nil ? -8 : -10))
        pill.backgroundColor = gold
        pill.layer.cornerRadius = subtitle == nil ? pill.bounds.height / 2 : 18
        pill.layer.cornerCurve = .continuous
        pill.layer.shadowColor = gold.cgColor
        pill.layer.shadowOpacity = 0.7
        pill.layer.shadowRadius = 14
        pill.layer.shadowOffset = .zero
        pill.isUserInteractionEnabled = false
        label.center = CGPoint(x: pill.bounds.midX, y: pill.bounds.midY)
        pill.addSubview(label)
        pill.center = point
        overlay.addSubview(pill)

        pill.transform = CGAffineTransform(scaleX: 0.3, y: 0.3).rotated(by: -0.12)
        pill.alpha = 0
        UIView.animate(withDuration: 0.5, delay: 0.04, usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.8, options: []) {
            pill.transform = CGAffineTransform(rotationAngle: -0.05)
            pill.alpha = 1
        }
        UIView.animate(withDuration: 0.3, delay: hold, options: [.curveEaseIn]) {
            pill.alpha = 0
            pill.transform = CGAffineTransform(translationX: 0, y: -14).rotated(by: -0.05)
        } completion: { _ in
            pill.removeFromSuperview()
        }
    }

    /// A score number that pops in and floats away — Balatro's "+chips".
    func floatText(_ text: String, at point: CGPoint) {
        guard let overlay else { return }
        let label = UILabel()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 24 * style.typeScale, weight: .black),
            .foregroundColor: gold,
            .strokeColor: Self.ink,
            .strokeWidth: -3
        ])
        label.sizeToFit()
        label.center = point
        overlay.addSubview(label)
        label.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.8, options: []) {
            label.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
        UIView.animate(withDuration: 0.85, delay: 0.1, options: [.curveEaseOut]) {
            label.center.y -= 46
        }
        UIView.animate(withDuration: 0.35, delay: 0.6, options: [.curveEaseIn]) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }

    // MARK: Particles

    enum Bit {
        case shard, spark, dot, pip(Suit)
        /// A casino chip seen from above.
        case chip
        /// A strip of confetti.
        case confetti
    }

    /// Sparks thrown all the way round at a burst — from behind `card`, so
    /// its face stays readable.
    func sparks(at point: CGPoint, width: CGFloat, behind card: UIView?) {
        var bits: [(Bit, UIColor, CGFloat)] = []
        bits += Array(repeating: (.spark, gold, 16), count: 16)
        bits += Array(repeating: (.spark, .white, 11), count: 8)
        bits += Array(repeating: (.dot, gold, 6), count: 12)
        throwBits(bits.shuffled(), from: point, across: width * 0.4,
                  toward: -.pi / 2, spread: .pi, distance: 90...175, fall: 60,
                  duration: 0.7...1.1, below: card?.layer)
    }

    /// Throws each bit out along its own angle — spread evenly across the
    /// fan with a little jitter, so they never clump — then lets it arc down
    /// under gravity, spinning, shrinking and fading.
    func throwBits(_ bits: [(Bit, UIColor, CGFloat)], from point: CGPoint, across width: CGFloat,
                   toward direction: CGFloat, spread: CGFloat, distance: ClosedRange<CGFloat>,
                   fall: CGFloat, duration: ClosedRange<Double>, below sibling: CALayer?) {
        guard let overlay else { return }
        let hairline = style.hairline.resolvedColor(with: overlay.traitCollection).cgColor
        for (index, bit) in bits.enumerated() {
            let layer = shape(bit.0, color: bit.1, size: bit.2, hairline: hairline)
            let origin = CGPoint(x: point.x + CGFloat.random(in: -width / 2...width / 2), y: point.y)
            let share = bits.count > 1 ? CGFloat(index) / CGFloat(bits.count - 1) : 0.5
            let angle = direction - spread + 2 * spread * share + CGFloat.random(in: -0.12...0.12)
            let reach = CGFloat.random(in: distance)
            let apex = CGPoint(x: origin.x + cos(angle) * reach, y: origin.y + sin(angle) * reach)
            let land = CGPoint(x: apex.x + cos(angle) * reach * 0.25, y: apex.y + fall)
            // A quadratic arc whose midpoint is the apex.
            let control = CGPoint(x: 2 * apex.x - (origin.x + land.x) / 2,
                                  y: 2 * apex.y - (origin.y + land.y) / 2)
            let arc = UIBezierPath()
            arc.move(to: origin)
            arc.addQuadCurve(to: land, controlPoint: control)

            layer.position = land
            layer.opacity = 0
            if let sibling, sibling.superlayer === overlay.layer {
                overlay.layer.insertSublayer(layer, below: sibling)
            } else {
                overlay.layer.addSublayer(layer)
            }

            let move = CAKeyframeAnimation(keyPath: "position")
            move.path = arc.cgPath
            move.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.45, 1)
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]
            fade.keyTimes = [0, 0.55, 1]
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.random(in: -7...7)
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1
            shrink.toValue = 0.45
            let group = CAAnimationGroup()
            group.animations = [move, fade, spin, shrink]
            group.duration = Double.random(in: duration)
            CATransaction.begin()
            CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
            layer.add(group, forKey: "throw")
            CATransaction.commit()
        }
    }

    /// Confetti falling from above the screen, drifting and tumbling —
    /// Clash Royale's legendary shower.
    func confetti(colors: [UIColor], count: Int, duration: ClosedRange<Double>) {
        guard let overlay, !reduceMotion else { return }
        let hairline = style.hairline.resolvedColor(with: overlay.traitCollection).cgColor
        let width = overlay.bounds.width
        for index in 0..<count {
            let layer = shape(.confetti, color: colors[index % colors.count],
                              size: CGFloat.random(in: 9...14), hairline: hairline)
            let x = width * (CGFloat(index) + CGFloat.random(in: 0.1...0.9)) / CGFloat(count)
            let start = CGPoint(x: x, y: -20 - CGFloat.random(in: 0...80))
            let end = CGPoint(x: x + CGFloat.random(in: -60...60), y: overlay.bounds.height * CGFloat.random(in: 0.55...0.95))
            layer.position = end
            layer.opacity = 0
            overlay.layer.addSublayer(layer)

            let fall = CABasicAnimation(keyPath: "position")
            fall.fromValue = NSValue(cgPoint: start)
            fall.toValue = NSValue(cgPoint: end)
            fall.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.1, 0.6, 1)
            let sway = CAKeyframeAnimation(keyPath: "transform.translation.x")
            sway.values = [0, 14, -12, 10, 0].map { $0 * CGFloat.random(in: 0.5...1.2) }
            sway.isAdditive = true
            let tumble = CABasicAnimation(keyPath: "transform.rotation.z")
            tumble.fromValue = 0
            tumble.toValue = CGFloat.random(in: -9...9)
            let flip = CAKeyframeAnimation(keyPath: "transform.scale.y")
            flip.values = [1, -1, 1, -1, 1]
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]
            fade.keyTimes = [0, 0.75, 1]
            let group = CAAnimationGroup()
            group.animations = [fall, sway, tumble, flip, fade]
            group.duration = Double.random(in: duration)
            group.beginTime = CACurrentMediaTime() + Double.random(in: 0...0.35)
            group.fillMode = .backwards
            CATransaction.begin()
            CATransaction.setCompletionBlock { layer.removeFromSuperlayer() }
            layer.add(group, forKey: "confetti")
            CATransaction.commit()
        }
    }

    /// A spark left behind by something flying past.
    func trailSpark(at point: CGPoint, size: CGFloat) {
        guard let overlay else { return }
        let spark = CAShapeLayer()
        spark.path = path(for: .spark, size: size)
        spark.fillColor = gold.cgColor
        spark.position = point
        spark.opacity = 0
        overlay.layer.addSublayer(spark)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.fromValue = 1
        shrink.toValue = 0.2
        let group = CAAnimationGroup()
        group.animations = [fade, shrink]
        group.duration = 0.38
        CATransaction.begin()
        CATransaction.setCompletionBlock { spark.removeFromSuperlayer() }
        spark.add(group, forKey: "trail")
        CATransaction.commit()
    }

    func shape(_ bit: Bit, color: UIColor, size: CGFloat, hairline: CGColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = path(for: bit, size: size)
        layer.fillColor = color.cgColor
        switch bit {
        case .shard, .confetti:
            layer.strokeColor = hairline        // stays visible on a light table
            layer.lineWidth = 0.6
        case .chip:
            // The chip's edge spots.
            let spots = CAShapeLayer()
            spots.path = chipSpots(size: size)
            spots.fillColor = UIColor.white.withAlphaComponent(0.85).cgColor
            layer.addSublayer(spots)
            layer.strokeColor = UIColor.black.withAlphaComponent(0.18).cgColor
            layer.lineWidth = 0.6
        default:
            break
        }
        return layer
    }

    func path(for bit: Bit, size: CGFloat) -> CGPath {
        switch bit {
        case .shard:
            return UIBezierPath(roundedRect: CGRect(x: -size * 0.35, y: -size / 2, width: size * 0.7, height: size),
                                cornerRadius: size * 0.15).cgPath
        case .spark:
            return CardBackView.sparkle(at: .zero, size: size / 2).cgPath
        case .dot, .chip:
            return UIBezierPath(ovalIn: CGRect(x: -size / 2, y: -size / 2, width: size, height: size)).cgPath
        case .pip(let suit):
            let box = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
            return SuitView.path(for: SuitView.glyph(for: suit), in: box).cgPath
        case .confetti:
            return UIBezierPath(roundedRect: CGRect(x: -size * 0.22, y: -size / 2, width: size * 0.44, height: size),
                                cornerRadius: size * 0.08).cgPath
        }
    }

    /// Six notches round a chip's rim.
    private func chipSpots(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let r = size / 2
        for i in 0..<6 {
            let angle = CGFloat(i) / 6 * 2 * .pi
            let c = CGPoint(x: cos(angle) * r * 0.74, y: sin(angle) * r * 0.74)
            path.append(UIBezierPath(ovalIn: CGRect(x: c.x - r * 0.16, y: c.y - r * 0.16,
                                                    width: r * 0.32, height: r * 0.32)))
        }
        return path.cgPath
    }

    // MARK: Helpers

    func animate(_ layer: CALayer, key: String, from: Float, to: Float, duration: TimeInterval,
                 timing: CAMediaTimingFunctionName, completion: (() -> Void)? = nil) {
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timing)
        layer.setValue(to, forKeyPath: key)
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        layer.add(animation, forKey: key)
        CATransaction.commit()
    }

    func point(onQuad a: CGPoint, _ c: CGPoint, _ b: CGPoint, at t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                       y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }
}
