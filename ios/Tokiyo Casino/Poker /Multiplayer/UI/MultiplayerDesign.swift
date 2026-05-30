//
//  MultiplayerDesign.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Shared design tokens + atoms for the multiplayer + Texas Hold'em
//  setup screens, mirroring the Claude Design handoff bundle
//  (poker/project/Multiplayer.html). Every color is a dynamic
//  (light, dark) pair so the app follows the system theme — no manual
//  toggle, no `overrideUserInterfaceStyle`.
//
//  Light palette  — warm parchment cream (private library at golden hour)
//  Dark palette   — tuxedo navy-black with cool ink + brass-gold accents
//                   (black-tie poker room at midnight)
//

import UIKit

// MARK: - Theme tokens (dynamic light/dark)

enum MPTheme {
    // Page surface (used as backdrop for the radial gradient)
    static let pageBgTop  = UIColor.dyn(light: 0xF8F0DA, dark: 0x1A2230)
    static let pageBg     = UIColor.dyn(light: 0xF2EAD2, dark: 0x0E1218)
    static let pageBgEdge = UIColor.dyn(light: 0xE2D5A8, dark: 0x06080C)
    // Table felts (recessed slots, scan circle)
    static let felt       = UIColor.dyn(light: 0xEDE2C4, dark: 0x161B23)
    static let feltDepth  = UIColor.dyn(light: 0xE0D2A6, dark: 0x080B11)
    static let feltEdge   = UIColor.dyn(light: 0xD6C68F, dark: 0x1E2530)
    // Ink (foreground text)
    static let ink   = UIColor.dyn(light: 0x1F1A12, dark: 0xEEF0F2)
    static let muted = UIColor.dyn(light: 0x8C8369, dark: 0x838C9A)
    static let faint = UIColor.dyn(light: 0xB5A883, dark: 0x444C58)
    // Borders
    static let border = UIColor.dyn(
        lightRGBA: (31, 26, 18, 0.09),
        darkRGBA:  (220, 230, 245, 0.10)
    )
    static let borderStrong = UIColor.dyn(
        lightRGBA: (31, 26, 18, 0.16),
        darkRGBA:  (220, 230, 245, 0.22)
    )
    // Accents — gold/coral/forest read on both themes
    static let coral      = UIColor.dyn(light: 0xD5604E, dark: 0xE8786A)
    static let coralDeep  = UIColor.dyn(light: 0xB84A3A, dark: 0xC95A4E)
    static let forest     = UIColor.dyn(light: 0x5E9466, dark: 0x7BB07A)
    static let forestDeep = UIColor.dyn(light: 0x4B7B53, dark: 0x5E8A60)
    static let amber      = UIColor.dyn(light: 0xC99540, dark: 0xD9B26A)
    static let amberDeep  = UIColor.dyn(light: 0xA87723, dark: 0xA8853E)
    // Primary controls use the same amber as selected player pills.
    static let primaryAction = UIColor.dyn(light: 0xC99540, dark: 0xD9B26A)
    static let primaryActionText = UIColor.dyn(light: 0x3B2A0E, dark: 0x3B2A0E)
    // Card-back medallion (open seats)
    static let cardBack   = UIColor.dyn(light: 0xC9A674, dark: 0x2A3245)
    static let cardBackBg = UIColor.dyn(light: 0xF5E6C8, dark: 0x141823)
    // Glass chrome (pills, buttons, badges)
    static let glass = UIColor.dyn(
        lightRGBA: (255, 255, 255, 0.85),
        darkRGBA:  (220, 230, 245, 0.10)
    )
    static let glassWeak = UIColor.dyn(
        lightRGBA: (255, 255, 255, 0.70),
        darkRGBA:  (220, 230, 245, 0.06)
    )
    static let glassMedium = UIColor.dyn(
        lightRGBA: (255, 255, 255, 0.78),
        darkRGBA:  (220, 230, 245, 0.08)
    )
    static let glassDivider = UIColor.dyn(
        lightRGBA: (31, 26, 18, 0.09),
        darkRGBA:  (220, 230, 245, 0.12)
    )
    // Live status pill
    static let liveBg = UIColor.dyn(
        lightRGBA: (255, 255, 255, 0.85),
        darkRGBA:  (220, 230, 245, 0.10)
    )
    static let liveFg = UIColor.dyn(light: 0x4B7B53, dark: 0xD9B26A)
    // iOS-style tinted button (Cancel etc.) — sage in light, brass in dark
    static let tint = UIColor.dyn(light: 0x4B7B53, dark: 0xD9B26A)
    // Toggle switch (off track)
    static let toggleOff = UIColor.dyn(
        lightRGBA: (237, 226, 196, 1.0),
        darkRGBA:  (220, 230, 245, 0.10)
    )
    // Toggle handle (knob)
    static let toggleHandle = UIColor.dyn(light: 0xFFFFFF, dark: 0xEEF0F2)
    // Host gold-wash band
    static let hostWash = UIColor.dyn(
        lightRGBA: (201, 149, 64, 0.22),
        darkRGBA:  (217, 178, 106, 0.14)
    )
    // White noise grain dot
    static let grainDot = UIColor.dyn(
        lightRGBA: (60, 45, 15, 0.025),
        darkRGBA:  (180, 195, 220, 0.020)
    )
}

// MARK: - Typography

/// Display: iOS New York (a true contemporary garalde — far closer to
/// Cormorant Garamond than Georgia). UI: SF system. We never bundle
/// Cormorant/Manrope so this is the right native fallback.
enum MPFont {
    // Every text style on the Texas Hold'em setup + multiplayer screens funnels
    // through these three helpers, so multiplying by `DeviceLayout.fontScale`
    // here is the single lever that enlarges all of that type on iPad while
    // leaving iPhone (fontScale == 1) byte-for-byte unchanged.
    static func display(_ size: CGFloat, weight: UIFont.Weight = .medium) -> UIFont {
        displayRaw(size * DeviceLayout.fontScale, weight: weight)
    }
    /// Serif display font at an exact point size, bypassing `fontScale` — for
    /// callers (e.g. the mini-deck) that already apply their own scale factor.
    static func displayRaw(_ size: CGFloat, weight: UIFont.Weight = .medium) -> UIFont {
        // UIFontDescriptor.SystemDesign.serif → New York on iOS 13+.
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let desc = base.fontDescriptor.withDesign(.serif) {
            return UIFont(descriptor: desc, size: size)
        }
        return base
    }
    static func ui(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size * DeviceLayout.fontScale, weight: weight)
    }
    static func uiTabular(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let size = size * DeviceLayout.fontScale
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let desc = base.fontDescriptor.addingAttributes([
            .featureSettings: [
                [UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                 UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]
            ]
        ])
        return UIFont(descriptor: desc, size: size)
    }
}

// MARK: - Page background (radial gradient, trait-aware)

/// Tuxedo / parchment radial-gradient backdrop. Resolves the colors
/// fresh every time the trait collection changes so it follows
/// light/dark automatically.
final class MPPageBackgroundView: UIView {
    private let gradient = CAGradientLayer()
    private let grain = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.type = .radial
        gradient.locations = [0.0, 0.38, 1.0]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint   = CGPoint(x: 1.0, y: 1.2)
        layer.addSublayer(gradient)
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.pageBg
        let resolved = traitCollection
        gradient.colors = [
            MPTheme.pageBgTop.resolvedColor(with: resolved).cgColor,
            MPTheme.pageBg.resolvedColor(with: resolved).cgColor,
            MPTheme.pageBgEdge.resolvedColor(with: resolved).cgColor,
        ]
    }
}

// MARK: - Real poker chip (notched edge)

/// Mirrors the React Chip — concentric ring with notches, glossy pip on top.
/// Trait-aware shadow + pip so the chip reads on either backdrop.
final class MPChipView: UIView {
    private let outer = CAShapeLayer()
    private let ring = CAShapeLayer()
    private let notches = CAReplicatorLayer()
    private let notch = CALayer()
    private let pip = CAShapeLayer()
    private let highlight = CAGradientLayer()

    private var fillColor: UIColor
    private var ringColor: UIColor

    init(size: CGFloat, color: UIColor, ringColor: UIColor = .white) {
        self.fillColor = color
        self.ringColor = ringColor
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = .clear

        layer.addSublayer(outer)
        layer.addSublayer(ring)

        let n = 8
        notches.instanceCount = n
        notches.instanceTransform = CATransform3DMakeRotation(.pi * 2 / CGFloat(n), 0, 0, 1)
        notches.addSublayer(notch)
        layer.addSublayer(notches)

        layer.addSublayer(pip)
        pip.addSublayer(highlight)
        highlight.type = .radial
        highlight.startPoint = CGPoint(x: 0.35, y: 0.30)
        highlight.endPoint = CGPoint(x: 0.95, y: 0.95)

        applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setColor(_ color: UIColor) {
        self.fillColor = color
        applyColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let s = min(bounds.width, bounds.height)
        let rect = CGRect(x: (bounds.width - s)/2, y: (bounds.height - s)/2, width: s, height: s)

        outer.frame = bounds
        outer.path = UIBezierPath(ovalIn: rect).cgPath

        let ringInset = s * 0.29
        ring.frame = bounds
        let ringRect = rect.insetBy(dx: ringInset, dy: ringInset)
        let ringPath = UIBezierPath(ovalIn: ringRect)
        ring.path = ringPath.cgPath
        ring.lineWidth = max(2, s * 0.06)
        ring.fillColor = UIColor.clear.cgColor

        notches.frame = bounds
        notch.bounds = CGRect(x: 0, y: 0, width: max(3, s * 0.11), height: s * 0.92)
        notch.position = CGPoint(x: bounds.midX, y: bounds.midY)
        notches.position = CGPoint(x: bounds.midX, y: bounds.midY)
        notches.cornerRadius = s / 2
        notches.masksToBounds = true

        let pipInset = s * 0.22
        let pipRect = rect.insetBy(dx: pipInset, dy: pipInset)
        pip.frame = bounds
        pip.path = UIBezierPath(ovalIn: pipRect).cgPath
        pip.lineWidth = 1

        highlight.frame = pipRect
        let mask = CAShapeLayer()
        mask.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: pipRect.size)).cgPath
        highlight.mask = mask
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        outer.fillColor = fillColor.cgColor
        outer.strokeColor = UIColor.black.withAlphaComponent(isDark ? 0.30 : 0.14).cgColor
        outer.lineWidth = 1
        ring.strokeColor = ringColor.withAlphaComponent(0.85).cgColor
        notch.backgroundColor = ringColor.withAlphaComponent(0.85).cgColor
        pip.fillColor = fillColor.cgColor
        pip.strokeColor = ringColor.withAlphaComponent(0.5).cgColor
        highlight.colors = [
            UIColor.white.withAlphaComponent(0.55).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
        ]
        highlight.locations = [0.0, 0.55]

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Float(isDark ? 0.55 : 0.22)
        layer.shadowOffset = CGSize(width: 0, height: isDark ? 4 : 3)
        layer.shadowRadius = isDark ? 8 : 5
    }
}

// MARK: - Card-back medallion (empty seats)

final class SeatHolePatternView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        setNeedsDisplay()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.cardBackBg
        let isDark = traitCollection.userInterfaceStyle == .dark
        alpha = isDark ? 0.75 : 0.85
        layer.borderColor = MPTheme.cardBack.withAlphaComponent(0.55).cgColor
        layer.borderWidth = 1.5
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.width / 2
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(MPTheme.cardBack.cgColor)
        // 4x diagonal hatched diamond pattern — eight tiny squares per
        // step, rotated 45° to read as a card-back damask.
        let tile: CGFloat = 6
        let path = UIBezierPath()
        var y: CGFloat = -tile
        while y < rect.height + tile {
            var x: CGFloat = -tile
            while x < rect.width + tile {
                let cell = CGRect(x: x, y: y, width: tile * 0.5, height: tile * 0.5)
                let square = UIBezierPath(rect: cell)
                let rot = CGAffineTransform(translationX: cell.midX, y: cell.midY)
                    .rotated(by: .pi / 4)
                    .translatedBy(x: -cell.midX, y: -cell.midY)
                square.apply(rot)
                path.append(square)
                x += tile
            }
            y += tile
        }
        path.fill()
    }
}

// MARK: - Sonar (Nearby loading)

final class MPSonarView: UIView {
    private var ringLayers: [CAShapeLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        for _ in 0..<3 {
            let l = CAShapeLayer()
            l.fillColor = UIColor.clear.cgColor
            l.strokeColor = MPTheme.amber.cgColor
            l.lineWidth = 1.5
            l.opacity = 0
            layer.addSublayer(l)
            ringLayers.append(l)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 20
        let rect = bounds.insetBy(dx: inset, dy: inset)
        for l in ringLayers {
            l.frame = bounds
            l.path = UIBezierPath(ovalIn: rect).cgPath
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        for l in ringLayers { l.strokeColor = MPTheme.amber.cgColor }
    }

    func start() {
        for (i, l) in ringLayers.enumerated() {
            l.removeAllAnimations()
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.20
            scale.toValue = 1.0
            scale.duration = 2.6
            scale.repeatCount = .infinity
            scale.beginTime = CACurrentMediaTime() + Double(i) * 0.87
            scale.isRemovedOnCompletion = false

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 0.45, 0]
            opacity.keyTimes = [0, 0.1, 1.0]
            opacity.duration = 2.6
            opacity.repeatCount = .infinity
            opacity.beginTime = CACurrentMediaTime() + Double(i) * 0.87
            opacity.isRemovedOnCompletion = false

            l.add(scale, forKey: "scale")
            l.add(opacity, forKey: "opacity")
        }
    }

    func stop() { ringLayers.forEach { $0.removeAllAnimations() } }
}

// MARK: - Live dot (sage with pulse halo)

final class MPLiveDot: UIView {
    private let core = CAShapeLayer()
    private let pulse = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyColors()
        layer.addSublayer(core)
        layer.addSublayer(pulse)

        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 0.8
        anim.toValue = 2.6
        anim.duration = 1.8
        anim.repeatCount = .infinity

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.8
        opacity.toValue = 0
        opacity.duration = 1.8
        opacity.repeatCount = .infinity

        pulse.add(anim, forKey: "scale")
        pulse.add(opacity, forKey: "opacity")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyColors()
    }

    private func applyColors() {
        core.fillColor = MPTheme.forest.cgColor
        core.shadowColor = MPTheme.forest.cgColor
        core.shadowRadius = 3
        core.shadowOpacity = 0.9
        core.shadowOffset = .zero
        pulse.fillColor = UIColor.clear.cgColor
        pulse.strokeColor = MPTheme.forest.cgColor
        pulse.lineWidth = 1.5
        pulse.opacity = 0.6
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let dot = bounds.insetBy(dx: 1, dy: 1)
        core.path = UIBezierPath(ovalIn: dot).cgPath
        pulse.frame = bounds
        pulse.path = UIBezierPath(ovalIn: bounds.insetBy(dx: -2, dy: -2)).cgPath
    }
}

// MARK: - Live badge ("Live · 1 of 6")

final class MPLiveBadge: UIView {
    private let dot = MPLiveDot()
    private let label = UILabel()

    init(text: String) {
        super.init(frame: .zero)
        backgroundColor = MPTheme.liveBg
        layer.cornerRadius = 999
        layer.borderColor = MPTheme.border.cgColor
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        dot.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dot)
        addSubview(label)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 28),
        ])
        setText(text)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = MPTheme.border.cgColor
        if let t = label.attributedText?.string { setText(t) }
    }

    func setText(_ value: String) {
        label.attributedText = NSAttributedString(string: value.uppercased(), attributes: [
            .kern: 1.2,
            .font: MPFont.ui(10, weight: .bold),
            .foregroundColor: MPTheme.liveFg,
        ])
    }
}

// MARK: - Title (eyebrow + display heading + subtitle)

final class MPTitleView: UIView {
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let subtitleStack = UIStackView()
    private let subtitleLabel = UILabel()

    private var eyebrowText: String
    private var titleText: String
    private var subtitleText: String?

    init(eyebrow: String, title: String, subtitle: String?, showLiveDot: Bool = false) {
        self.eyebrowText = eyebrow
        self.titleText = title
        self.subtitleText = subtitle
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        self.eyebrow.textAlignment = .center
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        titleLabel.numberOfLines = 1
        subtitleLabel.textAlignment = .center

        subtitleStack.axis = .horizontal
        subtitleStack.alignment = .center
        subtitleStack.spacing = 8
        subtitleStack.distribution = .fill
        if showLiveDot {
            let dot = MPLiveDot()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            subtitleStack.addArrangedSubview(dot)
        }
        subtitleStack.addArrangedSubview(subtitleLabel)

        let v = UIStackView(arrangedSubviews: [self.eyebrow, titleLabel])
        v.axis = .vertical
        v.alignment = .center
        v.spacing = 6
        if subtitle != nil {
            v.setCustomSpacing(8, after: titleLabel)
            v.addArrangedSubview(subtitleStack)
        }
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: topAnchor),
            v.leadingAnchor.constraint(equalTo: leadingAnchor),
            v.trailingAnchor.constraint(equalTo: trailingAnchor),
            v.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        applyText()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyText()
    }

    func setSubtitle(_ value: String) {
        subtitleText = value
        applyText()
    }

    private func applyText() {
        eyebrow.attributedText = NSAttributedString(string: eyebrowText.uppercased(), attributes: [
            .kern: 1.8,
            .foregroundColor: MPTheme.muted,
            .font: MPFont.ui(10, weight: .bold),
        ])
        titleLabel.attributedText = NSAttributedString(string: titleText, attributes: [
            .font: MPFont.display(44, weight: .medium),
            .foregroundColor: MPTheme.ink,
            .kern: -0.7, // ≈ -0.02em
        ])
        subtitleLabel.attributedText = NSAttributedString(string: subtitleText ?? "", attributes: [
            .font: MPFont.ui(13.5, weight: .medium),
            .foregroundColor: MPTheme.muted,
        ])
    }
}

// MARK: - Cancel button (iOS-style tinted text)

final class MPCancelButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("Cancel", for: .normal)
        titleLabel?.font = MPFont.ui(16, weight: .medium)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        applyTint()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTint()
    }

    private func applyTint() {
        setTitleColor(MPTheme.tint, for: .normal)
    }
}

func mpCancelButton(target: Any?, action: Selector) -> MPCancelButton {
    let b = MPCancelButton()
    b.translatesAutoresizingMaskIntoConstraints = false
    b.addTarget(target, action: action, for: .touchUpInside)
    return b
}

// MARK: - Back chevron pill (matches the design's circular back button)

final class MPBackPill: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = MPTheme.glass
        layer.cornerRadius = 22
        layer.borderColor = MPTheme.border.cgColor
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        applyTint()
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = MPTheme.border.cgColor
        backgroundColor = MPTheme.glass
        applyTint()
    }

    private func applyTint() {
        tintColor = MPTheme.ink
    }
}

enum MPNavigationChrome {
    static func hideSystemBackBar(for viewController: UIViewController, animated: Bool) {
        viewController.navigationItem.title = ""
        viewController.navigationItem.hidesBackButton = true
        viewController.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    static func restoreSystemBackBarIfLeaving(_ viewController: UIViewController, animated: Bool) {
        guard viewController.isMovingFromParent || viewController.isBeingDismissed else { return }
        viewController.navigationItem.hidesBackButton = false
        viewController.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Gear pill

final class MPGearPill: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = MPTheme.glass
        layer.cornerRadius = 22
        layer.borderColor = MPTheme.border.cgColor
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        setImage(UIImage(systemName: "gearshape", withConfiguration: cfg), for: .normal)
        applyTint()
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        layer.borderColor = MPTheme.border.cgColor
        backgroundColor = MPTheme.glass
        applyTint()
    }

    private func applyTint() { tintColor = MPTheme.ink }
}

// MARK: - Primary CTA (warm parchment pill)

final class MPPrimaryButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = MPFont.ui(16, weight: .bold)
        layer.cornerRadius = 16
        layer.masksToBounds = false

        applyPrimaryStyle()
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 58).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyPrimaryStyle()
    }

    private func applyPrimaryStyle() {
        let resolved = traitCollection
        backgroundColor = MPTheme.primaryAction
        setTitleColor(MPTheme.primaryActionText, for: .normal)
        layer.shadowColor = MPTheme.primaryAction.resolvedColor(with: resolved).cgColor
        layer.shadowOpacity = resolved.userInterfaceStyle == .dark ? 0.30 : 0.36
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 14
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.55 }
    }
}

final class MPCompactPrimaryButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = MPFont.ui(12, weight: .heavy)
        contentEdgeInsets = UIEdgeInsets(top: 9, left: 16, bottom: 9, right: 16)
        layer.cornerRadius = 999
        layer.borderWidth = 1
        applyPrimaryStyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isEnabled: Bool {
        didSet { applyPrimaryStyle() }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyPrimaryStyle()
    }

    private func applyPrimaryStyle() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        if isEnabled {
            setTitleColor(MPTheme.primaryActionText, for: .normal)
            backgroundColor = MPTheme.primaryAction
            layer.borderColor = UIColor.clear.cgColor
            layer.shadowColor = MPTheme.primaryAction.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = Float(isDark ? 0.38 : 0.30)
            layer.shadowOffset = CGSize(width: 0, height: 4)
            layer.shadowRadius = 8
        } else {
            setTitleColor(MPTheme.faint, for: .normal)
            backgroundColor = MPTheme.glassWeak
            layer.borderColor = MPTheme.border.cgColor
            layer.shadowOpacity = 0
        }
    }
}

// MARK: - Secondary CTA (glass pill)

final class MPSecondaryButton: UIButton {
    init(title: String, leadingIcon: UIImage? = nil) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = MPFont.ui(16, weight: .bold)

        if let icon = leadingIcon {
            setImage(icon.withRenderingMode(.alwaysTemplate), for: .normal)
            imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
            titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        }

        layer.cornerRadius = 16
        layer.borderWidth = 1.5
        applyTheme()

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 58).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.glassMedium
        setTitleColor(MPTheme.ink, for: .normal)
        tintColor = MPTheme.ink
        layer.borderColor = MPTheme.borderStrong.cgColor
        layer.shadowColor = UIColor.black.cgColor
        let isDark = traitCollection.userInterfaceStyle == .dark
        layer.shadowOpacity = Float(isDark ? 0.40 : 0.10)
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
    }
}

// MARK: - Identity chip ("Playing as X | Change")

final class MPIdentityChip: UIButton {
    private let chip = MPChipView(size: 28, color: .clear)
    private let nameLabel = UILabel()
    private let separator = UIView()
    private let changeLabel = UILabel()

    var name: String = "Player" {
        didSet { rebuildText() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 999
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        chip.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        changeLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(chip)
        addSubview(nameLabel)
        addSubview(separator)
        addSubview(changeLabel)

        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            chip.centerYAnchor.constraint(equalTo: centerYAnchor),
            chip.widthAnchor.constraint(equalToConstant: 28),
            chip.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 10),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 14),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor),

            changeLabel.leadingAnchor.constraint(equalTo: separator.trailingAnchor, constant: 10),
            changeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            changeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 40),
        ])

        applyTheme()
        rebuildText()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        rebuildText()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.glassWeak
        layer.borderColor = MPTheme.border.cgColor
        separator.backgroundColor = MPTheme.glassDivider
        chip.setColor(MPTheme.amber)
    }

    private func rebuildText() {
        let attr = NSMutableAttributedString(
            string: "Playing as ",
            attributes: [
                .font: MPFont.ui(13.5, weight: .semibold),
                .foregroundColor: MPTheme.ink,
            ]
        )
        attr.append(NSAttributedString(string: name, attributes: [
            .font: MPFont.ui(13.5, weight: .heavy),
            .foregroundColor: MPTheme.ink,
        ]))
        nameLabel.attributedText = attr

        changeLabel.attributedText = NSAttributedString(string: "Change name", attributes: [
            .font: MPFont.ui(13.5, weight: .heavy),
            .foregroundColor: MPTheme.tint,
        ])
    }
}

// MARK: - Chip-tray ornament (3 chips inside a recessed felt arc)

final class MPChipTrayOrnament: UIView {
    private let tray = UIView()
    private let chipCoral: MPChipView
    private let chipForest: MPChipView
    private let chipAmber: MPChipView

    override init(frame: CGRect) {
        chipCoral = MPChipView(size: 46, color: MPTheme.coral)
        chipForest = MPChipView(size: 50, color: MPTheme.forest)
        chipAmber = MPChipView(size: 46, color: MPTheme.amber)

        super.init(frame: frame)
        tray.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tray)
        applyTheme()

        [chipCoral, chipForest, chipAmber].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            tray.addSubview($0)
        }

        NSLayoutConstraint.activate([
            tray.topAnchor.constraint(equalTo: topAnchor),
            tray.bottomAnchor.constraint(equalTo: bottomAnchor),
            tray.centerXAnchor.constraint(equalTo: centerXAnchor),
            tray.widthAnchor.constraint(equalToConstant: 220),
            tray.heightAnchor.constraint(equalToConstant: 90),

            chipForest.centerXAnchor.constraint(equalTo: tray.centerXAnchor),
            chipForest.centerYAnchor.constraint(equalTo: tray.centerYAnchor),
            chipForest.widthAnchor.constraint(equalToConstant: 50),
            chipForest.heightAnchor.constraint(equalToConstant: 50),

            chipCoral.trailingAnchor.constraint(equalTo: chipForest.leadingAnchor, constant: 18),
            chipCoral.centerYAnchor.constraint(equalTo: tray.centerYAnchor),
            chipCoral.widthAnchor.constraint(equalToConstant: 46),
            chipCoral.heightAnchor.constraint(equalToConstant: 46),

            chipAmber.leadingAnchor.constraint(equalTo: chipForest.trailingAnchor, constant: -18),
            chipAmber.centerYAnchor.constraint(equalTo: tray.centerYAnchor),
            chipAmber.widthAnchor.constraint(equalToConstant: 46),
            chipAmber.heightAnchor.constraint(equalToConstant: 46),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        tray.layer.cornerRadius = tray.bounds.height / 2
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        tray.backgroundColor = MPTheme.feltDepth
        let isDark = traitCollection.userInterfaceStyle == .dark
        tray.layer.shadowColor = UIColor.black.cgColor
        tray.layer.shadowOpacity = Float(isDark ? 0.55 : 0.18)
        tray.layer.shadowOffset = CGSize(width: 0, height: 4)
        tray.layer.shadowRadius = 10
        chipCoral.setColor(MPTheme.coral)
        chipForest.setColor(MPTheme.forest)
        chipAmber.setColor(MPTheme.amber)
    }
}

// MARK: - Seat slot (recessed felt slot with chip medallion)

final class MPSeatSlot: UIView {

    enum Kind {
        case host(name: String, isDealer: Bool)
        case occupied(name: String, isAI: Bool, isDealer: Bool)
        case open
    }

    private let chipView: MPChipView
    private let openMedallion = SeatHolePatternView()
    private let dealerBadge = UILabel()
    private let dealerBadgeBg = UIView()
    private let eyebrow = UILabel()
    private let nameLabel = UILabel()
    private let trailingView: UIView
    private let hostRail = UIView()
    private weak var washLayer: CAGradientLayer?
    private let kind: Kind

    init(seatNumber: Int, kind: Kind) {
        self.kind = kind
        switch kind {
        case .host:
            chipView = MPChipView(size: 36, color: MPTheme.amber)
            trailingView = MPSeatSlot.makeHostPill()
        case .occupied:
            chipView = MPChipView(size: 36, color: UIColor(hex: 0x5A7AA8))
            trailingView = UIView()
        case .open:
            chipView = MPChipView(size: 36, color: MPTheme.amber)
            trailingView = MPSeatSlot.makeWaitingPill()
        }

        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        clipsToBounds = false

        // Recess outline
        let recess = UIView()
        recess.translatesAutoresizingMaskIntoConstraints = false
        recess.layer.cornerRadius = 14
        recess.isUserInteractionEnabled = false
        recess.layer.borderWidth = 1
        addSubview(recess)
        NSLayoutConstraint.activate([
            recess.topAnchor.constraint(equalTo: topAnchor),
            recess.leadingAnchor.constraint(equalTo: leadingAnchor),
            recess.trailingAnchor.constraint(equalTo: trailingAnchor),
            recess.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        self.recessLayer = recess

        // Host rail (gold left stripe)
        hostRail.layer.cornerRadius = 2
        hostRail.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostRail)

        chipView.translatesAutoresizingMaskIntoConstraints = false
        openMedallion.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chipView)
        addSubview(openMedallion)

        dealerBadgeBg.translatesAutoresizingMaskIntoConstraints = false
        dealerBadgeBg.layer.cornerRadius = 8
        addSubview(dealerBadgeBg)
        dealerBadge.text = "D"
        dealerBadge.textAlignment = .center
        dealerBadge.font = MPFont.ui(9, weight: .heavy)
        dealerBadge.translatesAutoresizingMaskIntoConstraints = false
        dealerBadgeBg.addSubview(dealerBadge)
        NSLayoutConstraint.activate([
            dealerBadge.centerXAnchor.constraint(equalTo: dealerBadgeBg.centerXAnchor),
            dealerBadge.centerYAnchor.constraint(equalTo: dealerBadgeBg.centerYAnchor),
        ])

        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(eyebrow)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        trailingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trailingView)

        var dealerVisible = false
        var openVisible = false
        var hostRailVisible = false
        var eyebrowTail = ""
        var nameText = ""
        var nameItalic = false

        switch kind {
        case .host(let name, let isDealer):
            hostRailVisible = true
            dealerVisible = isDealer
            eyebrowTail = isDealer ? " · DEALER" : ""
            nameText = name
            let wash = CAGradientLayer()
            wash.startPoint = CGPoint(x: 0, y: 0.5)
            wash.endPoint = CGPoint(x: 0.5, y: 0.5)
            wash.frame = bounds
            layer.insertSublayer(wash, at: 0)
            self.washLayer = wash
        case .occupied(let name, let isAI, let isDealer):
            dealerVisible = isDealer
            eyebrowTail = isDealer ? " · DEALER" : (isAI ? " · AI" : "")
            nameText = name
        case .open:
            openVisible = true
            nameText = "Open"
            nameItalic = true
        }

        chipView.isHidden = openVisible
        openMedallion.isHidden = !openVisible
        dealerBadgeBg.isHidden = !dealerVisible
        hostRail.isHidden = !hostRailVisible

        let eyebrowText = "SEAT \(seatNumber)\(eyebrowTail)"
        eyebrow.attributedText = NSAttributedString(string: eyebrowText, attributes: [
            .kern: 1.0,
            .font: MPFont.ui(10, weight: .bold),
            .foregroundColor: MPTheme.muted,
        ])

        if nameItalic {
            nameLabel.font = MPFont.display(17, weight: .medium)
            nameLabel.textColor = MPTheme.muted
        } else {
            nameLabel.font = MPFont.ui(15, weight: .heavy)
            nameLabel.textColor = MPTheme.ink
        }
        nameLabel.text = nameText

        NSLayoutConstraint.activate([
            hostRail.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            hostRail.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hostRail.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            hostRail.widthAnchor.constraint(equalToConstant: 3),

            chipView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            chipView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chipView.widthAnchor.constraint(equalToConstant: 36),
            chipView.heightAnchor.constraint(equalToConstant: 36),

            openMedallion.leadingAnchor.constraint(equalTo: chipView.leadingAnchor),
            openMedallion.topAnchor.constraint(equalTo: chipView.topAnchor),
            openMedallion.trailingAnchor.constraint(equalTo: chipView.trailingAnchor),
            openMedallion.bottomAnchor.constraint(equalTo: chipView.bottomAnchor),

            dealerBadgeBg.widthAnchor.constraint(equalToConstant: 16),
            dealerBadgeBg.heightAnchor.constraint(equalToConstant: 16),
            dealerBadgeBg.trailingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: 3),
            dealerBadgeBg.bottomAnchor.constraint(equalTo: chipView.bottomAnchor, constant: 3),

            eyebrow.leadingAnchor.constraint(equalTo: chipView.trailingAnchor, constant: 12),
            eyebrow.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            nameLabel.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            nameLabel.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 1),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingView.leadingAnchor, constant: -8),

            trailingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            trailingView.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 56),
        ])

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    private weak var recessLayer: UIView?
    override func layoutSubviews() {
        super.layoutSubviews()
        washLayer?.frame = bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = MPTheme.feltDepth
        layer.borderColor = UIColor.black.withAlphaComponent(isDark ? 0.40 : 0.06).cgColor
        recessLayer?.layer.borderColor = UIColor.white.withAlphaComponent(isDark ? 0.04 : 0.55).cgColor

        hostRail.backgroundColor = MPTheme.amber
        hostRail.layer.shadowColor = MPTheme.amber.cgColor
        hostRail.layer.shadowOpacity = Float(isDark ? 0.55 : 0.30)
        hostRail.layer.shadowRadius = 6
        hostRail.layer.shadowOffset = .zero

        dealerBadgeBg.backgroundColor = MPTheme.ink
        dealerBadgeBg.layer.borderColor = MPTheme.borderStrong.cgColor
        dealerBadgeBg.layer.borderWidth = 1
        dealerBadge.textColor = MPTheme.feltDepth

        // Refresh chip/wash colors
        switch kind {
        case .host: chipView.setColor(MPTheme.amber)
        case .occupied: chipView.setColor(UIColor(hex: 0x5A7AA8))
        case .open: chipView.setColor(MPTheme.amber)
        }
        washLayer?.colors = [
            MPTheme.hostWash.resolvedColor(with: traitCollection).cgColor,
            UIColor.clear.cgColor,
        ]
        // Refresh eyebrow / name colors (attributed text uses resolved
        // colors at creation; recreate so light/dark flip cleanly).
        if let t = eyebrow.attributedText?.string {
            eyebrow.attributedText = NSAttributedString(string: t, attributes: [
                .kern: 1.0,
                .font: MPFont.ui(10, weight: .bold),
                .foregroundColor: MPTheme.muted,
            ])
        }
        switch kind {
        case .open:
            nameLabel.textColor = MPTheme.muted
        default:
            nameLabel.textColor = MPTheme.ink
        }
    }

    private static func makeWaitingPill() -> UIView {
        let v = UIStackView()
        v.axis = .horizontal
        v.spacing = 5
        v.alignment = .center

        let dot = UIView()
        dot.backgroundColor = MPTheme.faint.withAlphaComponent(0.6)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 2.5
        dot.widthAnchor.constraint(equalToConstant: 5).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 5).isActive = true

        let label = UILabel()
        label.attributedText = NSAttributedString(string: "WAITING", attributes: [
            .kern: 0.6,
            .font: MPFont.ui(10, weight: .bold),
            .foregroundColor: MPTheme.faint,
        ])

        v.addArrangedSubview(dot)
        v.addArrangedSubview(label)
        return v
    }

    private static func makeHostPill() -> UIView {
        let pill = UILabel()
        pill.attributedText = NSAttributedString(string: "HOST · YOU", attributes: [
            .kern: 1.0,
            .font: MPFont.ui(9.5, weight: .heavy),
            .foregroundColor: MPTheme.amber,
        ])
        pill.textAlignment = .center
        pill.backgroundColor = MPTheme.amber.withAlphaComponent(0.15)
        pill.layer.cornerRadius = 999
        pill.layer.borderColor = MPTheme.amber.withAlphaComponent(0.40).cgColor
        pill.layer.borderWidth = 1
        pill.layer.masksToBounds = true
        pill.translatesAutoresizingMaskIntoConstraints = false
        let wrap = UIView()
        wrap.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 4),
            pill.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -4),
            pill.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 9),
            pill.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -9),
        ])
        return wrap
    }
}

// MARK: - Stepper pill (Blinds, Buy-in, Seats)

final class MPStepperPill: UIControl {
    private let labelTop = UILabel()
    private let valueLabel = UILabel()
    private let minusBtn = UIButton(type: .system)
    private let plusBtn = UIButton(type: .system)
    private let stepperContainer = UIView()
    private let labelText: String

    var onMinus: (() -> Void)?
    var onPlus: (() -> Void)?

    var minusEnabled: Bool = true { didSet { applyEnabled() } }
    var plusEnabled: Bool = true { didSet { applyEnabled() } }

    var value: String {
        get { valueLabel.text ?? "" }
        set { valueLabel.text = newValue }
    }

    init(label: String, value: String) {
        self.labelText = label
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        labelTop.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = value
        valueLabel.font = MPFont.uiTabular(15, weight: .bold)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(labelTop)
        addSubview(valueLabel)

        stepperContainer.layer.cornerRadius = 999
        stepperContainer.layer.borderWidth = 1
        stepperContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stepperContainer)

        configureStepBtn(minusBtn, symbol: "−")
        configureStepBtn(plusBtn, symbol: "+")
        minusBtn.addTarget(self, action: #selector(minusTapped), for: .touchUpInside)
        plusBtn.addTarget(self, action: #selector(plusTapped), for: .touchUpInside)

        let div = UIView()
        div.translatesAutoresizingMaskIntoConstraints = false
        stepperContainer.addSubview(minusBtn)
        stepperContainer.addSubview(div)
        stepperContainer.addSubview(plusBtn)
        self.divider = div

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),

            labelTop.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            labelTop.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.topAnchor.constraint(equalTo: labelTop.bottomAnchor, constant: 1),

            stepperContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stepperContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            stepperContainer.heightAnchor.constraint(equalToConstant: 30),

            minusBtn.leadingAnchor.constraint(equalTo: stepperContainer.leadingAnchor),
            minusBtn.topAnchor.constraint(equalTo: stepperContainer.topAnchor),
            minusBtn.bottomAnchor.constraint(equalTo: stepperContainer.bottomAnchor),
            minusBtn.widthAnchor.constraint(equalToConstant: 28),

            div.leadingAnchor.constraint(equalTo: minusBtn.trailingAnchor),
            div.centerYAnchor.constraint(equalTo: stepperContainer.centerYAnchor),
            div.widthAnchor.constraint(equalToConstant: 1),
            div.heightAnchor.constraint(equalToConstant: 14),

            plusBtn.leadingAnchor.constraint(equalTo: div.trailingAnchor),
            plusBtn.topAnchor.constraint(equalTo: stepperContainer.topAnchor),
            plusBtn.bottomAnchor.constraint(equalTo: stepperContainer.bottomAnchor),
            plusBtn.trailingAnchor.constraint(equalTo: stepperContainer.trailingAnchor),
            plusBtn.widthAnchor.constraint(equalToConstant: 28),
        ])

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    private weak var divider: UIView?

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        applyEnabled()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.glassMedium
        layer.borderColor = MPTheme.border.cgColor
        labelTop.attributedText = NSAttributedString(string: labelText.uppercased(), attributes: [
            .kern: 1.0,
            .font: MPFont.ui(9.5, weight: .bold),
            .foregroundColor: MPTheme.muted,
        ])
        valueLabel.textColor = MPTheme.ink
        stepperContainer.backgroundColor = MPTheme.feltDepth
        stepperContainer.layer.borderColor = MPTheme.border.cgColor
        divider?.backgroundColor = MPTheme.border
    }

    private func configureStepBtn(_ b: UIButton, symbol: String) {
        b.setTitle(symbol, for: .normal)
        b.titleLabel?.font = MPFont.ui(15, weight: .bold)
        b.translatesAutoresizingMaskIntoConstraints = false
    }

    private func applyEnabled() {
        minusBtn.isEnabled = minusEnabled
        plusBtn.isEnabled = plusEnabled
        minusBtn.setTitleColor(minusEnabled ? MPTheme.ink : MPTheme.faint, for: .normal)
        plusBtn.setTitleColor(plusEnabled ? MPTheme.ink : MPTheme.faint, for: .normal)
        minusBtn.alpha = minusEnabled ? 1 : 0.5
        plusBtn.alpha = plusEnabled ? 1 : 0.5
    }

    @objc private func minusTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onMinus?()
    }
    @objc private func plusTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onPlus?()
    }
}

// MARK: - Toggle pill (AI Fill)

final class MPTogglePill: UIControl {
    private let labelTop = UILabel()
    private let valueLabel = UILabel()
    private let track = UIView()
    private let trackGradient = CAGradientLayer()
    private let handle = UIView()
    private var handleLeading: NSLayoutConstraint!
    private let labelText: String

    var onValueChange: ((Bool) -> Void)?

    var isOn: Bool = false {
        didSet { applyState(animated: true) }
    }

    init(label: String, isOn: Bool) {
        self.labelText = label
        super.init(frame: .zero)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2

        labelTop.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = MPFont.ui(15, weight: .bold)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(labelTop)
        addSubview(valueLabel)

        track.translatesAutoresizingMaskIntoConstraints = false
        track.layer.cornerRadius = 13
        track.layer.borderWidth = 1
        addSubview(track)
        trackGradient.cornerRadius = 13
        trackGradient.startPoint = CGPoint(x: 0.5, y: 0)
        trackGradient.endPoint = CGPoint(x: 0.5, y: 1)
        track.layer.insertSublayer(trackGradient, at: 0)

        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.layer.cornerRadius = 11
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowOpacity = 0.30
        handle.layer.shadowOffset = CGSize(width: 0, height: 1)
        handle.layer.shadowRadius = 2
        track.addSubview(handle)

        handleLeading = handle.leadingAnchor.constraint(equalTo: track.leadingAnchor, constant: 2)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),

            labelTop.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            labelTop.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            valueLabel.topAnchor.constraint(equalTo: labelTop.bottomAnchor, constant: 1),

            track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            track.centerYAnchor.constraint(equalTo: centerYAnchor),
            track.widthAnchor.constraint(equalToConstant: 42),
            track.heightAnchor.constraint(equalToConstant: 26),

            handle.topAnchor.constraint(equalTo: track.topAnchor, constant: 2),
            handle.widthAnchor.constraint(equalToConstant: 22),
            handle.heightAnchor.constraint(equalToConstant: 22),
            handleLeading,
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleTapped))
        addGestureRecognizer(tap)

        self.isOn = isOn
        applyTheme()
        applyState(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        trackGradient.frame = track.bounds
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        applyState(animated: false)
    }

    private func applyTheme() {
        backgroundColor = MPTheme.glassMedium
        layer.borderColor = MPTheme.border.cgColor
        labelTop.attributedText = NSAttributedString(string: labelText.uppercased(), attributes: [
            .kern: 1.0,
            .font: MPFont.ui(9.5, weight: .bold),
            .foregroundColor: MPTheme.muted,
        ])
        valueLabel.textColor = MPTheme.ink
        handle.backgroundColor = MPTheme.toggleHandle
    }

    @objc private func toggleTapped() {
        isOn.toggle()
        onValueChange?(isOn)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func applyState(animated: Bool) {
        valueLabel.text = isOn ? "On" : "Off"
        handleLeading.constant = isOn ? 18 : 2
        let resolved = traitCollection
        let apply: () -> Void = {
            if self.isOn {
                self.track.backgroundColor = .clear
                self.trackGradient.isHidden = false
                self.trackGradient.colors = [
                    MPTheme.forest.resolvedColor(with: resolved).cgColor,
                    MPTheme.forestDeep.resolvedColor(with: resolved).cgColor,
                ]
                self.track.layer.borderColor = UIColor.clear.cgColor
                self.track.layer.borderWidth = 0
            } else {
                self.track.backgroundColor = MPTheme.toggleOff
                self.trackGradient.isHidden = true
                self.track.layer.borderColor = MPTheme.border.cgColor
                self.track.layer.borderWidth = 1
            }
            self.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: apply)
        } else {
            apply()
        }
    }
}

// MARK: - Section eyebrow ("GAME")

func mpSectionEyebrow(_ text: String) -> UILabel {
    MPSectionEyebrowLabel(text: text)
}

final class MPSectionEyebrowLabel: UILabel {
    private let raw: String
    init(text: String) {
        self.raw = text
        super.init(frame: .zero)
        apply()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        apply()
    }
    private func apply() {
        attributedText = NSAttributedString(string: raw.uppercased(), attributes: [
            .kern: 1.4,
            .font: MPFont.ui(10, weight: .bold),
            .foregroundColor: MPTheme.muted,
        ])
    }
}

// MARK: - Nearby table slot row (Screen D)

final class MPTableSlot: UIView {

    private let chip: MPChipView
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let joinButton: MPCompactPrimaryButton
    private let chipColor: UIColor
    private let fullState: Bool
    private let hostName: String
    private let players: Int
    private let maxPlayers: Int
    private let blinds: String
    private let buyIn: Int?

    var onJoin: (() -> Void)?

    init(host: String, players: Int, max: Int, blinds: String, buyIn: Int?, chipColor: UIColor) {
        let full = players >= max
        self.fullState = full
        self.chipColor = chipColor
        self.hostName = host
        self.players = players
        self.maxPlayers = max
        self.blinds = blinds
        self.buyIn = buyIn
        self.chip = MPChipView(size: 40, color: chipColor)
        self.joinButton = MPCompactPrimaryButton(title: full ? "FULL" : "JOIN")
        super.init(frame: .zero)

        layer.cornerRadius = 14
        layer.borderWidth = 1

        chip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chip)

        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(eyebrow)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(metaLabel)

        joinButton.translatesAutoresizingMaskIntoConstraints = false
        if !full {
            joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
        } else {
            joinButton.isEnabled = false
        }
        addSubview(joinButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 76),

            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            chip.centerYAnchor.constraint(equalTo: centerYAnchor),
            chip.widthAnchor.constraint(equalToConstant: 40),
            chip.heightAnchor.constraint(equalToConstant: 40),

            eyebrow.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 12),
            eyebrow.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: joinButton.leadingAnchor, constant: -8),

            metaLabel.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            metaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            metaLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: joinButton.leadingAnchor, constant: -8),

            joinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            joinButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = MPTheme.feltDepth
        layer.borderColor = UIColor.black.withAlphaComponent(isDark ? 0.40 : 0.06).cgColor

        chip.setColor(chipColor)

        eyebrow.attributedText = NSAttributedString(
            string: (fullState ? "TABLE FULL" : "OPEN TABLE"),
            attributes: [
                .kern: 1.0,
                .font: MPFont.ui(10, weight: .bold),
                .foregroundColor: MPTheme.muted,
            ]
        )
        titleLabel.attributedText = NSAttributedString(
            string: "\(hostName)'s Table",
            attributes: [
                .font: MPFont.display(22, weight: .medium),
                .foregroundColor: MPTheme.ink,
                .kern: -0.3,
            ])

        let meta = NSMutableAttributedString()
        meta.append(NSAttributedString(string: "\(players)/\(maxPlayers)", attributes: [
            .font: MPFont.uiTabular(11.5, weight: .bold),
            .foregroundColor: MPTheme.ink,
        ]))
        meta.append(NSAttributedString(string: "  ·  ", attributes: [
            .font: MPFont.ui(11.5),
            .foregroundColor: MPTheme.faint,
        ]))
        meta.append(NSAttributedString(string: "Blinds \(blinds)", attributes: [
            .font: MPFont.uiTabular(11.5),
            .foregroundColor: MPTheme.muted,
        ]))
        if let b = buyIn {
            let f = NumberFormatter(); f.numberStyle = .decimal
            meta.append(NSAttributedString(string: "  ·  ", attributes: [
                .font: MPFont.ui(11.5),
                .foregroundColor: MPTheme.faint,
            ]))
            meta.append(NSAttributedString(string: "$\(f.string(from: NSNumber(value: b)) ?? "\(b)")",
                                           attributes: [
                .font: MPFont.uiTabular(11.5),
                .foregroundColor: MPTheme.muted,
            ]))
        }
        metaLabel.attributedText = meta

        if fullState {
            joinButton.isEnabled = false
        } else {
            joinButton.isEnabled = true
        }
    }

    @objc private func joinTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onJoin?()
    }
}

// MARK: - Mini deck (Screen E — 3 fanned playing cards)

/// Three white playing cards (A♠, K♥, Q♦) fanned out, each with a centered
/// rank + suit glyph. Matches the JSX MiniDeck.
final class MPMiniDeck: UIView {

    private struct Card {
        let rank: String
        let suit: Suit
        let dx: CGFloat
        let dy: CGFloat
        let rot: CGFloat
        let z: Int
    }
    private enum Suit { case spade, heart, diamond }

    private var cardViews: [UIView] = []

    /// Geometry multiplier. iPhone stays 1.0 (so the fanned deck is identical);
    /// iPad enlarges the whole hero deck — cards, glyphs and the view's own
    /// intrinsic size all grow together, so it reads as artwork rather than a
    /// thumbnail next to the big title.
    private let scale: CGFloat

    init(scale: CGFloat = DeviceLayout.pick(1.0, pad: 1.5)) {
        self.scale = scale
        super.init(frame: .zero)
        let cards: [Card] = [
            Card(rank: "A", suit: .spade,   dx: -46, dy: 12, rot: -14 * .pi / 180, z: 1),
            Card(rank: "K", suit: .heart,   dx:   0, dy:  0, rot:   0,             z: 3),
            Card(rank: "Q", suit: .diamond, dx:  46, dy: 12, rot:  14 * .pi / 180, z: 2),
        ]
        for c in cards {
            let v = buildCard(rank: c.rank, suit: c.suit, isRed: c.suit != .spade)
            v.layer.zPosition = CGFloat(c.z)
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
            NSLayoutConstraint.activate([
                v.widthAnchor.constraint(equalToConstant: 70 * scale),
                v.heightAnchor.constraint(equalToConstant: 100 * scale),
                v.centerXAnchor.constraint(equalTo: centerXAnchor, constant: c.dx * scale),
                v.topAnchor.constraint(equalTo: topAnchor, constant: c.dy * scale),
            ])
            // Rotate around bottom-center, matching the JSX transform origin
            v.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
            v.transform = CGAffineTransform(rotationAngle: c.rot)
            cardViews.append(v)
        }
        translatesAutoresizingMaskIntoConstraints = false
        // Self-size off `scale` so the host doesn't have to pin a width/height
        // (which previously collided with this one on iPad).
        widthAnchor.constraint(equalToConstant: 200 * scale).isActive = true
        heightAnchor.constraint(equalToConstant: 104 * scale).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Refresh card shadow based on theme
        let isDark = traitCollection.userInterfaceStyle == .dark
        for v in cardViews {
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOpacity = Float(isDark ? 0.55 : 0.25)
            v.layer.shadowOffset = CGSize(width: 0, height: isDark ? 10 : 8)
            v.layer.shadowRadius = isDark ? 22 : 18
        }
    }

    private func buildCard(rank: String, suit: Suit, isRed: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 9 * scale
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.45
        card.layer.shadowOffset = CGSize(width: 0, height: 10)
        card.layer.shadowRadius = 22

        let inkColor: UIColor = isRed
            ? UIColor(red: 225/255, green: 61/255, blue: 68/255, alpha: 1)
            : UIColor(red:  26/255, green: 26/255, blue: 31/255, alpha: 1)

        let rankLabel = UILabel()
        rankLabel.text = rank
        // Raw point size (×scale) — not MPFont, so the deck scales off its own
        // geometry factor rather than the global iPad type bump.
        rankLabel.font = MPFont.displayRaw(32 * scale, weight: .semibold)
        rankLabel.textColor = inkColor
        rankLabel.translatesAutoresizingMaskIntoConstraints = false

        let suitGlyph = SuitGlyphView(suit: suit, color: inkColor)
        suitGlyph.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rankLabel)
        card.addSubview(suitGlyph)
        NSLayoutConstraint.activate([
            rankLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            rankLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18 * scale),

            suitGlyph.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            suitGlyph.topAnchor.constraint(equalTo: rankLabel.bottomAnchor, constant: 4 * scale),
            suitGlyph.widthAnchor.constraint(equalToConstant: 20 * scale),
            suitGlyph.heightAnchor.constraint(equalToConstant: 20 * scale),
        ])
        return card
    }

    private final class SuitGlyphView: UIView {
        private let suit: Suit
        private let inkColor: UIColor
        init(suit: Suit, color: UIColor) {
            self.suit = suit
            self.inkColor = color
            super.init(frame: .zero)
            backgroundColor = .clear
            isOpaque = false
        }
        required init?(coder: NSCoder) { fatalError() }
        override func draw(_ rect: CGRect) {
            inkColor.setFill()
            let unit = min(rect.width, rect.height) / 24.0
            let ox = (rect.width - 24*unit) / 2
            let oy = (rect.height - 24*unit) / 2
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x*unit, y: oy + y*unit)
            }
            let path = UIBezierPath()
            switch suit {
            case .heart:
                path.move(to: p(12, 21))
                path.addCurve(to: p(2, 8.5),  controlPoint1: p(8, 18),     controlPoint2: p(2, 14))
                path.addCurve(to: p(7.5, 3),  controlPoint1: p(2, 5.5),    controlPoint2: p(4.2, 3))
                path.addCurve(to: p(12, 5.8), controlPoint1: p(9.6, 3),    controlPoint2: p(11.2, 4.2))
                path.addCurve(to: p(16.5, 3), controlPoint1: p(12.8, 4.2), controlPoint2: p(14.4, 3))
                path.addCurve(to: p(22, 8.5), controlPoint1: p(19.8, 3),   controlPoint2: p(22, 5.5))
                path.addCurve(to: p(12, 21),  controlPoint1: p(22, 14),    controlPoint2: p(16, 18))
                path.close()
            case .diamond:
                path.move(to: p(12, 2))
                path.addLine(to: p(21, 12))
                path.addLine(to: p(12, 22))
                path.addLine(to: p(3, 12))
                path.close()
            case .spade:
                path.move(to: p(12, 2))
                path.addCurve(to: p(22, 16.5), controlPoint1: p(12, 8),  controlPoint2: p(22, 11))
                path.addCurve(to: p(16, 22),   controlPoint1: p(22, 20), controlPoint2: p(19, 22))
                path.addCurve(to: p(12, 19),   controlPoint1: p(14, 22), controlPoint2: p(12.5, 21))
                path.addCurve(to: p(8, 22),    controlPoint1: p(11.5, 21), controlPoint2: p(10, 22))
                path.addCurve(to: p(2, 16.5),  controlPoint1: p(5, 22),  controlPoint2: p(2, 20))
                path.addCurve(to: p(12, 2),    controlPoint1: p(2, 11),  controlPoint2: p(12, 8))
                path.close()
                path.move(to: p(11, 19))
                path.addLine(to: p(8, 23))
                path.addLine(to: p(16, 23))
                path.addLine(to: p(13, 19))
                path.close()
            }
            path.fill()
        }
    }
}

// MARK: - Player picker (Screen E — segmented number picker 2…8)

/// Segmented control where the selected option becomes a gold poker chip
/// (matches the JSX PlayerPicker).
final class MPPlayerPicker: UIControl {

    private let track = UIView()
    private var options: [Int]
    private var buttons: [UIButton] = []
    private(set) var value: Int

    var onChange: ((Int) -> Void)?

    init(value: Int, options: [Int] = [2, 3, 4, 5, 6]) {
        self.options = options
        self.value = value
        super.init(frame: .zero)
        track.layer.cornerRadius = 999
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 60),
        ])

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        track.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: track.topAnchor),
            stack.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: track.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: track.bottomAnchor),
        ])

        for n in options {
            let b = UIButton(type: .system)
            b.tag = n
            b.titleLabel?.font = MPFont.ui(16, weight: .heavy)
            b.addTarget(self, action: #selector(numTapped(_:)), for: .touchUpInside)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(b)
            buttons.append(b)
        }
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    @objc private func numTapped(_ sender: UIButton) {
        value = sender.tag
        applyTheme()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onChange?(value)
        sendActions(for: .valueChanged)
    }

    private func applyTheme() {
        track.backgroundColor = MPTheme.feltDepth
        for b in buttons {
            let isSelected = (b.tag == value)
            b.setTitle("\(b.tag)", for: .normal)
            if isSelected {
                // Render as a small gold chip
                b.backgroundColor = MPTheme.amber
                b.layer.cornerRadius = 22
                b.layer.borderColor = MPTheme.amber.withAlphaComponent(0.7).cgColor
                b.layer.borderWidth = 2
                b.layer.shadowColor = MPTheme.amber.cgColor
                b.layer.shadowOpacity = 0.45
                b.layer.shadowOffset = CGSize(width: 0, height: 6)
                b.layer.shadowRadius = 12
                b.setTitleColor(UIColor(hex: 0x3B2A0E), for: .normal)
                b.titleLabel?.font = MPFont.ui(16, weight: .heavy)
            } else {
                b.backgroundColor = .clear
                b.layer.cornerRadius = 22
                b.layer.borderWidth = 0
                b.layer.shadowOpacity = 0
                b.setTitleColor(MPTheme.muted, for: .normal)
                b.titleLabel?.font = MPFont.ui(14, weight: .bold)
            }
        }
    }
}

// MARK: - Difficulty picker (Screen E — same rail/chip treatment as player count)

final class MPDifficultyPicker: UIControl {

    private let track = UIView()
    private let stack = UIStackView()
    private let options: [Difficulty]
    private var buttons: [UIButton] = []
    private(set) var value: Difficulty

    init(value: Difficulty, options: [Difficulty] = Difficulty.allCases) {
        self.value = value
        self.options = options
        super.init(frame: .zero)

        track.layer.cornerRadius = 999
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)

        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        track.addSubview(stack)

        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 60),

            stack.topAnchor.constraint(equalTo: track.topAnchor),
            stack.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: track.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: track.bottomAnchor),
        ])

        for (index, difficulty) in options.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitle(difficulty.displayName, for: .normal)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.78
            button.titleLabel?.lineBreakMode = .byClipping
            button.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    func setValue(_ newValue: Difficulty, animated: Bool) {
        guard newValue != value else {
            applyTheme()
            return
        }
        value = newValue
        if animated {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseInOut]) {
                self.applyTheme()
            }
        } else {
            applyTheme()
        }
    }

    @objc private func optionTapped(_ sender: UIButton) {
        guard options.indices.contains(sender.tag) else { return }
        let selected = options[sender.tag]
        guard selected != value else { return }
        setValue(selected, animated: true)
        sendActions(for: .valueChanged)
    }

    private func applyTheme() {
        track.backgroundColor = MPTheme.feltDepth
        for (index, button) in buttons.enumerated() {
            guard options.indices.contains(index) else { continue }
            let isSelected = options[index] == value
            if isSelected {
                button.backgroundColor = MPTheme.amber
                button.layer.cornerRadius = 22
                button.layer.borderColor = MPTheme.amber.withAlphaComponent(0.7).cgColor
                button.layer.borderWidth = 2
                button.layer.shadowColor = MPTheme.amber.cgColor
                button.layer.shadowOpacity = 0.45
                button.layer.shadowOffset = CGSize(width: 0, height: 6)
                button.layer.shadowRadius = 12
                button.setTitleColor(UIColor(hex: 0x3B2A0E), for: .normal)
                button.titleLabel?.font = MPFont.ui(15, weight: .heavy)
            } else {
                button.backgroundColor = .clear
                button.layer.cornerRadius = 22
                button.layer.borderWidth = 0
                button.layer.shadowOpacity = 0
                button.setTitleColor(MPTheme.muted, for: .normal)
                button.titleLabel?.font = MPFont.ui(14, weight: .bold)
            }
        }
    }
}

// MARK: - Chips slider (Screen E — gold chip thumb on a warm rail)

final class MPChipsSlider: UIControl {
    private let trackBg = UIView()
    private let trackFill = CALayer()
    private let thumb = MPChipView(size: 32, color: MPTheme.amber)
    private let minLabel = UILabel()
    private let maxLabel = UILabel()
    private let stepsContainer = UIView()
    private var stepDots: [UIView] = []

    private(set) var value: Int
    let steps: [Int]
    var minValue: Int { steps.first ?? 0 }
    var maxValue: Int { steps.last ?? 0 }

    var onChange: ((Int) -> Void)?

    /// Discrete-step slider: drag lands on the nearest entry in `steps`.
    /// Interim values are never produced.
    init(value: Int, steps: [Int]) {
        self.value = value
        self.steps = steps
        super.init(frame: .zero)

        trackBg.layer.cornerRadius = 7
        trackBg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackBg)

        trackFill.cornerRadius = 7
        trackBg.layer.addSublayer(trackFill)

        stepsContainer.translatesAutoresizingMaskIntoConstraints = false
        stepsContainer.isUserInteractionEnabled = false
        addSubview(stepsContainer)

        for _ in steps {
            let d = UIView()
            d.layer.cornerRadius = 1
            stepDots.append(d)
            stepsContainer.addSubview(d)
        }

        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.isUserInteractionEnabled = false
        addSubview(thumb)

        minLabel.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(minLabel)
        addSubview(maxLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 64),

            trackBg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            trackBg.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            trackBg.heightAnchor.constraint(equalToConstant: 14),
            trackBg.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            stepsContainer.leadingAnchor.constraint(equalTo: trackBg.leadingAnchor),
            stepsContainer.trailingAnchor.constraint(equalTo: trackBg.trailingAnchor),
            stepsContainer.centerYAnchor.constraint(equalTo: trackBg.centerYAnchor),
            stepsContainer.heightAnchor.constraint(equalToConstant: 6),

            thumb.centerYAnchor.constraint(equalTo: trackBg.centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 32),
            thumb.heightAnchor.constraint(equalToConstant: 32),

            minLabel.topAnchor.constraint(equalTo: trackBg.bottomAnchor, constant: 14),
            minLabel.leadingAnchor.constraint(equalTo: trackBg.leadingAnchor),

            maxLabel.topAnchor.constraint(equalTo: trackBg.bottomAnchor, constant: 14),
            maxLabel.trailingAnchor.constraint(equalTo: trackBg.trailingAnchor),
        ])
        thumbCenterX = thumb.centerXAnchor.constraint(equalTo: leadingAnchor)
        thumbCenterX.isActive = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    private var thumbCenterX: NSLayoutConstraint!

    override func layoutSubviews() {
        super.layoutSubviews()
        trackFill.frame = CGRect(x: 0, y: 0,
                                 width: trackBg.bounds.width * progress(),
                                 height: trackBg.bounds.height)
        // Position thumb
        let trackOriginX = trackBg.frame.origin.x
        thumbCenterX.constant = trackOriginX + trackBg.bounds.width * progress()
        // Step dots
        if !stepDots.isEmpty && stepDots.count == steps.count {
            let cw = stepsContainer.bounds.width
            for (i, dot) in stepDots.enumerated() {
                let p = CGFloat(i) / CGFloat(steps.count - 1)
                dot.frame = CGRect(x: cw * p - 1, y: 0, width: 2, height: 6)
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func progress() -> CGFloat {
        // Index-based: position along the discrete-step axis, not a
        // linear interpolation. The thumb sits exactly on each tick.
        guard steps.count > 1 else { return 0 }
        let idx = steps.firstIndex(of: value) ?? closestIndex(to: value)
        return CGFloat(idx) / CGFloat(steps.count - 1)
    }

    private func closestIndex(to v: Int) -> Int {
        var best = 0
        var bestDelta = Int.max
        for (i, s) in steps.enumerated() {
            let d = abs(s - v)
            if d < bestDelta { bestDelta = d; best = i }
        }
        return best
    }

    private func applyTheme() {
        let resolved = traitCollection
        let isDark = resolved.userInterfaceStyle == .dark
        trackBg.backgroundColor = MPTheme.feltDepth
        let fillColor = MPTheme.primaryAction.resolvedColor(with: resolved).cgColor
        trackFill.backgroundColor = fillColor
        for dot in stepDots {
            dot.backgroundColor = UIColor.black.withAlphaComponent(isDark ? 0.55 : 0.20)
        }
        thumb.setColor(MPTheme.amber)
        let f = NumberFormatter(); f.numberStyle = .decimal
        minLabel.attributedText = NSAttributedString(string: f.string(from: NSNumber(value: minValue)) ?? "\(minValue)", attributes: [
            .font: MPFont.uiTabular(11, weight: .semibold),
            .foregroundColor: MPTheme.muted,
        ])
        maxLabel.attributedText = NSAttributedString(string: f.string(from: NSNumber(value: maxValue)) ?? "\(maxValue)", attributes: [
            .font: MPFont.uiTabular(11, weight: .semibold),
            .foregroundColor: MPTheme.muted,
        ])
    }

    func setValue(_ v: Int, animated: Bool) {
        let snapped = steps.contains(v) ? v : steps[closestIndex(to: v)]
        guard snapped != value else { return }
        value = snapped
        let apply = {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        if animated { UIView.animate(withDuration: 0.1, animations: apply) } else { apply() }
        onChange?(value)
        sendActions(for: .valueChanged)
    }

    private func snap(at location: CGPoint) {
        guard steps.count > 1 else { return }
        let p = max(0, min(1, location.x / trackBg.bounds.width))
        let idx = Int(round(p * CGFloat(steps.count - 1)))
        setValue(steps[idx], animated: true)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        snap(at: g.location(in: trackBg))
    }
    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        snap(at: g.location(in: trackBg))
    }
}

// MARK: - "Coins available" pill (Screen E)

final class MPCoinsPill: UIView {
    private let chip = MPChipView(size: 18, color: MPTheme.amber)
    private let label = UILabel()
    private var amount: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 999
        layer.borderWidth = 1
        chip.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chip)
        addSubview(label)
        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            chip.centerYAnchor.constraint(equalTo: centerYAnchor),
            chip.widthAnchor.constraint(equalToConstant: 18),
            chip.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 26),
        ])
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    func setAmount(_ value: Int) {
        amount = value
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = MPTheme.glassWeak
        layer.borderColor = MPTheme.border.cgColor
        chip.setColor(MPTheme.amber)
        let f = NumberFormatter(); f.numberStyle = .decimal
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: f.string(from: NSNumber(value: amount)) ?? "\(amount)",
                                       attributes: [
            .font: MPFont.uiTabular(11, weight: .heavy),
            .foregroundColor: MPTheme.ink,
        ]))
        attr.append(NSAttributedString(string: " available", attributes: [
            .font: MPFont.ui(11, weight: .semibold),
            .foregroundColor: MPTheme.muted,
        ]))
        label.attributedText = attr
    }
}

// Note: UIColor(hex:) is provided by PokerDesign.swift; no need to redefine here.
