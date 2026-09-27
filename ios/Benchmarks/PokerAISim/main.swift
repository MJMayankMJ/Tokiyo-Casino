//
//  main.swift
//  Poker AI — headless table simulator
//
//  Plays thousands of hands against every difficulty and bot style in seconds,
//  to check how the AI actually plays rather than how the code reads. It drives
//  the app's real GameManager synchronously — mirroring startNewHand /
//  processNextTurn / processPlayerAction / endBettingRound minus the UX delays —
//  and every bot decision goes through `GameManager.aiDecisionInputs` and
//  `AIEngine.decide`, exactly like `processAITurn`. Only the human seat is
//  scripted. Deals and bot choices use seeded generators, so a run is
//  reproducible and two engine versions can be compared on identical deals.
//
//  Built for the 2026-09-27 "the AI folds too much when you go all-in" fix
//  (POKER_AI_DESIGN.md, Phase 4).
//
//      Benchmarks/PokerAISim/build.sh
//      "${TMPDIR:-/tmp}/pokersim/sim" <scenario> [sessions] [hands] [players] [chips]
//
//  Scenarios (what the human seat does):
//      shove     shoves every hand                  (the reported problem)
//      tight     shoves only the top 10% of hands   (bots must not pay this off)
//      flop      calls preflop, shoves every flop
//      raise     min-raises every hand, check/folds after the flop
//      station   calls everything
//      straight  plays its equity straightforwardly (a general strength check)
//
//  Env: ONLY=<text> keeps configs whose label contains it; HANDS=1 prints how
//  often bots call a shove with a few representative hands.
//
//  Output is the human's result in big blinds per 100 hands (lower = stronger
//  bots) plus, when the human shoves, how the bots answered it.
//

import Foundation

// MARK: - Seeded randomness

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Deck with its own seeded shuffle (the app's Deck uses the system RNG).
final class SeededDeck: Deck {
    var deckRng: SplitMix64
    private var pile: [Card] = []
    init(seed: UInt64) { deckRng = SplitMix64(seed: seed); super.init() }
    override func reset() {
        pile = []
        for suit in Suit.allCases { for rank in Rank.allCases { pile.append(Card(suit: suit, rank: rank)) } }
        pile.shuffle(using: &deckRng)
    }
    override func shuffle() { pile.shuffle(using: &deckRng) }
    override func deal() -> Card? { pile.isEmpty ? nil : pile.removeFirst() }
    override var remainingCards: Int { pile.count }
}

// MARK: - Starting hands

struct HandClass: Hashable { let hi: Int; let lo: Int; let suited: Bool }

func handClass(_ c: [Card]) -> HandClass {
    let a = c[0].rank.rawValue, b = c[1].rank.rawValue
    return HandClass(hi: max(a, b), lo: min(a, b), suited: a != b && c[0].suit == c[1].suit)
}

func className(_ k: HandClass) -> String {
    func r(_ v: Int) -> String { ["", "", "2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A"][v] }
    if k.hi == k.lo { return r(k.hi) + r(k.lo) }
    return r(k.hi) + r(k.lo) + (k.suited ? "s" : "o")
}

let allClasses: [HandClass] = {
    var out: [HandClass] = []
    for hi in 2...14 {
        for lo in 2...hi {
            if hi == lo { out.append(HandClass(hi: hi, lo: lo, suited: false)) }
            else {
                out.append(HandClass(hi: hi, lo: lo, suited: true))
                out.append(HandClass(hi: hi, lo: lo, suited: false))
            }
        }
    }
    return out
}()

/// Each starting hand's equity against one random hand — the yardstick for
/// "should call a player who shoves any two cards".
let vsRandomEquity: [HandClass: Double] = {
    var eqs = [Double](repeating: 0, count: allClasses.count)
    let lock = NSLock()
    DispatchQueue.concurrentPerform(iterations: allClasses.count) { i in
        let k = allClasses[i]
        let c1 = Card(suit: .spades, rank: Rank(rawValue: k.hi)!)
        let c2 = Card(suit: k.suited ? .spades : .hearts, rank: Rank(rawValue: k.lo)!)
        var rng = SplitMix64(seed: UInt64(i) &* 7919 &+ 17)
        let e = EquityCalculator.equity(hole: [c1, c2], board: [], opponents: 1, iterations: 8000, rng: &rng)
        lock.lock(); eqs[i] = e; lock.unlock()
    }
    var out: [HandClass: Double] = [:]
    for (i, k) in allClasses.enumerated() { out[k] = eqs[i] }
    return out
}()

/// Equity (vs a random hand) that separates the top `fraction` of combos.
func equityThreshold(topFraction fraction: Double) -> Double {
    let list = allClasses
        .map { (vsRandomEquity[$0]!, $0.hi == $0.lo ? 6 : ($0.suited ? 4 : 12)) }
        .sorted { $0.0 > $1.0 }
    var combos = 0
    for (e, n) in list {
        combos += n
        if Double(combos) >= fraction * 1326 { return e }
    }
    return 0
}

func styleName(_ p: AIProfile) -> String {
    let presets: [(String, AIProfile)] = [("Nit", .nit), ("TAG", .tag), ("LAG", .lag),
                                          ("Station", .callingStation), ("Maniac", .maniac), ("Pro", .solverInspired)]
    for (n, q) in presets where q.aggression == p.aggression && q.looseness == p.looseness
        && q.bluffFrequency == p.bluffFrequency && q.callStation == p.callStation && q.trickiness == p.trickiness {
        return n
    }
    return "?"
}

// MARK: - The human seat

enum Human {
    case alwaysShove
    case shoveTop(Double)
    case flopShove
    case minRaiseAlways
    case station
    case straightforward

    var label: String {
        switch self {
        case .alwaysShove: return "human shoves every hand"
        case .shoveTop(let x): return "human shoves the top \(Int(x * 100))% only"
        case .flopShove: return "human calls preflop, shoves every flop"
        case .minRaiseAlways: return "human min-raises every hand"
        case .station: return "human calls everything"
        case .straightforward: return "human plays its equity straightforwardly"
        }
    }
}

// MARK: - Stats

struct Bucket {
    var n = 0, cont = 0
    mutating func add(_ continued: Bool) { n += 1; if continued { cont += 1 } }
    mutating func merge(_ o: Bucket) { n += o.n; cont += o.cont }
    var pct: String { n == 0 ? "  -  " : String(format: "%5.1f%%", 100.0 * Double(cont) / Double(n)) }
}

struct Stats {
    var hands = 0
    var humanNet = 0
    var humanShoves = 0
    var shovesUncalled = 0
    var vsShove = Bucket()                          // bot decisions facing the human's preflop shove
    var vsShoveByStyle: [String: Bucket] = [:]
    var vsShoveByHandsSeen = [Bucket](repeating: Bucket(), count: 3)   // hands 1-10, 11-30, 31+
    var bigPairs = Bucket()                         // TT+
    var aceKing = Bucket()
    var clearCalls = Bucket()                       // ≥ 52% against a random hand
    var byHand: [String: Bucket] = [:]
    var postflopVsShove = Bucket()
    var vsSmallRaise = Bucket()                     // bot facing the human's non-all-in preflop raise

    mutating func merge(_ o: Stats) {
        hands += o.hands; humanNet += o.humanNet
        humanShoves += o.humanShoves; shovesUncalled += o.shovesUncalled
        vsShove.merge(o.vsShove)
        for (k, v) in o.vsShoveByStyle { vsShoveByStyle[k, default: Bucket()].merge(v) }
        for i in 0..<3 { vsShoveByHandsSeen[i].merge(o.vsShoveByHandsSeen[i]) }
        bigPairs.merge(o.bigPairs); aceKing.merge(o.aceKing); clearCalls.merge(o.clearCalls)
        for (k, v) in o.byHand { byHand[k, default: Bucket()].merge(v) }
        postflopVsShove.merge(o.postflopVsShove); vsSmallRaise.merge(o.vsSmallRaise)
    }
}

let namedHands = ["AA", "KK", "QQ", "JJ", "TT", "77", "22", "AKo", "AQo", "AJo", "ATo", "A5o", "A2o",
                  "KQo", "KJo", "K9o", "QJs", "J9s", "T8o", "72o"]

// MARK: - Session

final class Session {
    let gm: GameManager
    let human: Human
    let startingChips: Int
    let shoveLine: Double
    var rng: SplitMix64
    var stats = Stats()
    var handIndex = 0
    var humanShovedPreflop = false
    var botCalledShove = false

    init(players: Int, chips: Int, config: PokerAIConfig, human: Human, seed: UInt64) {
        rng = SplitMix64(seed: seed)
        gm = GameManager(playerCount: players, startingChips: chips)
        gm.deck = SeededDeck(seed: seed ^ 0xD1CE)
        gm.aiConfig = config
        gm.applyAIConfigToAISeats()
        self.human = human
        startingChips = chips
        if case .shoveTop(let x) = human { shoveLine = equityThreshold(topFraction: x) } else { shoveLine = 0 }
    }

    func run(hands: Int) { for _ in 0..<hands { playHand() } }

    func humanDecision(_ p: Player) -> PlayerAction {
        let callAmount = max(0, gm.currentBet - p.currentBet)
        let call: PlayerAction = p.chips <= callAmount ? .allIn : .call
        switch human {
        case .alwaysShove:
            return .allIn
        case .shoveTop:
            if gm.communityCards.isEmpty && vsRandomEquity[handClass(p.holeCards)]! >= shoveLine { return .allIn }
            return callAmount > 0 ? .fold : .check
        case .flopShove:
            if gm.communityCards.isEmpty { return callAmount > 0 ? call : .check }
            return .allIn
        case .minRaiseAlways:
            if gm.communityCards.isEmpty {
                if gm.canPlayerRaise(p) && p.chips > callAmount + gm.minRaise { return .raise(gm.minRaise) }
                return callAmount > 0 ? call : .check
            }
            return callAmount > 0 ? .fold : .check
        case .station:
            return callAmount > 0 ? call : .check
        case .straightforward:
            let eq = EquityCalculator.equity(hole: p.holeCards, board: gm.communityCards, opponents: 1,
                                             iterations: 300, rng: &rng)
            if gm.communityCards.isEmpty {
                if eq >= 0.62 && gm.canPlayerRaise(p) && p.chips > callAmount + gm.minRaise * 3 {
                    return .raise(max(gm.minRaise, gm.currentBet * 2))
                }
                if eq >= 0.55 || (callAmount <= gm.bigBlind && eq >= 0.45) { return callAmount > 0 ? call : .check }
                return callAmount > 0 ? .fold : .check
            }
            if eq >= 0.72 && gm.canPlayerRaise(p) && p.chips > callAmount + gm.mainPot.amount / 2 {
                return .raise(max(gm.minRaise, gm.mainPot.amount / 2))
            }
            guard callAmount > 0 else { return .check }
            let odds = Double(callAmount) / Double(gm.mainPot.amount + callAmount)
            return eq >= max(0.5, odds) ? call : .fold
        }
    }

    /// Tally how a bot answered the human's bet, before the action is applied.
    func observe(_ p: Player, _ action: PlayerAction) {
        guard let h = gm.humanPlayer else { return }
        if p.isHuman {
            if gm.communityCards.isEmpty, case .allIn = action { humanShovedPreflop = true }
            return
        }
        var continued = true
        if case .fold = action { continued = false }
        let humanSetThePrice = !h.isFolded && h.currentBet == gm.currentBet && gm.currentBet > p.currentBet

        if humanSetThePrice, gm.communityCards.isEmpty, !h.isAllIn, case .raise? = h.lastAction {
            stats.vsSmallRaise.add(continued)
        }
        guard humanSetThePrice, h.isAllIn else { return }
        if continued { botCalledShove = true }
        guard gm.communityCards.isEmpty else { stats.postflopVsShove.add(continued); return }

        let hand = handClass(p.holeCards)
        stats.vsShove.add(continued)
        stats.vsShoveByStyle[styleName(p.resolvedProfile), default: Bucket()].add(continued)
        stats.vsShoveByHandsSeen[handIndex <= 10 ? 0 : (handIndex <= 30 ? 1 : 2)].add(continued)
        if hand.hi == hand.lo && hand.hi >= 10 { stats.bigPairs.add(continued) }
        if hand.hi == 14 && hand.lo == 13 { stats.aceKing.add(continued) }
        if vsRandomEquity[hand]! >= 0.52 { stats.clearCalls.add(continued) }
        stats.byHand[className(hand), default: Bucket()].add(continued)
    }

    func playHand() {
        // Rebuy anyone busted so the table stays full.
        for p in gm.players where p.chips == 0 {
            p.chips = startingChips
            gm.adjustExpectedChipTotal(by: startingChips)
        }
        let humanBefore = gm.humanPlayer!.chips
        handIndex += 1
        humanShovedPreflop = false
        botCalledShove = false

        // startNewHand, minus processNextTurn's scheduling.
        gm.resetForNewHand()
        guard gm.activePlayers.count >= 2 else { return }
        gm.dealHoleCards()
        gm.postBlinds()
        gm.currentPhase = .preFlop
        gm.handHistory.handStarted(button: gm.dealerIndex, smallBlind: gm.smallBlind, bigBlind: gm.bigBlind,
                                   seats: gm.players.filter { $0.holeCards.count == 2 }.map { $0.id })
        if let bb = gm.bigBlindPlayerSeatIndex {
            gm.currentPlayerIndex = gm.findNextActivePlayerIndex(afterSeatIndex: bb)
        } else {
            gm.currentPlayerIndex = gm.findFirstActivePlayerAfterDealer()
        }

        var steps = 0
        while true {
            steps += 1
            precondition(steps < 1000, "hand stuck")
            // processNextTurn
            guard !gm.activePlayers.isEmpty, let current = gm.currentPlayer else {
                if endRound() { break } else { continue }
            }
            if current.isAllIn || current.isFolded {
                if gm.activePlayers.filter({ !$0.isAllIn && !$0.isFolded }).isEmpty {
                    if endRound() { break } else { continue }
                }
                gm.moveToNextPlayer(after: current)
                continue
            }
            let action: PlayerAction
            if current.isHuman {
                action = humanDecision(current)
            } else {
                let (profile, state) = gm.aiDecisionInputs(for: current)
                action = AIEngine.decide(for: current, gameState: state, profile: profile, rng: &rng)
            }
            observe(current, action)

            // processPlayerAction, synchronous part.
            let preCallAmount = max(0, gm.currentBet - current.currentBet)
            let preCurrentBet = gm.currentBet
            let executed = gm.executeAction(action, for: current)
            let raisedBet = gm.currentBet > preCurrentBet
            gm.handHistory.recordAction(seat: current.id, action: executed, callAmount: preCallAmount,
                                        raisedBet: raisedBet, isShove: raisedBet && current.hasShoved)
            if gm.shouldEndBettingRound() {
                if endRound() { break }
            } else {
                gm.moveToNextPlayer(after: current)
            }
        }

        let total = gm.players.reduce(0) { $0 + $1.chips } + gm.mainPot.amount
        precondition(total == gm.expectedTotalChips, "chip leak: \(total) vs \(gm.expectedTotalChips)")
        stats.hands += 1
        stats.humanNet += gm.humanPlayer!.chips - humanBefore
        if humanShovedPreflop {
            stats.humanShoves += 1
            if !botCalledShove { stats.shovesUncalled += 1 }
        }
    }

    /// endBettingRound + dealFlop/Turn/River + showdown. True when the hand is over.
    func endRound() -> Bool {
        let inHand = gm.players.filter { $0.isActive && !$0.isFolded }
        if inHand.count == 1 {
            inHand[0].win(amount: gm.mainPot.amount)
            gm.mainPot.reset()
            gm.handHistory.handEnded(wentToShowdown: false, winners: [inHand[0].id])
            return true
        }
        if gm.activePlayers.filter({ !$0.isAllIn && !$0.isFolded }).isEmpty {
            showdown()
            return true
        }
        for p in gm.players { p.hasActed = false; p.currentBet = 0 }
        gm.currentBet = 0
        gm.lastRaiseAmount = gm.bigBlind
        gm.minRaise = gm.bigBlind
        gm.currentBetAllowsRaises = true
        gm.currentPlayerIndex = 0
        switch gm.currentPhase {
        case .preFlop:
            _ = gm.deck.deal()
            gm.communityCards.append(contentsOf: gm.deck.dealMultiple(3))
            gm.currentPhase = .flop
            gm.handHistory.streetBegan(.flop, board: gm.communityCards)
        case .flop, .turn:
            _ = gm.deck.deal()
            if let card = gm.deck.deal() { gm.communityCards.append(card) }
            gm.currentPhase = gm.currentPhase == .flop ? .turn : .river
            gm.handHistory.streetBegan(gm.currentPhase == .turn ? .turn : .river, board: gm.communityCards)
        case .river:
            showdown()
            return true
        default:
            return true
        }
        gm.resetBettingRound()
        return false
    }

    func showdown() {
        gm.currentPhase = .showdown
        gm.dealRemainingCommunityCards()
        gm.determineWinnersWithDelay()
    }
}

// MARK: - Main

let args = CommandLine.arguments
let scenario = args.count > 1 ? args[1] : "shove"
let sessions = args.count > 2 ? Int(args[2])! : 12
let handsPerSession = args.count > 3 ? Int(args[3])! : 100
let players = args.count > 4 ? Int(args[4])! : 5
let chips = args.count > 5 ? Int(args[5])! : 1000
let env = ProcessInfo.processInfo.environment

let human: Human
switch scenario {
case "shove": human = .alwaysShove
case "tight": human = .shoveTop(0.10)
case "flop": human = .flopShove
case "raise": human = .minRaiseAlways
case "station": human = .station
case "straight": human = .straightforward
default: fatalError("unknown scenario \(scenario) — shove, tight, flop, raise, station or straight")
}

struct Config { let label: String; let ai: PokerAIConfig }
var configs: [Config] = [
    Config(label: "Easy   · auto-mix", ai: .init(difficulty: .easy)),
    Config(label: "Medium · auto-mix", ai: .init(difficulty: .medium)),
    Config(label: "Hard   · auto-mix", ai: .init(difficulty: .hard)),
    Config(label: "Expert · auto-mix", ai: .init(difficulty: .expert)),
    Config(label: "Medium · Nit     ", ai: .init(difficulty: .medium, style: .nit)),
    Config(label: "Medium · TAG     ", ai: .init(difficulty: .medium, style: .tag)),
    Config(label: "Medium · LAG     ", ai: .init(difficulty: .medium, style: .lag)),
    Config(label: "Medium · Station ", ai: .init(difficulty: .medium, style: .callingStation)),
    Config(label: "Medium · Maniac  ", ai: .init(difficulty: .medium, style: .maniac)),
    Config(label: "Medium · Pro     ", ai: .init(difficulty: .medium, style: .solverInspired)),
]
if let only = env["ONLY"] { configs = configs.filter { $0.label.lowercased().contains(only.lowercased()) } }

_ = vsRandomEquity
print("\(human.label) · \(players) players · \(chips) chips · \(sessions) sessions × \(handsPerSession) hands per config\n")

let started = Date()
var results = [Stats](repeating: Stats(), count: configs.count * sessions)
let lock = NSLock()
DispatchQueue.concurrentPerform(iterations: configs.count * sessions) { i in
    let session = Session(players: players, chips: chips, config: configs[i / sessions].ai,
                          human: human, seed: UInt64(i) &* 1_000_003 &+ 12345)
    session.run(hands: handsPerSession)
    lock.lock(); results[i] = session.stats; lock.unlock()
}

for (ci, config) in configs.enumerated() {
    var st = Stats()
    for si in 0..<sessions { st.merge(results[ci * sessions + si]) }
    let bigBlind = 20.0
    let bb100 = Double(st.humanNet) / bigBlind / Double(max(1, st.hands)) * 100
    var line = "\(config.label) | human \(String(format: "%+7.1f", bb100)) bb/100"
    if st.humanShoves > 0 {
        let uncalled = 100.0 * Double(st.shovesUncalled) / Double(st.humanShoves)
        line += " | shoves nobody called \(String(format: "%5.1f%%", uncalled))"
        line += " | bot calls a shove \(st.vsShove.pct)"
        line += " [hands 1-10 \(st.vsShoveByHandsSeen[0].pct) · 11-30 \(st.vsShoveByHandsSeen[1].pct) · 31+ \(st.vsShoveByHandsSeen[2].pct)]"
        line += " | TT+ \(st.bigPairs.pct) · AK \(st.aceKing.pct) · ≥52% vs any two \(st.clearCalls.pct)"
    }
    if st.postflopVsShove.n > 0 { line += " | calls a postflop shove \(st.postflopVsShove.pct)" }
    if st.vsSmallRaise.n > 0 { line += " | continues vs a small raise \(st.vsSmallRaise.pct)" }
    print(line)
    if st.humanShoves > 0 {
        let styles = st.vsShoveByStyle.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value.pct)" }
        print("                    by style: " + styles.joined(separator: " · "))
        if env["HANDS"] != nil {
            let row = namedHands.compactMap { nm in st.byHand[nm].map { "\(nm) \($0.pct.trimmingCharacters(in: .whitespaces))" } }
            print("                    by hand:  " + row.joined(separator: " · "))
        }
    }
}
print(String(format: "\n%.1fs", Date().timeIntervalSince(started)))
