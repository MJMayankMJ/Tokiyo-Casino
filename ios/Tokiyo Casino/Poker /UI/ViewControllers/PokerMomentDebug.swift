//
//  PokerMomentDebug.swift
//  Poker
//
//  Debug · moments: every special hand (`PokerMoments`), played over the
//  live table with a made-up hand, so each effect can be watched without
//  waiting for the cards to fall that way. The tests check that every
//  sample really makes its moment.
//

#if DEBUG
import UIKit

enum PokerMomentSample: CaseIterable {
    case royalFlush, straightFlush, fourOfAKind
    case runnerRunner, riverMiracle, heroCall, hammer
    case knockout, doubleKnockout

    var title: String {
        switch self {
        case .royalFlush:     return "Royal flush"
        case .straightFlush:  return "Straight flush"
        case .fourOfAKind:    return "Four of a kind"
        case .runnerRunner:   return "Runner-runner (A♥5♥ vs set)"
        case .riverMiracle:   return "River miracle (gutshot vs aces)"
        case .heroCall:       return "Hero call (ace-high)"
        case .hammer:         return "The Hammer (7-2)"
        case .knockout:       return "Knockout"
        case .doubleKnockout: return "Double KO"
        }
    }

    /// The hand, won by you against the players in `others` (one is
    /// enough; a double KO uses two).
    func hand(against others: [Int]) -> PokerHandRecord {
        let a = others.first ?? 1
        let b = others.dropFirst().first ?? a + 1
        func shown(_ seat: Int, _ list: String) -> PokerShownHand { PokerShownHand(seat: seat, cards: Self.cards(list)) }
        switch self {
        case .royalFlush:
            return PokerHandRecord(hole: Self.cards("AS KS"), board: Self.cards("QS JS 10S 4D 9C"), won: true,
                                   shownDown: [shown(a, "AH QD")])
        case .straightFlush:
            return PokerHandRecord(hole: Self.cards("9H 8H"), board: Self.cards("7H 6H 5H KC 2D"), won: true,
                                   shownDown: [shown(a, "KS KD")])
        case .fourOfAKind:
            return PokerHandRecord(hole: Self.cards("9C 9D"), board: Self.cards("9H 9S KD 4C 2H"), won: true,
                                   shownDown: [shown(a, "KS QS")])
        case .runnerRunner:
            // A set of sevens on the flop; running hearts make the flush.
            return PokerHandRecord(hole: Self.cards("AH 5H"), board: Self.cards("QC 7H 2S 9H 3H"), won: true,
                                   shownDown: [shown(a, "7S 7C")])
        case .riverMiracle:
            // A gutshot against aces: four outs, and the river's a seven.
            return PokerHandRecord(hole: Self.cards("9H 8H"), board: Self.cards("5H 6C KD 2S 7D"), won: true,
                                   shownDown: [shown(a, "AS AC")])
        case .heroCall:
            // Ace-high calls the river; the missed flush draw shows up.
            return PokerHandRecord(hole: Self.cards("AC QD"), board: Self.cards("KS 7S 2D 4C 3H"), won: true,
                                   shownDown: [shown(a, "JS 10S")], calledRiver: true)
        case .hammer:
            return PokerHandRecord(hole: Self.cards("7D 2C"), board: Self.cards("AS KH 9C 5D 3S"), won: true)
        case .knockout:
            return PokerHandRecord(hole: Self.cards("AS AD"), board: Self.cards("9C 5H 2D JS 3C"), won: true,
                                   shownDown: [shown(a, "KS KD")], knockedOut: [a])
        case .doubleKnockout:
            return PokerHandRecord(hole: Self.cards("AS AD"), board: Self.cards("9C 5H 2D JS 3C"), won: true,
                                   shownDown: [shown(a, "KS KD"), shown(b, "QS QD")], knockedOut: [a, b])
        }
    }

    /// "AS KS 10H": each a rank, then the suit's letter.
    static func cards(_ list: String) -> [Card] {
        list.split(separator: " ").compactMap { code in
            let suits: [Character: Suit] = ["S": .spades, "H": .hearts, "D": .diamonds, "C": .clubs]
            guard let letter = code.last, let suit = suits[letter],
                  let rank = Rank.allCases.first(where: { $0.shortString == String(code.dropLast()) })
            else { return nil }
            return Card(suit: suit, rank: rank)
        }
    }
}

extension GameViewController {

    /// Every moment, to play over the table.
    func showMomentsDebug() {
        let sheet = UIAlertController(title: "Debug · moments",
                                      message: "Plays over the table with sample cards.",
                                      preferredStyle: .actionSheet)
        for sample in PokerMomentSample.allCases {
            sheet.addAction(UIAlertAction(title: sample.title, style: .default) { [weak self] _ in
                self?.replayMoment(sample)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY,
                                                                 width: 1, height: 1)
        present(sheet, animated: true)
    }

    private func replayMoment(_ sample: PokerMomentSample) {
        guard let gm = gameManager, let human = gm.humanPlayer else { return }
        let hand = sample.hand(against: gm.players.filter { !$0.isHuman }.map(\.id))
        momentEffects.play(PokerMoments.moments(for: hand), hand: hand, seat: human.id) {}
    }
}
#endif
