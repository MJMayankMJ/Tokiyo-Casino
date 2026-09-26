//
//  TDPGameState.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Root snapshot. The host owns exactly one of these and mutates it only
//  through `TDPEngine`. It is fully `Codable`, so autosave and replay come
//  for free — but it contains every player's hand and therefore must NEVER
//  be sent to a client. Clients receive `TDPClientView` instead.
//

import Foundation

// MARK: - Player

struct TDPPlayer: Codable, Equatable {
    let id: String
    var name: String
    var seat: TDPSeat
    var isAI: Bool
    var isReady: Bool
    var hand: [Card]
    var tricksWon: Int
    /// Card drawn during the first-dealer draw, cleared afterwards.
    var drawnCard: Card?
    /// Set when a remote guest owns this seat.
    var isRemote: Bool

    init(id: String, name: String, seat: TDPSeat, isAI: Bool = false, isRemote: Bool = false) {
        self.id = id
        self.name = name
        self.seat = seat
        self.isAI = isAI
        self.isRemote = isRemote
        self.isReady = false
        self.hand = []
        self.tricksWon = 0
        self.drawnCard = nil
    }
}

// MARK: - Trick

struct TDPTrickPlay: Codable, Equatable {
    let seat: TDPSeat
    let card: Card
}

// MARK: - Settlement

struct TDPDebt: Codable, Equatable {
    let from: TDPSeat
    let to: TDPSeat
    var amount: Int
}

/// One pending pull. `fanOrder` is a shuffled permutation of the debtor's
/// hand indices: the creditor picks a *position in the fan*, never a card,
/// so the index they send carries no information about what they take.
struct TDPKhichaiStep: Codable, Equatable {
    let creditorSeat: TDPSeat
    let debtorSeat: TDPSeat
    var drawnCard: Card?
    var fanOrder: [Int]
    /// The debtor is in their arranging window; nobody may pull yet.
    var arranging: Bool = false
}

// MARK: - Round record

struct TDPRoundScore: Codable, Equatable {
    let round: Int
    let dealerSeat: TDPSeat
    let trump: Suit
    let trumpMethod: TDPTrumpMethod
    /// Keyed by seat, stringified because JSON object keys must be strings.
    let tricks: [String: Int]
    /// Effective targets — the role quota plus any tricks given up.
    let quotas: [String: Int]
    let delta: [String: Int]
    /// Debts settled by giving up tricks at the start of this round.
    var concessions: [TDPConcession] = []
}

// MARK: - State

struct TDPGameState: Codable {

    // Identity
    var tableID: String
    var hostSeat: TDPSeat
    var seed: UInt32
    var rng: TDPRNG

    // Seating
    var players: [TDPPlayer]
    var dealerSeat: TDPSeat?

    // Deal
    var phase: TDPPhase
    var deck: [Card]
    var trump: Suit?
    var trumpMethod: TDPTrumpMethod?
    /// The card that set trump, when it is public (the opened seventh).
    var revealedTrumpCard: Card?
    /// The card that set trump under `highestOfThree` — private to the
    /// selector, never published.
    var privateTrumpCard: Card?

    // Trick play
    var currentTrick: [TDPTrickPlay]
    var leadSuit: Suit?
    var trickNumber: Int
    var leaderSeat: TDPSeat?
    var currentTurnSeat: TDPSeat?
    var lastTrick: [TDPTrickPlay]
    var lastTrickWinnerSeat: TDPSeat?

    // Session
    var roundNumber: Int
    var scores: [String: Int]
    var roundHistory: [TDPRoundScore]
    var targetRounds: Int
    var minRounds: Int

    // Settlement
    var debts: [TDPDebt]
    var khichaiQueue: [TDPKhichaiStep]
    var khichaiCurrent: TDPKhichaiStep?

    // Settling up (all round-scoped)
    /// "debtor-creditor" → the debtor's choice for that debt.
    var settleChoices: [String: TDPSettleMethod] = [:]
    /// Target changes from debts settled in tricks; always sums to zero.
    var targetAdjust: [String: Int] = [:]
    var concessions: [TDPConcession] = []
    /// Each debtor's face-down order, as card ids. Set once per round; a
    /// returned card is slipped in at a random position.
    var arrangements: [String: [String]] = [:]

    // First-dealer draw
    var dealerDrawPending: [TDPSeat]
    var dealerDrawGroup: [TDPSeat]

    // Presentation
    var message: String

    init(tableID: String, seed: UInt32, players: [TDPPlayer], hostSeat: TDPSeat = 0) {
        self.tableID = tableID
        self.hostSeat = hostSeat
        self.seed = seed
        self.rng = TDPRNG(seed: seed)
        self.players = players
        self.dealerSeat = nil
        self.phase = .lobby
        self.deck = []
        self.trump = nil
        self.trumpMethod = nil
        self.revealedTrumpCard = nil
        self.privateTrumpCard = nil
        self.currentTrick = []
        self.leadSuit = nil
        self.trickNumber = 0
        self.leaderSeat = nil
        self.currentTurnSeat = nil
        self.lastTrick = []
        self.lastTrickWinnerSeat = nil
        self.roundNumber = 0
        self.scores = [:]
        self.roundHistory = []
        self.targetRounds = 3
        self.minRounds = 3
        self.debts = []
        self.khichaiQueue = []
        self.khichaiCurrent = nil
        self.dealerDrawPending = []
        self.dealerDrawGroup = []
        self.message = "Waiting for players."
        for player in players { self.scores[String(player.seat)] = 0 }
    }

    // MARK: Lookup

    func player(at seat: TDPSeat) -> TDPPlayer? {
        players.first { $0.seat == seat }
    }

    func name(at seat: TDPSeat?) -> String {
        guard let seat, let player = player(at: seat) else { return "—" }
        return player.name
    }

    func score(at seat: TDPSeat) -> Int { scores[String(seat)] ?? 0 }

    var isSessionOver: Bool { phase == .sessionEnd }

    /// A session may only end on a multiple of three rounds, so every seat
    /// has dealt, selected trump and sat third an equal number of times.
    var canEndSession: Bool {
        let played = roundHistory.count
        return played >= minRounds && played % 3 == 0
    }

    /// Clears everything round-scoped, keeping seating and running scores.
    mutating func resetForNewRound() {
        deck = TDPDeck.build()
        trump = nil
        trumpMethod = nil
        revealedTrumpCard = nil
        privateTrumpCard = nil
        currentTrick = []
        leadSuit = nil
        trickNumber = 0
        leaderSeat = nil
        currentTurnSeat = nil
        lastTrick = []
        lastTrickWinnerSeat = nil
        debts = []
        khichaiQueue = []
        khichaiCurrent = nil
        settleChoices = [:]
        targetAdjust = [:]
        concessions = []
        arrangements = [:]
        for index in players.indices {
            players[index].hand = []
            players[index].tricksWon = 0
            players[index].drawnCard = nil
        }
    }
}
