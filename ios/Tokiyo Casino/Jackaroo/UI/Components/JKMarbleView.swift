//
//  JKMarbleView.swift
//  Tokiyo Casino — Jackaroo
//
//  Glossy peg with a per-seat colour, deep-colour ring outline, a
//  small team-color badge at the base, and an amber halo when active.
//

import UIKit

final class JKMarbleView: UIView {

    enum SeatPalette {
        // Per-seat marble colours. Seat 0/2 = Team A (coral family);
        // seat 1/3 = Team B (forest family). 2 and 3 use slightly
        // brighter variants so each player's marbles stay
        // distinguishable from their partner's.
        case seat(SeatID)

        var body: UIColor {
            switch self {
            case .seat(0): return UIColor.dyn(light: 0xD5604E, dark: 0xE8786A) // coral
            case .seat(1): return UIColor.dyn(light: 0x5E9466, dark: 0x7BB07A) // forest
            case .seat(2): return UIColor.dyn(light: 0xE9907D, dark: 0xF1A091) // coral-light
            case .seat(3): return UIColor.dyn(light: 0x8FB594, dark: 0xA8CCA8) // forest-light
            default:       return .gray
            }
        }
        var outline: UIColor {
            switch self {
            case .seat(0), .seat(2): return UIColor.dyn(light: 0xB84A3A, dark: 0xC95A4E) // coralDeep
            case .seat(1), .seat(3): return UIColor.dyn(light: 0x4B7B53, dark: 0x5E8A60) // forestDeep
            default:                  return .darkGray
            }
        }
    }

    let seat: SeatID

    /// Driven externally — true gives an amber halo around the peg.
    var isActive: Bool = false { didSet { setNeedsLayout() } }

    /// True when the player has selected this marble for a pending
    /// move. Lifts the peg slightly and brightens its outline.
    var isSelected: Bool = false { didSet { setNeedsLayout() } }

    private let bodyLayer = CAShapeLayer()
    private let highlightLayer = CAGradientLayer()
    private let teamBadgeLayer = CAShapeLayer()
    private let haloLayer = CAShapeLayer()

    init(seat: SeatID) {
        self.seat = seat
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true

        layer.addSublayer(haloLayer)
        layer.addSublayer(bodyLayer)
        layer.addSublayer(highlightLayer)
        layer.addSublayer(teamBadgeLayer)

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let s = min(bounds.width, bounds.height)
        let rect = CGRect(x: (bounds.width - s)/2,
                          y: (bounds.height - s)/2,
                          width: s, height: s)
        let bodyRect = rect.insetBy(dx: s * 0.10, dy: s * 0.10)

        // Halo — slightly larger than the peg, only visible when active.
        haloLayer.frame = bounds
        haloLayer.path = UIBezierPath(ovalIn: rect.insetBy(dx: -s * 0.05, dy: -s * 0.05)).cgPath
        haloLayer.fillColor = UIColor.clear.cgColor
        haloLayer.strokeColor = UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 0.85).cgColor
        haloLayer.lineWidth = isActive ? max(2, s * 0.10) : 0
        haloLayer.shadowColor = UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 1).cgColor
        haloLayer.shadowOpacity = isActive ? 0.6 : 0
        haloLayer.shadowRadius = s * 0.12
        haloLayer.shadowOffset = .zero

        // Body — solid disk with a deep outline.
        bodyLayer.frame = bounds
        bodyLayer.path = UIBezierPath(ovalIn: bodyRect).cgPath
        bodyLayer.lineWidth = max(1, s * 0.06)

        // Highlight — radial gradient (light center → seat colour edge).
        highlightLayer.frame = bodyRect
        highlightLayer.cornerRadius = bodyRect.width / 2
        highlightLayer.masksToBounds = true
        highlightLayer.type = .radial
        highlightLayer.startPoint = CGPoint(x: 0.35, y: 0.30)   // off-center for sheen
        highlightLayer.endPoint   = CGPoint(x: 1.00, y: 1.00)

        // Team badge — small dot at the bottom of the peg.
        let badgeSize = s * 0.22
        let badgeRect = CGRect(
            x: bodyRect.midX - badgeSize / 2,
            y: bodyRect.maxY - badgeSize * 0.85,
            width: badgeSize, height: badgeSize
        )
        teamBadgeLayer.frame = bounds
        teamBadgeLayer.path = UIBezierPath(ovalIn: badgeRect).cgPath

        // Lift on selection.
        if isSelected {
            transform = CGAffineTransform(translationX: 0, y: -3).scaledBy(x: 1.06, y: 1.06)
        } else {
            transform = .identity
        }
    }

    private func applyTheme() {
        let palette = SeatPalette.seat(seat)
        let body = palette.body
        let outline = palette.outline
        let resolved = traitCollection

        bodyLayer.fillColor = body.resolvedColor(with: resolved).cgColor
        bodyLayer.strokeColor = outline.resolvedColor(with: resolved).cgColor

        // Body radial gradient (light highlight → body colour).
        let light = UIColor.white.withAlphaComponent(0.55).cgColor
        let mid = body.withAlphaComponent(0.0).cgColor
        let edge = outline.resolvedColor(with: resolved).cgColor
        highlightLayer.colors = [light, mid, edge]
        highlightLayer.locations = [0.0, 0.55, 1.0]

        teamBadgeLayer.fillColor = outline.resolvedColor(with: resolved).cgColor
        teamBadgeLayer.strokeColor = UIColor.white.withAlphaComponent(0.85).cgColor
        teamBadgeLayer.lineWidth = 1
    }
}
