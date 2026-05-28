//
//  Constants.swift
//  Tokiyo Casino
//

import Foundation
import UIKit

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
