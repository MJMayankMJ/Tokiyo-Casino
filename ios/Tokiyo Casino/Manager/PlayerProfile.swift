//
//  PlayerProfile.swift
//  Tokiyo Casino
//
//  Who is playing on this phone, shared by every game: the name shown at
//  the table and an optional photo. The name is asked for once, on first
//  launch; skipping assigns a guest name. Both can be changed later from
//  Profile. Nothing here leaves the device.
//

import UIKit

enum PlayerProfile {

    /// Posted on the main queue whenever the name or photo changes.
    static let didChange = Notification.Name("PlayerProfile.didChange")

    /// Long enough for most first names, short enough for a table badge.
    static let maxNameLength = 16

    private static let nameKey = "tokiyo.profile.name"
    /// The guest name offered until the player picks one — kept apart from
    /// `nameKey` so it never passes for a name they chose.
    private static let guestKey = "tokiyo.profile.guestName"
    private static let onboardedKey = "tokiyo.profile.onboarded.v1"
    /// Poker's multiplayer screens kept their own name before profiles.
    private static let legacyPokerNameKey = "tokiyo.poker.mp.displayName"

    private static var defaults: UserDefaults { .standard }

    // MARK: Name

    /// Never empty: the saved name, the name Poker already knew, or this
    /// phone's guest name.
    static var name: String {
        suggestedName ?? guestName
    }

    /// A name the player actually typed — now or, for Poker, before profiles
    /// existed. Pre-fills onboarding; nil for a brand-new player.
    static var suggestedName: String? {
        clean(defaults.string(forKey: nameKey)) ?? clean(defaults.string(forKey: legacyPokerNameKey))
    }

    /// "Guest 4821": made up once and kept, so Skip and Home agree.
    static var guestName: String {
        if let guest = clean(defaults.string(forKey: guestKey)) { return guest }
        let guest = randomGuestName()
        defaults.set(guest, forKey: guestKey)
        return guest
    }

    /// Saves a new name. Blank input is rejected; long input is trimmed.
    @discardableResult
    static func setName(_ raw: String) -> Bool {
        guard let name = clean(raw) else { return false }
        defaults.set(name, forKey: nameKey)
        notify()
        return true
    }

    static func randomGuestName() -> String {
        "Guest \(Int.random(in: 1000...9999))"
    }

    /// "Mayank Jangid" → "MJ", "Guest 4821" → "G".
    static func initials(for name: String) -> String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? String(name.prefix(1)).uppercased() : String(letters).uppercased()
    }

    private static func clean(_ raw: String?) -> String? {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    // MARK: Onboarding

    static var hasOnboarded: Bool { defaults.bool(forKey: onboardedKey) }

    /// `name == nil` means the player skipped: they play as a guest.
    static func completeOnboarding(name: String?) {
        if name.map(setName) != true {
            setName(guestName)
        }
        defaults.set(true, forKey: onboardedKey)
    }

    // MARK: Cards

    private static func designKey(_ game: CardGame) -> String { "tokiyo.profile.cardDesign.\(game.rawValue)" }

    /// The deck this player picked for `game`, or the game's own default.
    static func cardDesign(for game: CardGame) -> CardDesign {
        defaults.string(forKey: designKey(game)).flatMap(CardDesign.init(rawValue:)) ?? game.defaultDesign
    }

    static func setCardDesign(_ design: CardDesign, for game: CardGame) {
        defaults.set(design.rawValue, forKey: designKey(game))
        notify()
    }

    // MARK: Photo

    private static var cachedPhoto: UIImage?
    private static var didLoadPhoto = false

    private static var photoURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Profile", isDirectory: true)
            .appendingPathComponent("photo.jpg")
    }

    static var photo: UIImage? {
        if !didLoadPhoto {
            didLoadPhoto = true
            cachedPhoto = (try? Data(contentsOf: photoURL)).flatMap(UIImage.init(data:))
        }
        return cachedPhoto
    }

    /// Stores a square, downscaled copy. `nil` removes the photo.
    static func setPhoto(_ image: UIImage?) {
        let url = photoURL
        if let image {
            let square = squared(image, side: 512)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? square.jpegData(compressionQuality: 0.85)?.write(to: url, options: .atomic)
            cachedPhoto = square
        } else {
            try? FileManager.default.removeItem(at: url)
            cachedPhoto = nil
        }
        didLoadPhoto = true
        notify()
    }

    /// Centre-crops to a square and scales it to `side` points at 1x.
    private static func squared(_ image: UIImage, side: CGFloat) -> UIImage {
        let size = image.size
        let crop = min(size.width, size.height)
        let target = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let scale = side / max(crop, 1)
            let drawn = CGSize(width: size.width * scale, height: size.height * scale)
            image.draw(in: CGRect(x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                                  width: drawn.width, height: drawn.height))
        }
    }

    private static func notify() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
