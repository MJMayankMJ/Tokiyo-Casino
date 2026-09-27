//
//  TDPPayloads.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Every message payload. Wire-stable: renaming a field is a breaking
//  change that needs `TDPProtocol.version` bumped.
//
//  The important type here is `TDPClientView` — the *redacted* per-seat
//  snapshot. It is the only game state a client ever sees, so hidden
//  information is enforced by construction rather than by discipline.
//

import Foundation

// MARK: - Lobby

/// Broadcast in MPC `discoveryInfo`, so it must stay a flat string map.
struct TDPLobbyAdvert {
    let tableId: String
    let hostName: String
    let humansJoined: Int
    let targetRounds: Int
    let isStarted: Bool

    var discoveryInfo: [String: String] {
        [
            "v": "\(TDPProtocol.version)",
            "tableId": tableId,
            "host": hostName,
            "humans": "\(humansJoined)",
            "rounds": "\(targetRounds)",
            "started": isStarted ? "1" : "0"
        ]
    }

    init(tableId: String, hostName: String, humansJoined: Int, targetRounds: Int, isStarted: Bool) {
        self.tableId = tableId
        self.hostName = hostName
        self.humansJoined = humansJoined
        self.targetRounds = targetRounds
        self.isStarted = isStarted
    }

    /// Returns nil for a host on a different major protocol version, so
    /// incompatible tables never appear in the join list.
    init?(discoveryInfo info: [String: String]) {
        guard let raw = info["v"], Int(raw) == TDPProtocol.version else { return nil }
        self.tableId = info["tableId"] ?? UUID().uuidString
        self.hostName = info["host"] ?? "Host"
        self.humansJoined = Int(info["humans"] ?? "1") ?? 1
        self.targetRounds = Int(info["rounds"] ?? "3") ?? 3
        self.isStarted = (info["started"] ?? "0") == "1"
    }
}

struct TDPJoinRequest: Codable {
    let displayName: String
    let clientVersion: Int
}

struct TDPJoinAccepted: Codable {
    let seat: TDPSeat
    let displayName: String
    let lobby: TDPLobbySnapshot
}

struct TDPJoinRejected: Codable {
    let reason: String
}

struct TDPLobbySeat: Codable {
    let seat: TDPSeat
    let name: String
    /// "host" | "remote" | "ai" | "open"
    let kind: String
    let isReady: Bool
}

struct TDPLobbySnapshot: Codable {
    let tableId: String
    let hostName: String
    let targetRounds: Int
    let seats: [TDPLobbySeat]
    let canStart: Bool
}

struct TDPPeerLeft: Codable {
    let seat: TDPSeat
    let reason: String
}

struct TDPHostEnding: Codable {
    let reason: String
}

// MARK: - Redacted game view

struct TDPSeatView: Codable {
    let seat: TDPSeat
    let name: String
    /// "you" | "ai" | "remote"
    let kind: String
    /// Card *count* only — never the cards.
    let handCount: Int
    let tricksWon: Int
    let quota: Int
    let score: Int
    /// `TDPRole` raw value, nil before the dealer is known.
    let role: String?
    let isDealer: Bool
    let isConnected: Bool
    /// Card drawn in the first-dealer draw; public by nature.
    let drawnCard: Card?
    /// The role quota before any tricks were given up this round; `quota`
    /// is the effective target.
    var baseQuota: Int = 0
}

/// The pull in progress. `drawnCard` and `legalReturnIDs` are populated
/// ONLY in the creditor's copy — everyone else sees the seats and counts
/// so their animation can run, and nothing else.
struct TDPKhichaiView: Codable {
    let creditorSeat: TDPSeat
    let debtorSeat: TDPSeat
    let fanCount: Int
    let iAmCreditor: Bool
    let iAmDebtor: Bool
    let drawnCard: Card?
    let legalReturnIDs: [String]?
    /// The debtor is arranging; nobody may pull until it closes.
    var isArranging: Bool = false
    var arrangeSecondsLeft: Int?
    /// "1 of 2" — this pull within the current creditor/debtor pair.
    var pullNumber: Int = 1
    var pullTotal: Int = 1
}

/// One debt the viewer owes, for the settle-up choice.
struct TDPSettleDebt: Codable, Equatable {
    let creditorSeat: TDPSeat
    let amount: Int
    /// Gave this creditor tricks last round — must give cards this time.
    let giveTricksLocked: Bool
}

struct TDPSettleView: Codable {
    /// The viewer's own debts still awaiting a choice (empty once chosen).
    let mine: [TDPSettleDebt]
    /// Debtors who haven't chosen yet — public.
    let waitingOn: [TDPSeat]
}

/// One line of a settle-up intent.
struct TDPSettleChoice: Codable, Equatable {
    let creditorSeat: TDPSeat
    let method: TDPSettleMethod
}

/// What the host is waiting on from this client, so the UI knows which
/// control to surface without re-deriving the rules.
enum TDPPrompt: String, Codable {
    case none
    case ready
    case chooseTrump
    /// You owe tricks: give them up, or give cards, per creditor.
    case settleUp
    /// Your arranging window is open.
    case arrangeCards
    case khichaiDraw
    case khichaiReturn
    case playCard
    case roundEnd
}

struct TDPClientView: Codable {
    let tableId: String
    let phase: TDPPhase
    let roundNumber: Int
    let trickNumber: Int
    let targetRounds: Int

    // This client
    let mySeat: TDPSeat
    let myHand: [Card]
    let myLegalCardIDs: [String]
    let prompt: TDPPrompt
    let isMyTurn: Bool
    /// Only the trump selector sees this, and only under highest-of-three.
    let myPrivateTrumpCard: Card?

    // Public
    let seats: [TDPSeatView]
    let dealerSeat: TDPSeat?
    let trump: Suit?
    let trumpMethod: TDPTrumpMethod?
    let revealedTrumpCard: Card?
    let currentTrick: [TDPTrickPlay]
    let leadSuit: Suit?
    let currentTurnSeat: TDPSeat?
    let leaderSeat: TDPSeat?
    let lastTrick: [TDPTrickPlay]
    let lastTrickWinnerSeat: TDPSeat?

    // Settlement
    let debts: [TDPDebt]
    let khichai: TDPKhichaiView?

    // Session
    let roundHistory: [TDPRoundScore]
    let isHost: Bool
    let message: String

    var settlement: TDPSettleView?
    /// The debtor's own cards in their face-down order. Only ever sent to
    /// the debtor — it is their hand.
    var myArrangement: [Card]?
    /// Debts settled in tricks this round; public.
    var concessions: [TDPConcession] = []
    /// The vote on three more rounds, once the last one is played.
    var extendVote: TDPExtendVoteView?
    /// This round's finished tricks, in order — public, like the cards.
    var roundTricks: [[TDPTrickPlay]] = []
}

/// Where the "three more rounds?" vote stands. Public — everyone sees who
/// has voted and how.
struct TDPExtendVoteView: Codable, Equatable {
    struct Ballot: Codable, Equatable {
        let seat: TDPSeat
        /// nil until they vote.
        let yes: Bool?
    }
    /// Every person at the table, in seat order. Bots don't vote.
    let ballots: [Ballot]
    let needed: Int
    let declined: Bool
}

// MARK: - Intents (client → host)

/// One flat struct rather than an enum with associated values, so the
/// wire form stays trivially decodable from another platform.
struct TDPIntent: Codable {

    enum Kind: String, Codable {
        case ready
        case targetRounds
        case trumpSuit
        case trumpSeventh
        case trumpHighestOfThree
        case settle
        case arrange
        case khichaiDraw
        case khichaiReturn
        case playCard
        case beginNextRound
        case voteExtend
    }

    let kind: Kind
    var ready: Bool?
    var rounds: Int?
    var suit: Suit?
    /// Position in the fanned hand, never a card id — the host resolves it.
    var fanIndex: Int?
    var cardID: String?
    var settlements: [TDPSettleChoice]?
    /// The debtor's own card ids in their chosen face-down order.
    var order: [String]?
    var done: Bool?
    /// Yes or no to three more rounds.
    var accept: Bool?

    init(kind: Kind,
         ready: Bool? = nil,
         rounds: Int? = nil,
         suit: Suit? = nil,
         fanIndex: Int? = nil,
         cardID: String? = nil,
         settlements: [TDPSettleChoice]? = nil,
         order: [String]? = nil,
         done: Bool? = nil,
         accept: Bool? = nil) {
        self.kind = kind
        self.ready = ready
        self.rounds = rounds
        self.suit = suit
        self.fanIndex = fanIndex
        self.cardID = cardID
        self.settlements = settlements
        self.order = order
        self.done = done
        self.accept = accept
    }

    /// Maps to an engine action for `seat`. The host always supplies the
    /// seat itself — a client cannot act for another seat by asking to.
    func action(for seat: TDPSeat) -> TDPAction? {
        switch kind {
        case .ready:               return .setReady(seat: seat, ready: ready ?? true)
        case .targetRounds:        return .setTargetRounds(seat: seat, rounds: rounds ?? 3)
        case .trumpSuit:           return suit.map { .selectTrumpSuit(seat: seat, suit: $0) }
        case .trumpSeventh:        return .selectTrumpSeventh(seat: seat)
        case .trumpHighestOfThree: return .selectTrumpHighestOfThree(seat: seat)
        case .settle:
            guard let settlements else { return nil }
            var choices: [TDPSeat: TDPSettleMethod] = [:]
            for line in settlements {
                guard choices[line.creditorSeat] == nil else { return nil }   // duplicate creditor
                choices[line.creditorSeat] = line.method
            }
            return .settle(seat: seat, choices: choices)
        case .arrange:
            return order.map { .khichaiArrange(seat: seat, order: $0, done: done ?? false) }
        case .khichaiDraw:         return .khichaiDraw(seat: seat, fanIndex: fanIndex)
        case .khichaiReturn:       return cardID.map { .khichaiReturn(seat: seat, cardID: $0) }
        case .playCard:            return cardID.map { .playCard(seat: seat, cardID: $0) }
        case .beginNextRound:      return .beginNextRound
        case .voteExtend:          return accept.map { .voteExtend(seat: seat, yes: $0) }
        }
    }
}

struct TDPIntentRejected: Codable {
    let kind: TDPIntent.Kind
    let reason: String
}
