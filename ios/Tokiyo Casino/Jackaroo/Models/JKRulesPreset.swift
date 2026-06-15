//
//  JKRulesPreset.swift
//  Tokiyo Casino — Jackaroo
//
//  Toggle bag for ruleset variants. Defaults form the V1 shipping
//  preset, based on Jawaker Basic with consolidated gaps. See
//  JACKAROO_SPEC.md §4.
//
//  The engine reads from these toggles; we never branch on a preset
//  name directly. Presets simply pick a set of values.
//

import Foundation

// MARK: - Per-toggle enums

public enum DealCycle: String, Codable, Hashable {
    /// Default — 4 cards every deal, reshuffle Fire Pile when deck empties.
    case four
    /// CatsAtCards — first deal 4, then 5 thereafter.
    case fourThenFive
    /// Bader / community custom — 4, 4, 5 rotating.
    case fourFourFive
}

public enum SeatOrder: String, Codable, Hashable {
    /// Dealer's left starts, clockwise (Jawaker Basic).
    case dealerLeftCW
    /// Dealer's right starts, counter-clockwise (CatsAtCards).
    case dealerRightCCW
}

public enum KingMode: String, Codable, Hashable {
    /// Default — King fields one marble from Home to Base.
    case fieldOnly
    /// Complex — King may instead move a marble 13 with capture-along-path.
    case fieldOrThirteenCapture
}

public enum FiveMode: String, Codable, Hashable {
    /// Default — 5 moves one of your own marbles forward 5.
    case selfOnly
    /// Complex — 5 moves any marble on the track forward 5.
    case anyMarbleOnTrack
}

public enum SevenMode: String, Codable, Hashable {
    /// Default — split 7 across exactly two own marbles, 1…6 each.
    case twoOwn
    /// Community — split 7 across 1…4 own marbles.
    case multiOwn
}

public enum JackMode: String, Codable, Hashable {
    /// Default — swap one own marble with an opponent's marble on track.
    case swapOpponentOnly
    /// CatsAtCards — Black Jack swaps; Red Jack moves 11.
    case redElevenBlackSwap
}

public enum QueenMode: String, Codable, Hashable {
    /// Default — forward 12.
    case twelveForward
    /// CatsAtCards — Black Queen = 12 forward, Red Queen forces a discard.
    case blackTwelveRedDiscard
}

public enum SafeEntryMode: String, Codable, Hashable {
    /// Default — card value consumed as stepsToGate + stepsInsideSafe;
    /// land on or before deepest empty cell.
    case cardValueAtMostRemaining
    /// Variant — must land exactly on the deepest empty cell.
    case exactOnly
    /// Variant — unused steps continue around the main track.
    case overflowAroundTrack
}

public enum BurnScope: String, Codable, Hashable {
    /// Default — discard the whole hand when no card has any legal move.
    case wholeHand
    /// Variant — discard only the offending card(s).
    case singleCard
}

public enum AceSplit: String, Codable, Hashable {
    case oneOrEleven
    case oneOnly
    case elevenOnly
}

// MARK: - Preset bag

public struct JKRulesPreset: Codable, Hashable {
    public var dealCycle: DealCycle
    public var seatOrder: SeatOrder
    public var kingMode: KingMode
    public var fiveMode: FiveMode
    public var sevenMode: SevenMode
    public var jackMode: JackMode
    public var queenMode: QueenMode
    public var cannotPassOwn: Bool
    public var burnOnNoMove: Bool
    public var burnScope: BurnScope
    public var safeEntryMode: SafeEntryMode
    public var partnerHandoff: Bool
    public var aceSplit: AceSplit

    public init(
        dealCycle: DealCycle = .four,
        seatOrder: SeatOrder = .dealerLeftCW,
        kingMode: KingMode = .fieldOnly,
        fiveMode: FiveMode = .selfOnly,
        sevenMode: SevenMode = .twoOwn,
        jackMode: JackMode = .swapOpponentOnly,
        queenMode: QueenMode = .twelveForward,
        cannotPassOwn: Bool = true,
        burnOnNoMove: Bool = true,
        burnScope: BurnScope = .wholeHand,
        safeEntryMode: SafeEntryMode = .cardValueAtMostRemaining,
        partnerHandoff: Bool = true,
        aceSplit: AceSplit = .oneOrEleven
    ) {
        self.dealCycle = dealCycle
        self.seatOrder = seatOrder
        self.kingMode = kingMode
        self.fiveMode = fiveMode
        self.sevenMode = sevenMode
        self.jackMode = jackMode
        self.queenMode = queenMode
        self.cannotPassOwn = cannotPassOwn
        self.burnOnNoMove = burnOnNoMove
        self.burnScope = burnScope
        self.safeEntryMode = safeEntryMode
        self.partnerHandoff = partnerHandoff
        self.aceSplit = aceSplit
    }

    var direction: JKDirection { seatOrder == .dealerLeftCW ? .cw : .ccw }
}

// MARK: - Named presets

public extension JKRulesPreset {
    /// V1 shipping default — Jawaker Basic with consolidated gaps.
    static let jawakerBasic = JKRulesPreset()

    /// Complex — King-13 capture, 5-any-marble.
    static let jawakerComplex = JKRulesPreset(
        kingMode: .fieldOrThirteenCapture,
        fiveMode: .anyMarbleOnTrack
    )

    /// CatsAtCards-style community preset.
    static let community = JKRulesPreset(
        dealCycle: .fourThenFive,
        seatOrder: .dealerRightCCW,
        kingMode: .fieldOrThirteenCapture,
        fiveMode: .anyMarbleOnTrack,
        sevenMode: .multiOwn,
        jackMode: .redElevenBlackSwap,
        queenMode: .blackTwelveRedDiscard
    )
}

// MARK: - V1 selectable presets (menu + settings + rules)

public extension JKRulesPreset {
    /// One pickable ruleset, with copy for the menu/settings/rules UI.
    /// V1 ships locked-in presets only — no freeform toggle editor
    /// (JACKAROO_SPEC.md §4).
    struct Option: Hashable {
        public let name: String
        public let caption: String
        public let preset: JKRulesPreset
    }

    /// The three presets a player can choose, in display order. The
    /// menu segmented control, the in-game settings sheet, and the
    /// rules screen all read from this single source.
    static let selectableOptions: [Option] = [
        Option(name: "Basic",
               caption: "Jawaker Basic — the classic, balanced ruleset.",
               preset: .jawakerBasic),
        Option(name: "Complex",
               caption: "Adds King-13 (captures all it passes) and 5-on-any-marble.",
               preset: .jawakerComplex),
        Option(name: "Community",
               caption: "Complex, plus 4-then-5 deals, multi-marble 7s, and red Jack/Queen.",
               preset: .community),
    ]

    /// Index of this preset among `selectableOptions`, or nil if it's a
    /// non-standard combination.
    var selectableIndex: Int? {
        Self.selectableOptions.firstIndex { $0.preset == self }
    }

    /// Short label for the active preset (defaults to "Custom").
    var displayName: String {
        selectableIndex.map { Self.selectableOptions[$0].name } ?? "Custom"
    }
}
