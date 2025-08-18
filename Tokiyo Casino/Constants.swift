//
//  Constants.swift
//  EmojiSlotMachine
//
//  Created by Marcy Vernon on 5/30/20.
//  Copyright © 2020 Marcy Vernon. All rights reserved.
//

import Foundation
import UIKit

enum K {
    // MARK: - Fonts
    static let emojiFont     = "Apple Color Emoji"
    static let customFont    = "Pocket Monk"  // Your custom font name
    static let defaultFont   = "System"       // Fallback font
    
    // MARK: - Font Sizes
    static let buttonFontSize: CGFloat = 16
    static let titleFontSize: CGFloat = 24
    static let coinFontSize: CGFloat = 30
    
    // MARK: - Game Text
    static let win        = "Winner!"
    static let lose       = "3 In A Row"
    
    // MARK: - Button Texts
    static let playSlots  = "PLAY SLOTS"
    static let playLotto  = "PLAY LOTTO"
    static let playCoino  = "PLAY COINO"
    
    // MARK: - Audio
    static let sound      = "Slots"
    static let rattle     = "Rattle"
    
    // MARK: - Assets
    static let imageArray = ["🍋", "❤️", "🍒", "⓻"]
    static let lightTile  = "lightTile"
    static let darkTile   = "darkTile"
    static let bombPNG    = "bomb"
    static let diamondPNG = "diamond"
    
    // MARK: - Segues
    static let toSlotVC   = "toSlotVC"
    static let toLottoVC  = "toLottoVC"
    static let toCoinoVC  = "toCoinoVC"
    
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
