//
//  Constants.swift
//  Tokiyo Casino
//

import Foundation
import UIKit

/// Device-class layout helpers. The UI was tuned for iPhone; these let the
/// iPad scale up the iPhone-sized layouts so they fill the larger canvas
/// instead of floating tiny in the middle. iPhone always gets `scale == 1`,
/// so existing phone layouts are untouched.
enum DeviceLayout {
    /// True on iPad (regular-width, larger canvas). Uses the idiom so it is
    /// stable regardless of multitasking trait changes during layout.
    static var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// Generic up-scale applied to iPhone-tuned point sizes on iPad.
    static var scale: CGFloat { isPad ? 1.6 : 1.0 }

    /// Type up-scale for iPad. Deliberately gentler than `scale` so text grows
    /// noticeably (matching the larger canvas) without overflowing the
    /// fixed-height pills/controls the iPhone design relies on. iPhone keeps
    /// 1.0, so every label stays pixel-identical there.
    static var fontScale: CGFloat { isPad ? 1.28 : 1.0 }

    /// Scales an iPhone-tuned value for the current device.
    static func scaled(_ value: CGFloat) -> CGFloat { value * scale }

    /// Picks a value per device class (iPhone first, iPad second).
    static func pick<T>(_ phone: T, pad: T) -> T { isPad ? pad : phone }
}

enum K {
    // MARK: - Fonts
    static let emojiFont     = "Apple Color Emoji"
    static let customFont    = "Pocket Monk"
    static let defaultFont   = "System"

    // MARK: - Font Sizes
    static let buttonFontSize: CGFloat = 16
    static let titleFontSize: CGFloat = 24
    static let coinFontSize: CGFloat = 30

    // MARK: - Button Texts
    static let playJackaroo = "PLAY JACKAROO"
    static let playPoker    = "PLAY POKER"

    // MARK: - Assets
    static let imageArray = ["🍋", "❤️", "🍒", "⓻"]

    // MARK: - Segues
    static let toSlotVC   = "toSlotVC"

    // MARK: - Font Helper Methods
    static func customFont(size: CGFloat) -> UIFont {
        return UIFont(name: K.customFont, size: size) ?? UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func buttonFont() -> UIFont {
        return customFont(size: K.buttonFontSize)
    }

    static func titleFont() -> UIFont {
        return customFont(size: K.titleFontSize)
    }

    static func coinFont() -> UIFont {
        return customFont(size: K.coinFontSize)
    }
}
