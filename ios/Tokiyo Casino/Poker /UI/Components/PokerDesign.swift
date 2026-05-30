//
//  PokerDesign.swift
//  Tokiyo Casino
//
//  Visual design tokens + shared atoms for the redesigned poker screen.
//  Mirrors the Claude Design handoff bundle (poker.jsx).
//

import UIKit

// MARK: - Theme tokens

enum PokerTheme {
    // Page / felt
    static let pageBg = UIColor.dyn(light: 0xF1E8D2, dark: 0x16140E)
    static let felt = UIColor.dyn(light: 0xEDE2C4, dark: 0x1F261C)
    static let feltEdge = UIColor.dyn(light: 0xDBCDA6, dark: 0x161B14)

    // Text / surface
    static let ink = UIColor.dyn(light: 0x1F1A12, dark: 0xF2EAD0)
    static let muted = UIColor.dyn(light: 0x8C8369, dark: 0x988E73)
    static let surface = UIColor.white
    static let surfaceAlt = UIColor.dyn(light: 0xF7EFD9, dark: 0x23211A)
    static let border = UIColor.dyn(lightRGBA: (31, 26, 18, 0.09),
                                    darkRGBA:  (230, 205, 140, 0.10))
    static let borderStrong = UIColor.dyn(lightRGBA: (31, 26, 18, 0.16),
                                          darkRGBA:  (230, 205, 140, 0.20))
    static let glass = UIColor.dyn(lightRGBA: (255, 255, 255, 0.85),
                                   darkRGBA:  (255, 255, 255, 0.10))
    static let betPillSurface = UIColor.dyn(light: .white,
                                            dark: UIColor.white.withAlphaComponent(0.92))

    // Accents
    static let coral = UIColor.dyn(light: 0xD5604E, dark: 0xE8786A)
    static let coralDeep = UIColor.dyn(light: 0xB84A3A, dark: 0xC95A4E)
    static let forest = UIColor.dyn(light: 0x5E9466, dark: 0x7BB07A)
    static let forestDeep = UIColor.dyn(light: 0x4B7B53, dark: 0x5E8A60)
    static let amber = UIColor.dyn(light: 0xC99540, dark: 0xD9A958)
    static let primaryAction = UIColor.dyn(light: 0xC99540, dark: 0xD9A958)
    static let primaryActionText = UIColor.dyn(light: 0x2E220D, dark: 0x241A0A)
    static let warn = UIColor.dyn(light: 0xC24A4A, dark: 0xD86056)

    // Card back
    static let cardBack = UIColor.dyn(light: 0xC9A674, dark: 0x3D462E)
    static let cardBackBg = UIColor.dyn(light: 0xF5E6C8, dark: 0x1F2418)

    // Suit ink (red suits use this, black suits use ink)
    static let suitRed = UIColor(red: 225/255, green: 61/255, blue: 68/255, alpha: 1)
    static let suitBlack = UIColor(red: 26/255, green: 26/255, blue: 31/255, alpha: 1)

    // Chip palette (matches design — chip color used for bet pills)
    enum Chip {
        static let blue = UIColor.dyn(light: 0x3FA8D9, dark: 0x4FB5DD)
        static let purple = UIColor.dyn(light: 0x7B5FE8, dark: 0x9B7FFF)
        static let red = UIColor.dyn(light: 0xC9564E, dark: 0xD8665E)
        static let gold = UIColor.dyn(light: 0xC99540, dark: 0xD9A958)
        static let green = UIColor.dyn(light: 0x5E9466, dark: 0x7BB07A)
    }

    // Shadow helpers (apply to a CALayer)
    static func applyShadowSm(_ layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.10
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
    }
    static func applyShadowMd(_ layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 10
    }
    static func applyShadowLg(_ layer: CALayer) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 22
    }
}

// MARK: - Color helpers

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8)  & 0xFF) / 255.0,
            blue:  CGFloat( hex        & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    static func dyn(light: UInt32, dark: UInt32) -> UIColor {
        let l = UIColor(hex: light)
        let d = UIColor(hex: dark)
        return UIColor { trait in
            trait.userInterfaceStyle == .dark ? d : l
        }
    }
    static func dyn(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light }
    }
    static func dyn(lightRGBA: (CGFloat, CGFloat, CGFloat, CGFloat),
                    darkRGBA: (CGFloat, CGFloat, CGFloat, CGFloat)) -> UIColor {
        let l = UIColor(red: lightRGBA.0/255, green: lightRGBA.1/255, blue: lightRGBA.2/255, alpha: lightRGBA.3)
        let d = UIColor(red:  darkRGBA.0/255, green:  darkRGBA.1/255, blue:  darkRGBA.2/255, alpha:  darkRGBA.3)
        return UIColor { trait in trait.userInterfaceStyle == .dark ? d : l }
    }
}

// MARK: - Suit pictogram view

/// Draws a clean filled suit glyph at any size, using the same outlines as poker.jsx.
final class SuitView: UIView {
    enum Glyph { case spade, heart, diamond, club }

    var glyph: Glyph = .spade { didSet { shape.path = Self.path(for: glyph, in: bounds).cgPath; setNeedsDisplay() } }
    var color: UIColor = PokerTheme.suitBlack { didSet { shape.fillColor = color.cgColor } }

    private let shape = CAShapeLayer()

    convenience init(glyph: Glyph, color: UIColor) {
        self.init(frame: .zero)
        self.glyph = glyph
        self.color = color
        shape.fillColor = color.cgColor
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(shape)
        shape.fillColor = color.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
        shape.path = Self.path(for: glyph, in: bounds).cgPath
    }

    static func path(for glyph: Glyph, in rect: CGRect) -> UIBezierPath {
        // All glyph paths are designed in a 24×24 viewport (matches poker.jsx)
        let unit = min(rect.width, rect.height) / 24.0
        let ox = (rect.width  - 24 * unit) / 2
        let oy = (rect.height - 24 * unit) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * unit, y: oy + y * unit)
        }
        let path = UIBezierPath()
        switch glyph {
        case .heart:
            // M12 21 C8 18 2 14 2 8.5 C2 5.5 4.2 3 7.5 3 C9.6 3 11.2 4.2 12 5.8 C12.8 4.2 14.4 3 16.5 3 C19.8 3 22 5.5 22 8.5 C22 14 16 18 12 21 Z
            path.move(to: p(12, 21))
            path.addCurve(to: p(2, 8.5),    controlPoint1: p(8, 18),     controlPoint2: p(2, 14))
            path.addCurve(to: p(7.5, 3),    controlPoint1: p(2, 5.5),    controlPoint2: p(4.2, 3))
            path.addCurve(to: p(12, 5.8),   controlPoint1: p(9.6, 3),    controlPoint2: p(11.2, 4.2))
            path.addCurve(to: p(16.5, 3),   controlPoint1: p(12.8, 4.2), controlPoint2: p(14.4, 3))
            path.addCurve(to: p(22, 8.5),   controlPoint1: p(19.8, 3),   controlPoint2: p(22, 5.5))
            path.addCurve(to: p(12, 21),    controlPoint1: p(22, 14),    controlPoint2: p(16, 18))
            path.close()
        case .diamond:
            // M12 2 L21 12 L12 22 L3 12 Z
            path.move(to: p(12, 2))
            path.addLine(to: p(21, 12))
            path.addLine(to: p(12, 22))
            path.addLine(to: p(3, 12))
            path.close()
        case .spade:
            // M12 2 C12 8 22 11 22 16.5 C22 20 19 22 16 22 C14 22 12.5 21 12 19 C11.5 21 10 22 8 22 C5 22 2 20 2 16.5 C2 11 12 8 12 2 Z + stem
            path.move(to: p(12, 2))
            path.addCurve(to: p(22, 16.5), controlPoint1: p(12, 8),  controlPoint2: p(22, 11))
            path.addCurve(to: p(16, 22),   controlPoint1: p(22, 20), controlPoint2: p(19, 22))
            path.addCurve(to: p(12, 19),   controlPoint1: p(14, 22), controlPoint2: p(12.5, 21))
            path.addCurve(to: p(8, 22),    controlPoint1: p(11.5, 21), controlPoint2: p(10, 22))
            path.addCurve(to: p(2, 16.5),  controlPoint1: p(5, 22),  controlPoint2: p(2, 20))
            path.addCurve(to: p(12, 2),    controlPoint1: p(2, 11),  controlPoint2: p(12, 8))
            path.close()
            // Stem: M11 19 L8 23 L16 23 L13 19 Z
            path.move(to: p(11, 19))
            path.addLine(to: p(8, 23))
            path.addLine(to: p(16, 23))
            path.addLine(to: p(13, 19))
            path.close()
        case .club:
            // Three circles + stem (simplified analogue of the JSX club path)
            // Top circle r ~ 3.5 at (12, 7.5)
            path.append(UIBezierPath(ovalIn: CGRect(x: ox + 8.5*unit, y: oy + 4*unit, width: 7*unit, height: 7*unit)))
            // Left circle at (6.5, 13.5)
            path.append(UIBezierPath(ovalIn: CGRect(x: ox + 3*unit, y: oy + 10*unit, width: 7*unit, height: 7*unit)))
            // Right circle at (17.5, 13.5)
            path.append(UIBezierPath(ovalIn: CGRect(x: ox + 14*unit, y: oy + 10*unit, width: 7*unit, height: 7*unit)))
            // Stem
            path.move(to: p(10, 16))
            path.addLine(to: p(7,  23))
            path.addLine(to: p(17, 23))
            path.addLine(to: p(14, 16))
            path.close()
        }
        return path
    }
}

extension SuitView {
    static func glyph(for suit: Suit) -> Glyph {
        switch suit {
        case .hearts:   return .heart
        case .diamonds: return .diamond
        case .spades:   return .spade
        case .clubs:    return .club
        }
    }
    static func color(for suit: Suit) -> UIColor {
        (suit == .hearts || suit == .diamonds) ? PokerTheme.suitRed : PokerTheme.suitBlack
    }
}

// MARK: - Chip view

final class ChipView: UIView {
    private let outer = CAShapeLayer()
    private let notchLayer = CAReplicatorLayer()
    private let notch = CALayer()
    private let inner = CAShapeLayer()

    var chipColor: UIColor = PokerTheme.Chip.blue {
        didSet { applyColor() }
    }

    init(size: CGFloat, color: UIColor) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.chipColor = color
        backgroundColor = .clear

        // outer disk
        layer.addSublayer(outer)
        // notches replicator
        notch.backgroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
        let notchCount: Int = 8
        notchLayer.instanceCount = notchCount
        notchLayer.instanceTransform = CATransform3DMakeRotation(.pi * 2 / CGFloat(notchCount), 0, 0, 1)
        notchLayer.addSublayer(notch)
        layer.addSublayer(notchLayer)
        // inner pip
        layer.addSublayer(inner)

        applyColor()
        setNeedsLayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let s = min(bounds.width, bounds.height)
        let rect = CGRect(x: (bounds.width - s)/2, y: (bounds.height - s)/2, width: s, height: s)

        // Outer ring path
        outer.frame = bounds
        outer.path = UIBezierPath(ovalIn: rect).cgPath

        // Notches — 4 small white slits across the edge
        notchLayer.frame = bounds
        notchLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // The notch sublayer is a thin vertical bar that we replicate by rotation
        notch.bounds = CGRect(x: 0, y: 0, width: max(2, s * 0.10), height: s)
        notch.position = CGPoint(x: bounds.midX, y: bounds.midY)
        notch.cornerRadius = 0

        // Inner pip
        let inset = s * 0.22
        let innerRect = rect.insetBy(dx: inset, dy: inset)
        inner.frame = bounds
        inner.path = UIBezierPath(ovalIn: innerRect).cgPath

        // soft drop shadow on the whole view
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 3
    }

    private func applyColor() {
        outer.fillColor = chipColor.cgColor
        outer.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        outer.lineWidth = 0  // ring drawn via inner pip

        inner.fillColor = chipColor.cgColor
        inner.strokeColor = UIColor.white.withAlphaComponent(0.6).cgColor
        inner.lineWidth = 1
    }
}

// MARK: - Bet pill (chip + amount)

final class BetPillView: UIView {
    private let chip: ChipView
    private let amountLabel = UILabel()

    init(amount: Int, chipColor: UIColor, chipSize: CGFloat = 18, scale: CGFloat = 1.0) {
        // `scale` is 1.0 on iPhone (identical) and the table's design scale on
        // iPad, so the pill — chip, padding and amount text — grows with the felt.
        let chipSize = chipSize * scale
        self.chip = ChipView(size: chipSize, color: chipColor)
        super.init(frame: .zero)

        backgroundColor = PokerTheme.betPillSurface
        layer.cornerRadius = 999 / 2
        PokerTheme.applyShadowSm(layer)
        clipsToBounds = false

        amountLabel.font = .systemFont(ofSize: 11.5 * scale, weight: .bold)
        amountLabel.textColor = PokerTheme.suitBlack
        amountLabel.text = "$\(ChipFormatter.string(amount))"
        amountLabel.translatesAutoresizingMaskIntoConstraints = false

        chip.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chip)
        addSubview(amountLabel)

        NSLayoutConstraint.activate([
            chip.widthAnchor.constraint(equalToConstant: chipSize),
            chip.heightAnchor.constraint(equalToConstant: chipSize),
            chip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3 * scale),
            chip.centerYAnchor.constraint(equalTo: centerYAnchor),

            amountLabel.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 6 * scale),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9 * scale),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: chipSize + 6 * scale),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setAmount(_ amount: Int) {
        amountLabel.text = "$\(ChipFormatter.string(amount))"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
}

// MARK: - Avatar (gradient circle with initials)

final class AvatarView: UIView {
    private let gradient = CAGradientLayer()
    private let label = UILabel()
    private var hue: CGFloat = 210

    init(name: String, hue: CGFloat, size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.hue = hue
        backgroundColor = .clear

        gradient.startPoint = CGPoint(x: 0.2, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1.0)
        layer.addSublayer(gradient)

        label.text = Self.initials(from: name)
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: size * 0.36, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6

        applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    static func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.width / 2
        layer.cornerRadius = bounds.width / 2
        // Inner white ring (border)
        layer.borderColor = UIColor.white.cgColor
        layer.borderWidth = 2
        clipsToBounds = false
    }

    private func applyColors() {
        // Approximate the OKLCH gradient from the design with two HSB colors.
        let h1 = hue / 360.0
        let h2 = ((hue + 40).truncatingRemainder(dividingBy: 360)) / 360.0
        let top = UIColor(hue: h1, saturation: 0.55, brightness: 0.82, alpha: 1.0)
        let bottom = UIColor(hue: h2, saturation: 0.65, brightness: 0.55, alpha: 1.0)
        gradient.colors = [top.cgColor, bottom.cgColor]
    }
}

// MARK: - Pot pill

final class PotPillView: UIView {
    private let amountLabel = UILabel()
    private let titleLabel = UILabel()
    private let chip1: ChipView
    private let chip2: ChipView

    init(scale: CGFloat = 1.0) {
        // 1.0 on iPhone (identical); on iPad ~the felt's design scale so the
        // central pot pill grows with the table instead of staying tiny.
        let chipSize = 20 * scale
        chip1 = ChipView(size: chipSize, color: PokerTheme.Chip.gold)
        chip2 = ChipView(size: chipSize, color: PokerTheme.Chip.red)
        super.init(frame: .zero)

        backgroundColor = PokerTheme.glass
        layer.cornerRadius = 16
        PokerTheme.applyShadowMd(layer)

        titleLabel.text = "POT"
        titleLabel.textColor = PokerTheme.muted
        titleLabel.font = .systemFont(ofSize: 9 * scale, weight: .semibold)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        amountLabel.text = "$0"
        amountLabel.textColor = PokerTheme.ink
        amountLabel.font = .systemFont(ofSize: 16 * scale, weight: .heavy)

        chip1.translatesAutoresizingMaskIntoConstraints = false
        chip2.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(chip1)
        addSubview(chip2)
        addSubview(titleLabel)
        addSubview(amountLabel)

        NSLayoutConstraint.activate([
            chip1.widthAnchor.constraint(equalToConstant: chipSize),
            chip1.heightAnchor.constraint(equalToConstant: chipSize),
            chip1.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6 * scale),
            chip1.centerYAnchor.constraint(equalTo: centerYAnchor),

            chip2.widthAnchor.constraint(equalToConstant: chipSize),
            chip2.heightAnchor.constraint(equalToConstant: chipSize),
            chip2.leadingAnchor.constraint(equalTo: chip1.trailingAnchor, constant: -9 * scale),
            chip2.centerYAnchor.constraint(equalTo: centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: chip2.trailingAnchor, constant: 8 * scale),
            titleLabel.firstBaselineAnchor.constraint(equalTo: amountLabel.firstBaselineAnchor),

            amountLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6 * scale),
            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12 * scale),
            amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 30 * scale),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func setAmount(_ amount: Int) {
        amountLabel.text = "$\(ChipFormatter.string(amount))"
    }
}

// MARK: - Top info bar

final class TopInfoBar: UIView {
    let backButton = UIButton(type: .system)
    let rulesButton = UIButton(type: .system)
    let menuButton = UIButton(type: .system)
    private let infoLabel = UILabel()
    private let infoPill = UIView()

    /// iPad enlarges the bar's icon buttons + center pill. iPhone stays 1.0
    /// (everything below multiplies out to its original value).
    static let barScale: CGFloat = DeviceLayout.pick(1.0, pad: 1.35)
    /// Height the hosting controllers should give the bar so the bigger icons fit.
    static var preferredBarHeight: CGFloat { 48 * barScale }
    private var s: CGFloat { Self.barScale }

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Back chip
        styleIconButton(backButton, systemImage: "chevron.left")
        addSubview(backButton)

        // Center pill
        infoPill.backgroundColor = PokerTheme.glass
        infoPill.layer.cornerRadius = 16 * Self.barScale
        PokerTheme.applyShadowSm(infoPill.layer)
        infoPill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(infoPill)

        infoLabel.font = .systemFont(ofSize: 11 * s, weight: .semibold)
        infoLabel.textColor = PokerTheme.ink
        infoLabel.textAlignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoPill.addSubview(infoLabel)

        // Top-right chips — rules plus completed-hand details.
        styleIconButton(rulesButton, systemImage: "questionmark.circle")
        addSubview(rulesButton)

        // Hand-details / info icon (was 3-dot ellipsis).
        // The hosting view controller toggles `isEnabled` once the first
        // hand finishes; until then it's a passive affordance.
        styleIconButton(menuButton, systemImage: "list.bullet.rectangle")
        addSubview(menuButton)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        rulesButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 36 * s),
            backButton.heightAnchor.constraint(equalToConstant: 36 * s),

            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 36 * s),
            menuButton.heightAnchor.constraint(equalToConstant: 36 * s),

            rulesButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8 * s),
            rulesButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            rulesButton.widthAnchor.constraint(equalToConstant: 36 * s),
            rulesButton.heightAnchor.constraint(equalToConstant: 36 * s),

            infoPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            infoPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            infoPill.heightAnchor.constraint(equalToConstant: 30 * s),
            infoPill.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 10),
            infoPill.trailingAnchor.constraint(lessThanOrEqualTo: rulesButton.leadingAnchor, constant: -10),

            infoLabel.topAnchor.constraint(equalTo: infoPill.topAnchor),
            infoLabel.bottomAnchor.constraint(equalTo: infoPill.bottomAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: infoPill.leadingAnchor, constant: 14 * s),
            infoLabel.trailingAnchor.constraint(equalTo: infoPill.trailingAnchor, constant: -14 * s),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setInfo(blinds: String, hand: String?, phase: String?) {
        // Build an attributed string so the labels are muted while values are inked.
        let muted: [NSAttributedString.Key: Any] = [
            .foregroundColor: PokerTheme.muted,
            .font: UIFont.systemFont(ofSize: 11 * s, weight: .medium),
        ]
        let inked: [NSAttributedString.Key: Any] = [
            .foregroundColor: PokerTheme.ink,
            .font: UIFont.systemFont(ofSize: 11 * s, weight: .semibold),
        ]
        let separator = NSAttributedString(string: "  |  ", attributes: muted)
        let out = NSMutableAttributedString()
        out.append(NSAttributedString(string: "Blinds ", attributes: muted))
        out.append(NSAttributedString(string: blinds, attributes: inked))
        if let hand {
            out.append(separator)
            out.append(NSAttributedString(string: "Hand ", attributes: muted))
            out.append(NSAttributedString(string: hand, attributes: inked))
        }
        if let phase {
            out.append(separator)
            out.append(NSAttributedString(string: phase, attributes: inked))
        }
        infoLabel.attributedText = out
    }

    private func styleIconButton(_ button: UIButton, systemImage: String) {
        button.backgroundColor = PokerTheme.glass
        button.layer.cornerRadius = 12 * s
        PokerTheme.applyShadowSm(button.layer)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14 * s, weight: .semibold)
        button.setImage(UIImage(systemName: systemImage, withConfiguration: cfg), for: .normal)
        button.tintColor = PokerTheme.ink
    }
}

// MARK: - Number formatting helper

enum ChipFormatter {
    static let shared: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
    static func string(_ amount: Int) -> String {
        shared.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}
