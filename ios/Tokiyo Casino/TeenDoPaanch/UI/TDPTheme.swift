//
//  TDPTheme.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Design tokens for the table. Every color is a dynamic light/dark pair so
//  the screen follows the system theme with no toggle:
//
//  • Dark  — taken from the Claude Design handoff ("532 Game Screen"): a
//            cool near-black page, raised graphite chrome, one green accent.
//            OKLCH values converted to sRGB.
//  • Light — Poker's parchment palette (`PokerTheme`): cream page, white
//            glass chrome, brown ink, amber primary actions, forest accent.
//
//  Layout is identical in both themes; only color changes.
//

import UIKit

enum TDPTheme {

    // MARK: Surfaces

    static let page      = UIColor.dyn(light: 0xF1E8D2, dark: 0x101214)   // ref oklch(.18 .006 255)
    static let raised    = UIColor.dyn(light: 0xFFFDF7, dark: 0x191B1D)   // ref oklch(.22 .006 255)
    static let raisedAlt = UIColor.dyn(light: 0xF7EFD9, dark: 0x222427)   // ref oklch(.26 .006 255)
    static let hairline  = UIColor.dyn(light: 0xDACDA8, dark: 0x202225)   // ref oklch(.25 .006 255)
    static let slot      = UIColor.dyn(light: 0xC2B48A, dark: 0x3B3D40)   // ref oklch(.36 .006 255)

    // MARK: Ink

    static let ink     = UIColor.dyn(light: 0x1F1A12, dark: 0xEDEFF1)     // ref oklch(.95 .004 255)
    static let inkSoft = UIColor.dyn(light: 0x4A4231, dark: 0xCED1D5)     // ref oklch(.86 .006 255)
    static let muted   = UIColor.dyn(light: 0x8C8369, dark: 0x898C91)     // ref oklch(.64 .008 255)

    // MARK: Accents

    /// "Your turn", quota met, the card that won the trick.
    static let accent     = UIColor.dyn(light: 0x4B7B53, dark: 0x79DD9F)  // ref oklch(.82 .13 155)
    /// Primary buttons — Poker's amber in light, the reference green in dark.
    /// Fill behind a selected option.
    static let accentWash = UIColor.dyn(light: 0xE4EEE2, dark: 0x132419)   // ref oklch(.24 .03 155)
    static let primary    = UIColor.dyn(light: 0xC99540, dark: 0x79DD9F)
    static let primaryInk = UIColor.dyn(light: 0x2E220D, dark: 0x0C2416)
    static let warn       = UIColor.dyn(light: 0xC24A4A, dark: 0xF66C6D)

    // MARK: Cards

    static let cardFace      = UIColor.dyn(light: 0xFFFFFF, dark: 0xF6F5F2)  // ref oklch(.97 .004 90)
    static let suitRed       = UIColor.dyn(light: 0xE13D44, dark: 0xCC3336)  // ref oklch(.56 .19 25)
    static let suitBlack     = UIColor.dyn(light: 0x1A1A1F, dark: 0x181B1F)  // ref oklch(.22 .01 255)
    /// Suit glyph on the trump pill — brighter red to read on the dark pill.
    static let trumpRed      = UIColor.dyn(light: 0xE13D44, dark: 0xF66C6D)  // ref oklch(.70 .17 22)
    /// Wash over cards you can't play. The reference darkens them
    /// (`brightness(.42) saturate(.6)`); on parchment a cream wash reads
    /// better than black.
    static let cardDim = UIColor.dyn(lightRGBA: (241, 232, 210, 0.66),
                                     darkRGBA: (8, 9, 10, 0.60))
    /// Card back: one flat colour, an inset hairline and the Tokiyo
    /// sparkle — forest on parchment, deep green on graphite.
    static let cardBack     = UIColor.dyn(light: 0x4B7B53, dark: 0x1D3A29)
    static let cardBackLine = UIColor.dyn(lightRGBA: (247, 239, 217, 0.40),
                                          darkRGBA: (121, 221, 159, 0.26))
    static let cardBackMark = UIColor.dyn(light: 0xF7EFD9, dark: 0x79DD9F)

    static func shadowOpacity(for traits: UITraitCollection) -> Float {
        traits.userInterfaceStyle == .dark ? 0.35 : 0.16
    }

    // MARK: Avatar tints

    enum Tint: CaseIterable {
        case green, amber, blue

        var fill: UIColor {
            switch self {
            case .green: return .dyn(light: 0xDCEBDD, dark: 0x1F3D2A)   // ref oklch(.33 .05 155)
            case .amber: return .dyn(light: 0xF3E1C7, dark: 0x482F1A)   // ref oklch(.33 .05 60)
            case .blue:  return .dyn(light: 0xDCE6F2, dark: 0x21374E)   // ref oklch(.33 .05 250)
            }
        }

        var ink: UIColor {
            switch self {
            case .green: return .dyn(light: 0x3E6B48, dark: 0xC0EACD)
            case .amber: return .dyn(light: 0x8A5A2B, dark: 0xF6CFB0)
            case .blue:  return .dyn(light: 0x3A5A7D, dark: 0xBADBFE)
            }
        }
    }

    // MARK: Metrics

    /// iPad scales the phone-tuned table up rather than floating it small.
    static let scale: CGFloat = DeviceLayout.pick(1.0, pad: 1.3)

    static var handCard: CGSize { CGSize(width: 62 * scale, height: 88 * scale) }
    static var tableCard: CGSize { CGSize(width: 70 * scale, height: 100 * scale) }

    // MARK: Type

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        .systemFont(ofSize: size * scale, weight: weight)
    }

    /// The reference sets scores in Geist Mono; SF Mono is the native match.
    static func mono(_ size: CGFloat, _ weight: UIFont.Weight = .regular) -> UIFont {
        .monospacedSystemFont(ofSize: size * scale, weight: weight)
    }

    static func suitName(_ suit: Suit) -> String {
        switch suit {
        case .spades:   return "spades"
        case .hearts:   return "hearts"
        case .diamonds: return "diamonds"
        case .clubs:    return "clubs"
        }
    }

    static func isRed(_ suit: Suit) -> Bool { suit == .hearts || suit == .diamonds }
}

// MARK: - Helpers for the lobby / entry / rules screens

/// Thin facade kept so the non-table screens share the table's palette.
enum TDPDesign {
    static var felt: UIColor { TDPTheme.page }
    static var panel: UIColor { TDPTheme.raised }
    static var accent: UIColor { TDPTheme.primary }
    static var good: UIColor { TDPTheme.accent }
    static var warn: UIColor { TDPTheme.warn }
    static var text: UIColor { TDPTheme.ink }
    static var dim: UIColor { TDPTheme.muted }

    static func label(_ text: String = "",
                      size: CGFloat = 14,
                      weight: UIFont.Weight = .semibold,
                      color: UIColor = TDPTheme.ink) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = TDPTheme.font(size, weight)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    static func button(_ title: String, filled: Bool = true) -> UIButton {
        TDPButton(title: title, style: filled ? .primary : .secondary)
    }
}
