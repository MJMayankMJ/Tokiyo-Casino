//
//  PokerMoments.swift
//  Poker
//
//  The hands worth a fanfare, for the player on this phone. Pure rules over
//  what that player can see once a pot is theirs — their cards, the board,
//  the hands turned over at showdown and how they played the river;
//  `PokerMomentEffects` is how each one looks.
//
//  • Monster hand — four of a kind, a straight flush or a royal flush with
//    at least one of your own cards in it. Quads or a straight flush on the
//    board, which everyone shares, don't count.
//  • The Hammer — any pot won holding 7-2 offsuit, the worst starting hand.
//  • Runner-runner — behind on the flop and on the turn to a hand that was
//    shown down, 15% or less to win, and it took both the turn and the
//    river to win it.
//  • River miracle — behind on the turn with 10% or less to win (about
//    four outs), and the river won it.
//  • Hero call — you called a river bet holding one pair or less and won
//    the showdown. It was a bluff you caught only if every hand you beat
//    added nothing to the board.
//  • Knockout — you won the pot that took a player's last chip.
//
//  One headline per hand — the rarest — and a knockout after it.
//

import Foundation

enum PokerMoment: Equatable {
    case royalFlush
    case straightFlush
    case fourOfAKind
    case hammer
    /// `odds`: your chance to win on the flop.
    case runnerRunner(odds: Double)
    /// `odds`: your chance to win on the turn.
    case riverMiracle(odds: Double)
    case heroCall
    /// `count` players out at once.
    case knockout(count: Int)

    /// How long the effect runs, so the table can wait for it.
    var duration: TimeInterval {
        switch self {
        case .royalFlush:    return 3.9
        case .straightFlush: return 3.1
        case .fourOfAKind:   return 2.9
        case .hammer:        return 2.5
        case .runnerRunner:  return 2.9
        case .riverMiracle:  return 2.9
        case .heroCall:      return 2.0
        case .knockout:      return 2.0
        }
    }
}

/// A hand turned over at showdown.
struct PokerShownHand: Equatable {
    let seat: Int
    let cards: [Card]
}

/// A finished hand as the player on this phone saw it.
struct PokerHandRecord {
    var hole: [Card]
    var board: [Card]
    /// You took all or part of a pot.
    var won: Bool
    /// The other hands turned over at showdown; empty when everyone else
    /// folded.
    var shownDown: [PokerShownHand] = []
    /// Your last move on the river was calling a bet.
    var calledRiver = false
    /// Seats whose last chip you won.
    var knockedOut: [Int] = []
}

enum PokerMoments {

    /// The most a river miracle could have been to win on the turn — about
    /// four outs. A flush draw hitting (~20%) is just a draw coming in.
    static let riverMiracleOdds = 0.10
    static let runnerRunnerOdds = 0.15

    /// On a friends' table the cards are turned over as the result
    /// arrives; a moment waits this long for them.
    static let showdownLeadIn: TimeInterval = 1.0

    /// How long a friends' table holds the next deal for its people's
    /// moments: the longest anyone's, once the cards are face up.
    static func hold(at table: GameManager) -> TimeInterval {
        let longest = table.players.filter(\.isHuman)
            .map { moments(for: PokerHandRecord(finishedAt: table, by: $0)).reduce(0) { $0 + $1.duration } }
            .max() ?? 0
        return longest > 0 ? showdownLeadIn + longest : 0
    }

    /// This hand's moments in play order: the headline, then a knockout.
    static func moments(for hand: PokerHandRecord) -> [PokerMoment] {
        guard hand.won, hand.hole.count == 2 else { return [] }
        var moments: [PokerMoment] = []
        if let headline = headline(for: hand) { moments.append(headline) }
        if !hand.knockedOut.isEmpty { moments.append(.knockout(count: hand.knockedOut.count)) }
        return moments
    }

    /// The rarest thing about a hand you won.
    static func headline(for hand: PokerHandRecord) -> PokerMoment? {
        if let monster = monster(hole: hand.hole, board: hand.board) { return monster }
        if isHammer(hand.hole) { return .hammer }
        let others = hand.shownDown.map(\.cards)
        if let comeback = comeback(hole: hand.hole, board: hand.board, against: others) { return comeback }
        if hand.calledRiver, !others.isEmpty, hand.board.count == 5,
           HandEvaluator.evaluateBestHand(from: hand.hole + hand.board).rank <= .onePair {
            return .heroCall
        }
        return nil
    }

    /// Quads, a straight flush or a royal made with at least one of `hole`.
    static func monster(hole: [Card], board: [Card]) -> PokerMoment? {
        guard hole.count == 2, board.count >= 3 else { return nil }
        let best = HandEvaluator.evaluateBestHand(from: hole + board)
        guard best.rank >= .fourOfAKind, madeCards(of: best).contains(where: hole.contains) else { return nil }
        switch best.rank {
        case .royalFlush:    return .royalFlush
        case .straightFlush: return .straightFlush
        default:             return .fourOfAKind
        }
    }

    /// The cards that make `hand` what it is — the four of a kind without
    /// its kicker; all five of anything else.
    static func madeCards(of hand: HandEvaluation) -> [Card] {
        guard hand.rank == .fourOfAKind,
              let quad = Dictionary(grouping: hand.cards, by: \.rank).first(where: { $0.value.count == 4 })?.key
        else { return hand.cards }
        return hand.cards.filter { $0.rank == quad }
    }

    static func isHammer(_ hole: [Card]) -> Bool {
        hole.count == 2 && Set(hole.map(\.rank)) == [.seven, .two] && hole[0].suit != hole[1].suit
    }

    /// A win from behind: runner-runner if it took both the turn and the
    /// river, a river miracle if the river alone did it.
    static func comeback(hole: [Card], board: [Card], against others: [[Card]]) -> PokerMoment? {
        guard hole.count == 2, board.count == 5, !others.isEmpty,
              beats(hole, others, on: board) else { return nil }
        let flop = Array(board.prefix(3))
        let turn = Array(board.prefix(4))
        guard isBehind(hole, others, on: turn) else { return nil }
        if isBehind(hole, others, on: flop), !beats(hole, others, on: flop + [board[4]]) {
            let odds = self.odds(hole: hole, board: flop, against: others)
            if odds <= runnerRunnerOdds { return .runnerRunner(odds: odds) }
        }
        let odds = self.odds(hole: hole, board: turn, against: others)
        return odds <= riverMiracleOdds ? .riverMiracle(odds: odds) : nil
    }

    /// Your chance to win from a flop or a turn against the hands shown
    /// down — every way the rest of the board can come, counted. A tie
    /// isn't a win.
    static func odds(hole: [Card], board: [Card], against others: [[Card]]) -> Double {
        let seen = Set(hole + board + others.flatMap { $0 })
        let unseen = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit: suit, rank: $0) } }
            .filter { !seen.contains($0) }
        var wins = 0, runs = 0
        switch board.count {
        case 4:
            for river in unseen {
                runs += 1
                if beats(hole, others, on: board + [river]) { wins += 1 }
            }
        case 3:
            for i in unseen.indices {
                for j in unseen.indices where j > i {
                    runs += 1
                    if beats(hole, others, on: board + [unseen[i], unseen[j]]) { wins += 1 }
                }
            }
        default:
            return 0
        }
        return runs == 0 ? 0 : Double(wins) / Double(runs)
    }

    /// `hole` is ahead of every one of `others` on `board`.
    static func beats(_ hole: [Card], _ others: [[Card]], on board: [Card]) -> Bool {
        let mine = FastHandEvaluator.score(hole + board)
        return others.allSatisfy { FastHandEvaluator.score($0 + board) < mine }
    }

    /// Someone in `others` is ahead of `hole` on `board`.
    static func isBehind(_ hole: [Card], _ others: [[Card]], on board: [Card]) -> Bool {
        let mine = FastHandEvaluator.score(hole + board)
        return others.contains { FastHandEvaluator.score($0 + board) > mine }
    }

    /// Every hand you beat at showdown added nothing to the board: the bet
    /// you called was a bluff, or a draw that missed. Anything else — a
    /// weaker pair, say — may have been a thin value bet.
    static func caughtBluff(_ hand: PokerHandRecord) -> Bool {
        guard hand.board.count == 5, !hand.shownDown.isEmpty else { return false }
        let board = HandEvaluator.evaluateBestHand(from: hand.board).rank
        return hand.shownDown.allSatisfy { HandEvaluator.evaluateBestHand(from: $0.cards + hand.board).rank == board }
    }

    /// Whether `action` called a bet: a call, or an all-in that didn't
    /// raise the table's bet.
    static func calls(_ action: PlayerAction, betBefore: Int, betAfter: Int) -> Bool {
        switch action {
        case .call:  return true
        case .allIn: return betAfter <= betBefore
        default:     return false
        }
    }

    /// Who took each player's last chip at showdown: the winners of the
    /// last pot that player paid into. Pots are split the way the table
    /// splits them (`GameManager.determineWinnersWithDelay`): the best hand
    /// left takes, from everyone, as much as its own stake, until the chips
    /// run out. `invested` is every player's stake this hand, folded or not;
    /// `hands` holds the showdown hands' `HandEvaluation.value`.
    static func lastChipTakers(invested: [Int: Int], hands: [Int: Int]) -> [Int: Set<Int>] {
        var stakes = invested
        var contenders = hands
        var takers: [Int: Set<Int>] = [:]
        while let best = contenders.values.max() {
            let winners = Set(contenders.filter { $0.value == best }.keys)
            let cap = winners.map { stakes[$0] ?? 0 }.min() ?? 0
            guard cap > 0 else { break }
            for (seat, stake) in stakes where stake > 0 {
                stakes[seat] = stake - min(stake, cap)
                if !winners.contains(seat) { takers[seat] = winners }
            }
            contenders = contenders.filter { (stakes[$0.key] ?? 0) > 0 }
        }
        return takers
    }
}

// MARK: - From the table

extension PokerHandRecord {

    /// The hand `player` just finished at `table`, from everything the
    /// table knows. Call once the pots are paid, before the next deal.
    init(finishedAt table: GameManager, by player: Player) {
        let inHand = table.players.filter { !$0.isFolded && $0.holeCards.count == 2 }
        let opponents = inHand.filter { $0.id != player.id }
        let won = player.winnings > 0
        // Out of chips and paid nothing back — and the pot that took their
        // last chip was yours.
        let takers = PokerMoments.lastChipTakers(
            invested: Dictionary(uniqueKeysWithValues: table.players.map { ($0.id, $0.totalInvested) }),
            hands: Dictionary(uniqueKeysWithValues: inHand.map {
                ($0.id, HandEvaluator.evaluateBestHand(from: $0.holeCards + table.communityCards).value)
            }))
        let out = opponents.filter { $0.chips == 0 && $0.winnings == 0 && takers[$0.id]?.contains(player.id) == true }
        self.init(hole: player.holeCards,
                  board: table.communityCards,
                  won: won,
                  shownDown: inHand.count > 1 ? opponents.map { PokerShownHand(seat: $0.id, cards: $0.holeCards) } : [],
                  calledRiver: table.handHistory.lastAction(of: player.id, on: .river) == .call,
                  knockedOut: won ? out.map(\.id) : [])
    }
}

extension HandHistoryTracker {

    /// `seat`'s last move on `street` this hand, if it acted there.
    func lastAction(of seat: Int, on street: PokerStreet) -> ActionClass? {
        for event in log.reversed() {
            switch event {
            case .handStarted:
                return nil
            case let .playerActed(_, actor, actedOn, action, _, _, _) where actor == seat && actedOn == street:
                return action
            default:
                continue
            }
        }
        return nil
    }
}
