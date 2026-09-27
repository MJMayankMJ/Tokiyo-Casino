//
//  TDPGameViewController.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The table, laid out after the "532 Game Screen" handoff: round, score,
//  trump and menu along the top; the two opponents beneath; the trick
//  circle; you; and your hand fanned along the bottom edge.
//
//  It renders whatever `TDPClientView` the driver hands it and posts intents
//  back — identical whether the authority is this device or a phone across
//  the room.
//

import UIKit

final class TDPGameViewController: UIViewController {

    private let driver: TDPGameDriver

    private let header = TDPHeaderView()
    private let leftBadge = TDPOpponentBadge(side: .left)
    private let rightBadge = TDPOpponentBadge(side: .right)
    private let tableArea = UILayoutGuide()
    private let trickTable = TDPTrickTableView()
    private let selfBadge = TDPSelfBadge()
    private let fan = TDPHandFanView()
    private let prompt = TDPPromptCard()
    private let toast = TDPToastView()
    private let curtain = TDPHandoffCurtain()
    /// Everything on the table — shaken when a card is slammed down.
    private let stage = UIView()
    /// Above the table: the big moments' light, sparks and callouts.
    private let effectsLayer = UIView()
    private lazy var moments = TDPMomentEffects(stage: stage, overlay: effectsLayer)
    /// A steal's point shows only when its trick lands in the pile; until
    /// then this seat's count stays one short.
    private var heldPointSeat: TDPSeat?
    private let arrangeView = TDPArrangeView()
    private let countdown = TDPCountdownView(diameter: 120 * TDPTheme.scale)
    private let banner = TDPBannerView()

    /// Settle-up choices being made on this screen, per creditor, reset
    /// each round.
    private var settleSelection: [TDPSeat: TDPSettleMethod] = [:]
    private var settleRound: Int?

    private var lastView: TDPClientView?
    /// First tap picks a card, second tap commits it — the reference's guard
    /// against a stray tap throwing away a trick.
    private var selectedCardID: String?
    /// Pass & play: whose hand the curtain was last lifted for.
    private var revealedSeat: TDPSeat?
    /// A new deal means new hands — the holder must be re-confirmed.
    private var curtainRound: Int?

    // MARK: Init

    init(driver: TDPGameDriver) {
        self.driver = driver
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page
        buildLayout()

        header.menuButton.addTarget(self, action: #selector(didTapMenu), for: .touchUpInside)
        header.onScoresTap = { [weak self] in self?.showScores() }
        fan.onTap = { [weak self] card in self?.didTapCard(card) }
        curtain.onReveal = { [weak self] in
            guard let self, let view = self.lastView else { return }
            self.revealedSeat = view.mySeat
        }

        GameAudio.shared.prepare()
        GameHaptics.shared.prepare()
        driver.onViewChanged = { [weak self] view in self?.render(view) }
        driver.onRejected = { [weak self] reason in
            GameHaptics.shared.play(.invalid)
            self?.toast.show(reason)
        }
        driver.onEnded = { [weak self] reason in self?.showEnded(reason) }
        driver.start()

        if let view = driver.currentView { render(view) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The table is full-bleed; the menu button carries "leave".
        navigationController?.setNavigationBarHidden(true, animated: animated)
        // A stray edge-swipe would abandon the table — for a host, everyone's.
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent { driver.stop() }
    }

    // MARK: Layout

    private func buildLayout() {
        let s = TDPTheme.scale
        let safe = view.safeAreaLayoutGuide
        let side: CGFloat = 24 * s

        [stage, effectsLayer, prompt, toast, curtain].forEach { view.addSubview($0) }
        [header, leftBadge, rightBadge, trickTable, countdown, banner, selfBadge, fan, arrangeView]
            .forEach { stage.addSubview($0) }
        for layer in [stage, effectsLayer] {
            layer.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                layer.topAnchor.constraint(equalTo: view.topAnchor),
                layer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                layer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        effectsLayer.isUserInteractionEnabled = false
        view.addLayoutGuide(tableArea)
        prompt.isHidden = true
        arrangeView.isHidden = true
        countdown.isHidden = true
        banner.isHidden = true
        arrangeView.onReorder = { [weak self] order in
            self?.driver.send(TDPIntent(kind: .arrange, order: order, done: false))
        }
        arrangeView.onDone = { [weak self] order in
            self?.driver.send(TDPIntent(kind: .arrange, order: order, done: true))
        }

        // The circle is 280pt in the reference; smaller phones shrink it to
        // whatever fits between the opponents and you.
        let preferred = trickTable.widthAnchor.constraint(equalToConstant: 280 * s)
        preferred.priority = .defaultHigh

        let promptCentered = prompt.centerYAnchor.constraint(equalTo: tableArea.centerYAnchor)
        promptCentered.priority = .defaultHigh

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 6),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: side),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -side),

            leftBadge.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 22 * s),
            leftBadge.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: side),
            rightBadge.topAnchor.constraint(equalTo: leftBadge.topAnchor),
            rightBadge.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -side),
            rightBadge.leadingAnchor.constraint(greaterThanOrEqualTo: leftBadge.trailingAnchor, constant: 12),

            // Room above the circle for its "Trick 3 of 10 · ♠ led" caption.
            tableArea.topAnchor.constraint(equalTo: leftBadge.bottomAnchor, constant: 36 * s),
            tableArea.bottomAnchor.constraint(equalTo: selfBadge.topAnchor, constant: -20 * s),
            tableArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            trickTable.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trickTable.centerYAnchor.constraint(equalTo: tableArea.centerYAnchor),
            trickTable.heightAnchor.constraint(equalTo: trickTable.widthAnchor),
            trickTable.widthAnchor.constraint(lessThanOrEqualToConstant: 280 * s),
            trickTable.heightAnchor.constraint(lessThanOrEqualTo: tableArea.heightAnchor),
            trickTable.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -2 * side),
            preferred,

            selfBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selfBadge.bottomAnchor.constraint(equalTo: fan.topAnchor, constant: -4 * s),

            fan.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fan.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fan.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            fan.heightAnchor.constraint(equalToConstant: 164 * s),

            prompt.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            prompt.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            prompt.widthAnchor.constraint(lessThanOrEqualToConstant: 360 * s),
            prompt.topAnchor.constraint(greaterThanOrEqualTo: leftBadge.bottomAnchor, constant: 10),
            prompt.bottomAnchor.constraint(lessThanOrEqualTo: selfBadge.topAnchor, constant: -10),
            promptCentered,

            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: selfBadge.topAnchor, constant: -10),
            toast.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),

            arrangeView.topAnchor.constraint(equalTo: leftBadge.bottomAnchor, constant: 18 * s),
            arrangeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arrangeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arrangeView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            countdown.centerXAnchor.constraint(equalTo: trickTable.centerXAnchor),
            countdown.centerYAnchor.constraint(equalTo: trickTable.centerYAnchor),

            banner.topAnchor.constraint(equalTo: trickTable.topAnchor, constant: 30 * s),
            banner.leadingAnchor.constraint(equalTo: trickTable.leadingAnchor, constant: 10),
            banner.trailingAnchor.constraint(equalTo: trickTable.trailingAnchor, constant: -10),

            curtain.topAnchor.constraint(equalTo: view.topAnchor),
            curtain.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            curtain.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            curtain.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: Render

    private func render(_ view: TDPClientView) {
        let previous = lastView
        lastView = view
        dropStaleSelection(view)
        let stolen = updatePointHold(from: previous, to: view)

        let me = view.mySeat
        let leftSeat = TDPRoles.nextSeat(me)     // plays after you
        let rightSeat = TDPRoles.prevSeat(me)    // plays before you
        let seats = Dictionary(view.seats.map { ($0.seat, $0) }, uniquingKeysWith: { a, _ in a })
        let acting = actingSeats(view)

        header.configure(round: max(view.roundNumber, 1),
                         of: view.targetRounds,
                         points: seats[me]?.score ?? 0,
                         trump: view.trump,
                         trumpDetail: view.revealedTrumpCard.map { "\($0.description) shown" })

        configure(leftBadge, with: seats[leftSeat], tint: .amber, active: acting.contains(leftSeat))
        configure(rightBadge, with: seats[rightSeat], tint: .blue, active: acting.contains(rightSeat))

        let myInfo = seats[me]
        let (status, isAction) = statusLine(view)
        let held = heldPointSeat != nil && heldPointSeat == me ? 1 : 0
        selfBadge.configure(name: driver.isSharedDevice ? (myInfo?.name ?? "You") : "You",
                            tally: tally(myInfo, held: held),
                            quotaMet: quotaMet(myInfo, held: held),
                            status: status,
                            statusIsAction: isAction,
                            isActive: acting.contains(me),
                            chip: targetChip(myInfo),
                            // A shared phone has several "you"s; only the owner has a photo.
                            photo: driver.isSharedDevice ? nil : PlayerProfile.photo)

        renderTable(view, previous: previous, claiming: stolen)
        renderHand(view, animated: previous != nil)
        renderPrompt(view)
        renderArrange(view)
        renderCountdownAndBanner(view)
        renderCurtain(view)
        if let previous { playFeedback(from: previous, to: view) }
    }

    // MARK: Sound and feel

    /// Sounds for what just happened at the table, and a haptic only when
    /// it happened to you. Worked out from the change between two views, so
    /// it is the same for a bot, a friend's phone or this one.
    private func playFeedback(from old: TDPClientView, to new: TDPClientView) {
        let audio = GameAudio.shared
        let me = new.mySeat
        // A shared phone swaps whose hand it shows; that is not a deal.
        let sameSeat = old.mySeat == new.mySeat

        if new.roundNumber != old.roundNumber, new.roundNumber > 0 {
            audio.play(.shuffle)
        }

        // Cards arriving in your hand: the deal, or a card handed back.
        let gained = new.myHand.count - old.myHand.count
        if sameSeat, gained > 0, new.roundNumber == old.roundNumber || old.myHand.isEmpty {
            audio.play(.deal, times: min(gained, 5), every: 0.07)
        }

        if old.trump == nil, new.trump != nil {
            audio.play(.flip)
        }

        // A card lands on the table — yours a touch louder. Your first cut
        // of a suit is thrown down hard.
        if new.currentTrick.count > old.currentTrick.count, let landed = new.currentTrick.last {
            if driver.localSeats.contains(landed.seat), let trump = new.trump,
               TDPMoments.isFirstCut(play: landed, trick: new.currentTrick, trump: trump, earlier: new.roundTricks),
               let card = trickTable.cardView(at: spot(landed.seat, me: me)) {
                moments.slam(card, card: landed.card, trump: trump)
            } else {
                audio.play(.play, volume: landed.seat == me ? 1 : 0.75)
            }
        }

        // The trick is decided. Yours: the burst for a first cut; nothing yet
        // for a steal — that waits for the trick to be taken; a small tap
        // otherwise.
        if new.phase == .trickResolve, old.phase != .trickResolve,
           let winner = new.lastTrickWinnerSeat, driver.localSeats.contains(winner) {
            switch moment(in: new, winner: winner) {
            case .firstCut?:
                if let play = new.currentTrick.first(where: { $0.seat == winner }),
                   let card = trickTable.cardView(at: spot(winner, me: me)) {
                    moments.burst(card, card: play.card, callout: callout(for: .firstCut))
                }
            case .steal?:
                break
            case nil:
                GameHaptics.shared.play(.trickWon)
            }
        }
        if old.phase == .trickResolve, new.phase != .trickResolve {
            audio.play(.sweep, volume: 0.8)
        }

        // The pull: a card leaves the fan, and later one comes back.
        if let before = old.khichai, let after = new.khichai, before.debtorSeat == after.debtorSeat {
            if after.fanCount < before.fanCount {
                audio.play(.flip)
                if after.iAmCreditor { GameHaptics.shared.play(.cardPlay) }
            }
        }

        // It's your move — felt, not heard.
        let asks: Set<TDPPrompt> = [.playCard, .chooseTrump, .settleUp, .khichaiDraw, .arrangeCards]
        if asks.contains(new.prompt), new.prompt != old.prompt {
            GameHaptics.shared.play(.yourTurn)
        }

        // Winning the game.
        if new.phase == .sessionEnd, old.phase != .sessionEnd {
            let top = new.seats.map(\.score).max() ?? 0
            if new.seats.first(where: { $0.seat == me })?.score == top {
                GameHaptics.shared.play(.win)
            }
        }
    }

    /// The moment in a trick a seat on this phone just won. A steal needs
    /// that seat's hand, which this view only has for its own seat.
    private func moment(in view: TDPClientView, winner: TDPSeat) -> TDPMoment? {
        if winner == view.mySeat {
            return TDPMoments.moment(trick: view.currentTrick, winner: winner, winnerHand: view.myHand,
                                     trump: view.trump, earlier: view.roundTricks)
        }
        guard let play = view.currentTrick.first(where: { $0.seat == winner }),
              TDPMoments.isFirstCut(play: play, trick: view.currentTrick, trump: view.trump,
                                    earlier: view.roundTricks) else { return nil }
        return .firstCut
    }

    private func callout(for moment: TDPMoment) -> String {
        switch moment {
        case .firstCut:        return "CUT!"
        case .steal(let rank): return "\(rank.shortString) STEALS IT"
        }
    }

    private func configure(_ badge: TDPOpponentBadge, with seat: TDPSeatView?, tint: TDPTheme.Tint, active: Bool) {
        guard let seat else { badge.isHidden = true; return }
        badge.isHidden = false
        var detail = "\(seat.handCount) card\(seat.handCount == 1 ? "" : "s")"
        if seat.kind == "ai" { detail += " · bot" }
        if !seat.isConnected { detail += " · offline" }
        badge.configure(name: seat.name, tally: tally(seat), quotaMet: quotaMet(seat),
                        detail: detail, isActive: active, tint: tint, isOffline: !seat.isConnected,
                        chip: targetChip(seat))
    }

    /// Targets are known once there is a dealer. A target can reach zero
    /// (or below) when tricks were given up, so test the role quota.
    private func targetKnown(_ seat: TDPSeatView) -> Bool { seat.baseQuota > 0 || seat.quota > 0 }

    /// `held` tricks are won but not yet shown — a steal still on its way
    /// to the pile.
    private func tally(_ seat: TDPSeatView?, held: Int = 0) -> String {
        guard let seat else { return "—" }
        let won = max(0, seat.tricksWon - held)
        return targetKnown(seat) ? "\(won) / \(max(0, seat.quota))" : "\(won)"
    }

    private func quotaMet(_ seat: TDPSeatView?, held: Int = 0) -> Bool {
        guard let seat, targetKnown(seat) else { return false }
        return seat.tricksWon - held >= seat.quota
    }

    /// A steal is celebrated once the point is confirmed — as the trick is
    /// taken — so its count waits until then. Returns the steal's rank when
    /// this update takes that trick, which the table then claims instead of
    /// sweeping; otherwise any hold is dropped once its trick is gone.
    private func updatePointHold(from previous: TDPClientView?, to view: TDPClientView) -> Rank? {
        if let previous, view.phase == .trickResolve, previous.phase != .trickResolve,
           let winner = view.lastTrickWinnerSeat, winner == view.mySeat,
           case .steal? = moment(in: view, winner: winner) {
            heldPointSeat = winner
            return nil
        }
        let taken = previous?.phase == .trickResolve && view.currentTrick.isEmpty && view.phase != .trickResolve
        if taken, let previous, heldPointSeat == previous.mySeat, view.mySeat == previous.mySeat,
           trickTable.cardView(at: .bottom) != nil,
           case .steal(let rank)? = moment(in: previous, winner: previous.mySeat) {
            return rank                     // the hold lifts when the claim lands
        }
        if taken || view.roundNumber != previous?.roundNumber { heldPointSeat = nil }
        return nil
    }

    /// "5 → 3" when this round's target moved because tricks were given up.
    private func targetChip(_ seat: TDPSeatView?) -> String? {
        guard let seat, seat.baseQuota > 0, seat.quota != seat.baseQuota else { return nil }
        return "\(seat.baseQuota) \u{2192} \(max(0, seat.quota))"
    }

    /// Seats the table is waiting on — they get the glowing ring.
    private func actingSeats(_ view: TDPClientView) -> Set<TDPSeat> {
        switch view.phase {
        case .play:
            return view.currentTurnSeat.map { [$0] } ?? []
        case .trumpSelect:
            let selector = view.seats.first { $0.role == TDPRole.trumpSelector.rawValue }?.seat
            return selector.map { [$0] } ?? []
        case .settle:
            return Set(view.settlement?.waitingOn ?? [])
        case .khichai:
            guard let pull = view.khichai else { return [] }
            return [pull.isArranging ? pull.debtorSeat : pull.creditorSeat]
        default:
            return []
        }
    }

    private func name(_ seat: TDPSeat?, in view: TDPClientView) -> String {
        guard let seat else { return "—" }
        if seat == view.mySeat && !driver.isSharedDevice { return "You" }
        return view.seats.first { $0.seat == seat }?.name ?? "—"
    }

    // MARK: Status line under "You"

    private func statusLine(_ view: TDPClientView) -> (String, Bool) {
        switch view.prompt {
        case .playCard:
            if selectedCardID != nil { return ("Tap again to play", true) }
            guard let lead = view.leadSuit else { return ("Your lead", true) }
            let canFollow = view.myHand.contains { $0.suit == lead }
            return (canFollow ? "Your turn · follow \(TDPFormat.symbol(lead))" : "Your turn · play any card", true)
        case .chooseTrump:
            return ("Call trump", true)
        case .settleUp:
            return ("Settle up", true)
        case .arrangeCards:
            return ("Arrange your cards", true)
        case .khichaiDraw:
            guard let pull = view.khichai, pull.pullTotal > 1 else { return ("Pull a card", true) }
            return ("Pull a card · \(pull.pullNumber) of \(pull.pullTotal)", true)
        case .khichaiReturn:
            return (selectedCardID == nil ? "Give one card back" : "Tap again to give it", true)
        default:
            break
        }

        switch view.phase {
        case .play:
            if view.currentTrick.contains(where: { $0.seat == view.mySeat }) { return ("Card played", false) }
            return ("Waiting for \(name(view.currentTurnSeat, in: view))", false)
        case .trickResolve:
            let winner = view.lastTrickWinnerSeat
            return (winner == view.mySeat ? "You take the trick" : "\(name(winner, in: view)) takes the trick", false)
        case .trumpSelect:
            let selector = view.seats.first { $0.role == TDPRole.trumpSelector.rawValue }?.seat
            return ("\(name(selector, in: view)) is calling trump", false)
        case .dealerDraw, .dealFirstFive, .dealThree, .dealTwo:
            return ("Dealing…", false)
        case .settle:
            let waiting = (view.settlement?.waitingOn ?? []).map { name($0, in: view) }
            guard !waiting.isEmpty else { return ("Settling up", false) }
            return ("Waiting for \(waiting.joined(separator: " and "))", false)
        case .khichai:
            guard let pull = view.khichai else { return ("Settling up", false) }
            if pull.isArranging {
                if pull.iAmCreditor { return ("You pull next", false) }
                return ("\(name(pull.debtorSeat, in: view)) is arranging", false)
            }
            if pull.iAmDebtor { return ("\(name(pull.creditorSeat, in: view)) is pulling from you", false) }
            return ("\(name(pull.creditorSeat, in: view)) is pulling from \(name(pull.debtorSeat, in: view))", false)
        case .roundEnd:
            return ("Round over", false)
        case .sessionEnd:
            return ("Session over", false)
        case .lobby:
            return ("Waiting for players", false)
        }
    }

    // MARK: Trick circle

    private func spot(_ seat: TDPSeat, me: TDPSeat) -> TDPTrickTableView.Spot {
        if seat == me { return .bottom }
        return seat == TDPRoles.nextSeat(me) ? .left : .right
    }

    /// `claiming` is the rank of a steal whose trick this update takes.
    private func renderTable(_ view: TDPClientView, previous: TDPClientView?, claiming: Rank?) {
        let me = view.mySeat

        // A trick was just collected — sweep it toward the winner, or, for a
        // steal, fly it into your count.
        if previous?.phase == .trickResolve, view.currentTrick.isEmpty, view.phase != .trickResolve {
            if let rank = claiming, let winner = trickTable.cardView(at: .bottom) {
                moments.claim(trickTable.takeCards(), winner: winner, into: selfBadge.tallyView,
                              callout: callout(for: .steal(rank))) { [weak self] in
                    guard let self else { return }
                    self.heldPointSeat = nil
                    if let latest = self.lastView { self.render(latest) }      // the point lands
                }
            } else {
                trickTable.collect(toward: previous?.lastTrickWinnerSeat.map { spot($0, me: me) })
            }
        }

        let plays = view.currentTrick.map { (spot: spot($0.seat, me: me), card: $0.card) }
        let pending: TDPTrickTableView.Spot? = view.phase == .play
            ? view.currentTurnSeat.map { spot($0, me: me) } : nil
        let winner: TDPTrickTableView.Spot? = view.phase == .trickResolve
            ? view.lastTrickWinnerSeat.map { spot($0, me: me) } : nil

        trickTable.configure(plays: plays, pending: pending, winner: winner,
                             caption: caption(view), animated: previous != nil)
    }

    private func caption(_ view: TDPClientView) -> String {
        let trick = "Trick \(min(view.trickNumber + 1, 10)) of 10"
        switch view.phase {
        case .play:
            return view.leadSuit.map { "\(trick) · \(TDPFormat.symbol($0)) led" } ?? trick
        case .trickResolve:
            let winner = view.lastTrickWinnerSeat
            return "\(trick) · \(name(winner, in: view)) \(winner == view.mySeat && !driver.isSharedDevice ? "take" : "takes") it"
        case .dealerDraw:                         return "Drawing for the deal"
        case .dealFirstFive, .dealThree, .dealTwo: return "Dealing"
        case .trumpSelect:                        return "Calling trump"
        case .settle:                             return "Settling up"
        case .khichai:
            guard let pull = view.khichai else { return "Pulling" }
            if pull.isArranging { return "Arranging" }
            return pull.pullTotal > 1 ? "Pull \(pull.pullNumber) of \(pull.pullTotal)" : "Pulling"
        case .roundEnd:                           return "Round \(view.roundHistory.count) complete"
        case .sessionEnd:                         return "Session complete"
        case .lobby:                              return "Waiting for players"
        }
    }

    // MARK: Hand

    private func renderHand(_ view: TDPClientView, animated: Bool) {
        // Pulling: the fan becomes the debtor's face-down hand. Positions
        // only — the host shuffled them, so an index names no card.
        // Calling trump: the five cards are shown large in the sheet instead.
        fan.alpha = view.prompt == .chooseTrump ? 0 : 1

        if let pull = view.khichai, pull.iAmCreditor, pull.drawnCard == nil {
            // While the debtor is still arranging, the fan is inert.
            let live = !pull.isArranging
            let items = (0..<pull.fanCount).map {
                TDPHandFanView.Item(key: "fan-\($0)", card: nil, tag: $0,
                                    enabled: live, dimmed: false, lift: live ? .hint : .none, highlighted: false)
            }
            fan.setItems(items, animated: animated)
            return
        }

        let legal = Set(view.myLegalCardIDs)
        let returns = view.khichai?.legalReturnIDs.map(Set.init)
        let drawnID = view.khichai?.drawnCard?.tdpID

        let items = view.myHand.enumerated().map { index, card -> TDPHandFanView.Item in
            let id = card.tdpID
            let selected = id == selectedCardID
            if let returns {
                // Choosing what to hand back after a pull.
                let allowed = returns.contains(id)
                return .init(key: id, card: card, tag: index, enabled: allowed, dimmed: !allowed,
                             lift: selected ? .selected : .none, highlighted: id == drawnID)
            }
            if view.prompt == .playCard {
                let allowed = legal.contains(id)
                return .init(key: id, card: card, tag: index, enabled: allowed, dimmed: !allowed,
                             lift: selected ? .selected : (allowed ? .hint : .none), highlighted: false)
            }
            // Not your move: readable, but inert.
            return .init(key: id, card: card, tag: index, enabled: false, dimmed: false,
                         lift: .none, highlighted: false)
        }
        fan.setItems(items, animated: animated)
    }

    private func dropStaleSelection(_ view: TDPClientView) {
        guard let selected = selectedCardID else { return }
        let valid: Bool
        switch view.prompt {
        case .playCard:      valid = view.myLegalCardIDs.contains(selected)
        case .khichaiReturn: valid = view.khichai?.legalReturnIDs?.contains(selected) ?? false
        default:             valid = false
        }
        if !valid { selectedCardID = nil }
    }

    private func didTapCard(_ card: TDPCardButton) {
        guard let view = lastView else { return }

        if let pull = view.khichai, pull.iAmCreditor {
            guard pull.drawnCard != nil else {
                driver.send(TDPIntent(kind: .khichaiDraw, fanIndex: card.tag))
                return
            }
            guard let id = card.card?.tdpID else { return }
            if selectedCardID == id {
                commitReturn()
            } else {
                selectedCardID = id
                render(view)
            }
            return
        }

        guard view.prompt == .playCard, let id = card.card?.tdpID else { return }
        if selectedCardID == id {
            selectedCardID = nil
            GameHaptics.shared.play(.cardPlay)
            driver.send(TDPIntent(kind: .playCard, cardID: id))
        } else {
            selectedCardID = id
            GameHaptics.shared.play(.select)
            render(view)
        }
    }

    // MARK: Prompt sheet

    private func renderPrompt(_ view: TDPClientView) {
        switch view.prompt {
        case .chooseTrump:   buildTrumpPrompt(view)
        case .settleUp:      buildSettlePrompt(view)
        case .khichaiDraw:   buildDrawPrompt(view)
        case .khichaiReturn: buildReturnPrompt(view)
        case .roundEnd:      buildRoundPrompt(view)
        default:
            setPrompt(visible: false)
            return
        }
        prompt.finish()
        setPrompt(visible: true)
    }

    private func setPrompt(visible: Bool) {
        guard prompt.isHidden == visible else { return }
        if visible {
            prompt.alpha = 0
            prompt.transform = CGAffineTransform(translationX: 0, y: 12)
            prompt.isHidden = false
        }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut]) {
            self.prompt.alpha = visible ? 1 : 0
            self.prompt.transform = .identity
            // The circle is empty at these moments; the sheet takes its place.
            self.trickTable.alpha = visible ? 0 : 1
        } completion: { _ in
            if !visible { self.prompt.isHidden = true }
        }
    }

    private func buildTrumpPrompt(_ view: TDPClientView) {
        prompt.reset(title: "Call trump", subtitle: nil)
        // Your first five, large enough to read, right where you choose.
        let five = UIStackView()
        five.spacing = 7
        five.alignment = .center
        let size = CGSize(width: 54 * TDPTheme.scale, height: 76 * TDPTheme.scale)
        for card in view.myHand.prefix(5) {
            let face = TDPCardButton(card: card, elevation: .hand)
            face.isUserInteractionEnabled = false
            face.translatesAutoresizingMaskIntoConstraints = false
            face.widthAnchor.constraint(equalToConstant: size.width).isActive = true
            face.heightAnchor.constraint(equalToConstant: size.height).isActive = true
            five.addArrangedSubview(face)
        }
        let centered = UIStackView(arrangedSubviews: [UIView(), five, UIView()])
        centered.distribution = .equalCentering
        prompt.bodyStack.addArrangedSubview(centered)
        for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
            let button = TDPSuitButton(suit: suit)
            button.addTarget(self, action: #selector(didTapTrumpSuit(_:)), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(button)
        }
        let seventh = TDPButton(title: "Open 7th card", style: .secondary)
        seventh.addTarget(self, action: #selector(didTapTrumpSeventh), for: .touchUpInside)
        let highest = TDPButton(title: "Best of next 3", style: .secondary)
        highest.addTarget(self, action: #selector(didTapTrumpHighest), for: .touchUpInside)
        prompt.secondaryRow.addArrangedSubview(seventh)
        prompt.secondaryRow.addArrangedSubview(highest)
    }

    private func buildDrawPrompt(_ view: TDPClientView) {
        let debtor = name(view.khichai?.debtorSeat, in: view)
        let pull = view.khichai
        let count = (pull?.pullTotal ?? 1) > 1 ? " · \(pull!.pullNumber) of \(pull!.pullTotal)" : ""
        prompt.reset(title: "Pull a card from \(debtor)\(count)", subtitle: "Tap any card below")
        let random = TDPButton(title: "Pick for me", style: .secondary)
        random.addTarget(self, action: #selector(didTapRandomPull), for: .touchUpInside)
        prompt.primaryRow.addArrangedSubview(random)
    }

    // MARK: Settling up

    private func buildSettlePrompt(_ view: TDPClientView) {
        let mine = view.settlement?.mine ?? []
        guard !mine.isEmpty else { return }
        if settleRound != view.roundNumber || Set(settleSelection.keys) != Set(mine.map(\.creditorSeat)) {
            settleRound = view.roundNumber
            settleSelection = Dictionary(uniqueKeysWithValues: mine.map {
                ($0.creditorSeat, $0.giveTricksLocked ? TDPSettleMethod.giveCards : .giveTricks)
            })
        }
        let seats = Dictionary(view.seats.map { ($0.seat, $0) }, uniquingKeysWith: { a, _ in a })
        let myBase = seats[view.mySeat]?.baseQuota ?? 0
        let total = mine.reduce(0) { $0 + $1.amount }

        if mine.count == 1, let debt = mine.first {
            buildSingleSettle(view, debt: debt, myBase: myBase, seats: seats)
        } else {
            prompt.reset(title: "You owe \(total) tricks", subtitle: nil)
            for debt in mine { prompt.bodyStack.addArrangedSubview(settleRow(view, debt: debt)) }
            prompt.bodyStack.addArrangedSubview(settleSummary(mine: mine, myBase: myBase))
            let confirm = TDPButton(title: "Confirm", style: .primary)
            confirm.addTarget(self, action: #selector(didTapConfirmSettle), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(confirm)
        }
    }

    private func buildSingleSettle(_ view: TDPClientView, debt: TDPSettleDebt,
                                   myBase: Int, seats: [TDPSeat: TDPSeatView]) {
        let creditor = name(debt.creditorSeat, in: view)
        let n = debt.amount
        let tricks = "\(n) trick\(n == 1 ? "" : "s")"
        let cards = "\(n) card\(n == 1 ? "" : "s")"
        prompt.reset(title: "You owe \(creditor) \(tricks)", subtitle: nil)

        // One short line each: what happens to you.
        let giveUp = TDPOptionCard(
            title: "Give up \(tricks)",
            chip: nil,
            body: debt.giveTricksLocked
                ? "Not allowed twice in a row"
                : "Your target \(myBase) \u{2192} \(myBase + n)")
        giveUp.tag = debt.creditorSeat * 10
        giveUp.isEnabled = !debt.giveTricksLocked
        giveUp.isSelected = settleSelection[debt.creditorSeat] == .giveTricks
        giveUp.addTarget(self, action: #selector(didTapSettleOption(_:)), for: .touchUpInside)

        let giveCards = TDPOptionCard(
            title: "Give \(cards)",
            chip: nil,
            body: "\(creditor) pulls blind")
        giveCards.tag = debt.creditorSeat * 10 + 1
        giveCards.isSelected = settleSelection[debt.creditorSeat] == .giveCards
        giveCards.addTarget(self, action: #selector(didTapSettleOption(_:)), for: .touchUpInside)

        prompt.bodyStack.addArrangedSubview(giveUp)
        prompt.bodyStack.addArrangedSubview(giveCards)

        let confirm = TDPButton(title: "Confirm", style: .primary)
        confirm.addTarget(self, action: #selector(didTapConfirmSettle), for: .touchUpInside)
        prompt.primaryRow.addArrangedSubview(confirm)
    }

    private func settleRow(_ view: TDPClientView, debt: TDPSettleDebt) -> UIView {
        let seat = view.seats.first { $0.seat == debt.creditorSeat }
        let tint: TDPTheme.Tint = debt.creditorSeat == TDPRoles.nextSeat(view.mySeat) ? .amber : .blue
        let avatar = TDPAvatarView(side: 36, radius: 12)
        avatar.setName(seat?.name ?? "?")
        avatar.tint = tint
        let nameLabel = UILabel()
        nameLabel.text = name(debt.creditorSeat, in: view)
        nameLabel.font = TDPTheme.font(14, .medium)
        nameLabel.textColor = TDPTheme.ink
        let owed = UILabel()
        owed.text = debt.giveTricksLocked ? "owed \(debt.amount) · cards only" : "owed \(debt.amount)"
        owed.font = TDPTheme.mono(12)
        owed.textColor = TDPTheme.muted
        let labels = UIStackView(arrangedSubviews: [nameLabel, owed])
        labels.axis = .vertical
        labels.spacing = 2

        let choice = TDPSegmentedChoice(first: "Give up \(debt.amount)", second: "Give cards")
        choice.tag = debt.creditorSeat
        choice.isFirstEnabled = !debt.giveTricksLocked
        choice.select(settleSelection[debt.creditorSeat] == .giveTricks ? 0 : 1)
        choice.addTarget(self, action: #selector(didChangeSettleChoice(_:)), for: .valueChanged)
        choice.widthAnchor.constraint(equalToConstant: 184 * TDPTheme.scale).isActive = true

        let row = UIStackView(arrangedSubviews: [avatar, labels, choice])
        row.spacing = 10
        row.alignment = .center
        return row
    }

    /// "Your target 3 → 5" — the one consequence worth spelling out.
    private func settleSummary(mine: [TDPSettleDebt], myBase: Int) -> UIView {
        let added = mine.filter { settleSelection[$0.creditorSeat] == .giveTricks }.reduce(0) { $0 + $1.amount }
        let summary = UILabel()
        summary.text = added == 0 ? "Your target stays \(myBase)" : "Your target \(myBase) \u{2192} \(myBase + added)"
        summary.font = TDPTheme.mono(13)
        summary.textColor = added == 0 ? TDPTheme.muted : TDPTheme.ink
        summary.textAlignment = .center
        return summary
    }

    @objc private func didTapSettleOption(_ sender: TDPOptionCard) {
        guard sender.isEnabled, let view = lastView else { return }
        settleSelection[sender.tag / 10] = sender.tag % 10 == 0 ? .giveTricks : .giveCards
        render(view)
    }

    @objc private func didChangeSettleChoice(_ sender: TDPSegmentedChoice) {
        guard let view = lastView else { return }
        settleSelection[sender.tag] = sender.selectedIndex == 0 ? .giveTricks : .giveCards
        render(view)
    }

    @objc private func didTapConfirmSettle() {
        guard let mine = lastView?.settlement?.mine, !mine.isEmpty else { return }
        let lines = mine.map {
            TDPSettleChoice(creditorSeat: $0.creditorSeat,
                            method: $0.giveTricksLocked ? .giveCards : (settleSelection[$0.creditorSeat] ?? .giveCards))
        }
        driver.send(TDPIntent(kind: .settle, settlements: lines))
    }

    // MARK: Arranging

    private func renderArrange(_ view: TDPClientView) {
        let arranging = view.prompt == .arrangeCards
        arrangeView.isHidden = !arranging
        trickTable.isHidden = arranging
        selfBadge.isHidden = arranging
        fan.isHidden = arranging
        guard arranging, let pull = view.khichai else {
            arrangeView.clear()
            return
        }
        arrangeView.configure(cards: view.myArrangement ?? view.myHand,
                              puller: name(pull.creditorSeat, in: view),
                              count: pull.pullTotal,
                              seconds: pull.arrangeSecondsLeft)
    }

    private func renderCountdownAndBanner(_ view: TDPClientView) {
        // Everyone but the arranger watches the same clock on the table.
        if let pull = view.khichai, pull.isArranging, !pull.iAmDebtor {
            if countdown.isHidden { countdown.reset() }
            countdown.isHidden = false
            countdown.set(seconds: pull.arrangeSecondsLeft ?? 10, of: 10)
        } else {
            countdown.isHidden = true
        }

        // Targets moved while settling up: say so as play begins.
        let opening = view.phase == .play && view.trickNumber == 0 && view.currentTrick.isEmpty
        guard opening, !view.concessions.isEmpty else { banner.isHidden = true; return }
        let target = { (seat: TDPSeat) in max(0, view.seats.first { $0.seat == seat }?.quota ?? 0) }
        let titles = view.concessions.map { c in
            "\(name(c.debtor, in: view)) gave up \(c.amount) trick\(c.amount == 1 ? "" : "s")"
                + (view.concessions.count > 1 ? " to \(name(c.creditor, in: view))" : "")
        }
        var involved: [TDPSeat] = []
        for c in view.concessions {
            for seat in [c.creditor, c.debtor] where !involved.contains(seat) { involved.append(seat) }
        }
        let needs = involved.map { seat -> String in
            seat == view.mySeat && !driver.isSharedDevice
                ? "You need \(target(seat))" : "\(name(seat, in: view)) needs \(target(seat))"
        }
        banner.configure(title: titles.joined(separator: " · "),
                         subtitle: needs.joined(separator: " · "))
        banner.isHidden = false
    }

    private func buildReturnPrompt(_ view: TDPClientView) {
        let drawn = view.khichai?.drawnCard?.description ?? "a card"
        let debtor = name(view.khichai?.debtorSeat, in: view)
        if let selected = selectedCardID, let card = Card(tdpID: selected) {
            prompt.reset(title: "Give \(card.description) to \(debtor)?", subtitle: nil)
            let confirm = TDPButton(title: "Confirm", style: .primary)
            confirm.addTarget(self, action: #selector(didTapConfirmReturn), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(confirm)
        } else {
            // Any card may go back — the outlined one you just drew included.
            prompt.reset(title: "You got \(drawn)", subtitle: "Give any one card back")
        }
    }

    private func buildRoundPrompt(_ view: TDPClientView) {
        let final = view.phase == .sessionEnd

        if final {
            let top = view.seats.map(\.score).max() ?? 0
            let leaders = view.seats.filter { $0.score == top }.map { name($0.seat, in: view) }
            let verdict = leaders.count > 1
                ? "\(leaders.joined(separator: " and ")) tie"
                : (leaders.first == "You" ? "You win" : "\(leaders.first ?? "—") wins")
            prompt.reset(title: verdict, subtitle: "Final scores · \(view.roundHistory.count) rounds")
        } else {
            prompt.reset(title: "Round \(view.roundHistory.count) done", subtitle: nil)
        }

        // This round and the totals; at the end, just the totals — every
        // round is one tap away in the score sheet.
        let rounds = final ? [] : Array(view.roundHistory.suffix(1))
        prompt.bodyStack.addArrangedSubview(TDPScoreGrid.make(from: view, rounds: rounds) { [unowned self] seat in
            self.name(seat, in: view)
        })

        if final {
            buildExtendVote(view)
        } else if view.isHost {
            // The length was agreed before the deal, so there is no ending
            // early — only the next round.
            let next = TDPButton(title: "Next round", style: .primary)
            next.addTarget(self, action: #selector(didTapNextRound), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(next)
        } else {
            let waiting = UILabel()
            waiting.text = "Waiting for the host…"
            waiting.font = TDPTheme.font(13)
            waiting.textColor = TDPTheme.muted
            waiting.textAlignment = .center
            prompt.bodyStack.addArrangedSubview(waiting)
        }
    }

    // MARK: Three more rounds?

    /// After the last round. Alone with bots it's your call; with people,
    /// a majority of them decides (both of two, two of three).
    private func buildExtendVote(_ view: TDPClientView) {
        let all = TDPButton(title: "All rounds", style: .quiet)
        all.addTarget(self, action: #selector(didTapScores), for: .touchUpInside)
        let done = TDPButton(title: "Done", style: .secondary)
        done.addTarget(self, action: #selector(didTapLeaveConfirmed), for: .touchUpInside)

        guard let vote = view.extendVote, !vote.ballots.isEmpty else {
            prompt.primaryRow.addArrangedSubview(done)
            return
        }

        if vote.ballots.count == 1, let solo = vote.ballots.first {
            let more = TDPButton(title: "Play 3 more", style: .primary)
            more.tag = solo.seat * 2 + 1
            more.addTarget(self, action: #selector(didTapVote(_:)), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(done)
            prompt.primaryRow.addArrangedSubview(more)
            prompt.secondaryRow.addArrangedSubview(all)
            return
        }

        prompt.bodyStack.addArrangedSubview(voteSummary(view, vote: vote))

        // Buttons for whoever on this phone hasn't voted yet. On a shared
        // phone that can be everyone, one row each.
        let mine = vote.ballots.filter { driver.localSeats.contains($0.seat) && $0.yes == nil }
        if !vote.declined {
            for ballot in mine {
                let shared = mine.count > 1
                let no = TDPButton(title: "No", style: .secondary)
                no.tag = ballot.seat * 2
                let yes = TDPButton(title: shared ? "Yes" : "Play 3 more", style: .primary)
                yes.tag = ballot.seat * 2 + 1
                [no, yes].forEach { $0.addTarget(self, action: #selector(didTapVote(_:)), for: .touchUpInside) }
                let buttons = UIStackView(arrangedSubviews: [no, yes])
                buttons.spacing = 8
                buttons.distribution = .fillEqually
                guard shared else {
                    prompt.bodyStack.addArrangedSubview(buttons)
                    continue
                }
                // One row per person sharing the phone, their name first.
                let who = UILabel()
                who.text = name(ballot.seat, in: view)
                who.font = TDPTheme.font(14, .semibold)
                who.textColor = TDPTheme.ink
                who.setContentHuggingPriority(.defaultLow, for: .horizontal)
                buttons.widthAnchor.constraint(equalToConstant: 200 * TDPTheme.scale).isActive = true
                let row = UIStackView(arrangedSubviews: [who, buttons])
                row.spacing = 10
                row.alignment = .center
                prompt.bodyStack.addArrangedSubview(row)
            }
        }
        if mine.isEmpty || vote.declined {
            prompt.primaryRow.addArrangedSubview(done)
        }
        prompt.secondaryRow.addArrangedSubview(all)
    }

    /// "Play 3 more?" · who has said what · how many it takes.
    private func voteSummary(_ view: TDPClientView, vote: TDPExtendVoteView) -> UIView {
        let question = UILabel()
        let yeses = vote.ballots.filter { $0.yes == true }.count
        if vote.declined {
            question.text = "Not playing on"
        } else {
            question.text = "Play 3 more?  \(yeses) of \(vote.needed) yes"
        }
        question.font = TDPTheme.font(15, .semibold)
        question.textColor = TDPTheme.ink

        let rule = UILabel()
        rule.text = vote.ballots.count == 2 ? "Both players must agree" : "\(vote.needed) of \(vote.ballots.count) must agree"
        rule.font = TDPTheme.font(12)
        rule.textColor = TDPTheme.muted

        let ballots = UIStackView()
        ballots.spacing = 6
        for ballot in vote.ballots {
            let chip = TDPChipLabel()
            let mark = ballot.yes.map { $0 ? "\u{2713}" : "\u{2715}" } ?? "\u{2026}"
            chip.text = "\(name(ballot.seat, in: view)) \(mark)"
            chip.isAccent = ballot.yes == true
            if ballot.yes == false { chip.textColor = TDPTheme.warn }
            chip.accessibilityLabel = "\(name(ballot.seat, in: view)): "
                + (ballot.yes.map { $0 ? "yes" : "no" } ?? "hasn't voted")
            ballots.addArrangedSubview(chip)
        }
        let chips = UIStackView(arrangedSubviews: [UIView(), ballots, UIView()])
        chips.distribution = .equalCentering

        let stack = UIStackView(arrangedSubviews: [question, rule, chips])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.setCustomSpacing(10, after: rule)
        return stack
    }

    @objc private func didTapVote(_ sender: UIButton) {
        let seat = sender.tag / 2
        driver.send(TDPIntent(kind: .voteExtend, accept: sender.tag % 2 == 1), as: seat)
    }

    // MARK: Pass & play

    private func renderCurtain(_ view: TDPClientView) {
        guard driver.isSharedDevice else { curtain.isHidden = true; return }
        if curtainRound != view.roundNumber {
            curtainRound = view.roundNumber
            revealedSeat = nil
        }
        // The only rule that matters for privacy: a hand is on screen only
        // for the seat the curtain was lifted for. Round summaries have
        // empty hands, so they pass straight through.
        guard !view.myHand.isEmpty, revealedSeat != view.mySeat else { return }
        curtain.present(name: view.seats.first { $0.seat == view.mySeat }?.name ?? "the next player")
    }

    // MARK: Actions

    @objc private func didTapTrumpSuit(_ sender: TDPSuitButton) {
        driver.send(TDPIntent(kind: .trumpSuit, suit: sender.suit))
    }
    @objc private func didTapTrumpSeventh() { driver.send(TDPIntent(kind: .trumpSeventh)) }
    @objc private func didTapTrumpHighest() { driver.send(TDPIntent(kind: .trumpHighestOfThree)) }
    @objc private func didTapRandomPull() { driver.send(TDPIntent(kind: .khichaiDraw)) }
    @objc private func didTapNextRound() { driver.send(TDPIntent(kind: .beginNextRound)) }

    @objc private func didTapConfirmReturn() { commitReturn() }

    private func commitReturn() {
        guard let cardID = selectedCardID else { return }
        selectedCardID = nil
        GameHaptics.shared.play(.cardPlay)
        driver.send(TDPIntent(kind: .khichaiReturn, cardID: cardID))
    }

    // MARK: Menu

    @objc private func didTapMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Scores", style: .default) { [weak self] _ in self?.showScores() })
        #if DEBUG
        sheet.addAction(UIAlertAction(title: "Debug · replay first cut", style: .default) { [weak self] _ in
            self?.replayMoment(.firstCut)
        })
        sheet.addAction(UIAlertAction(title: "Debug · replay steal", style: .default) { [weak self] _ in
            self?.replayMoment(.steal(.queen))
        })
        #endif
        sheet.addAction(UIAlertAction(title: "Leave table", style: .destructive) { [weak self] _ in self?.confirmLeave() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = header.menuButton
        sheet.popoverPresentationController?.sourceRect = header.menuButton.bounds
        present(sheet, animated: true)
    }

    @objc private func didTapScores() { showScores() }

    #if DEBUG
    /// Plays a moment on a stand-in card in your spot — for tuning the
    /// effect without setting up the play.
    private func replayMoment(_ moment: TDPMoment) {
        let trump = lastView?.trump ?? .hearts
        let face: Card
        switch moment {
        case .firstCut: face = Card(suit: trump, rank: .nine)
        case .steal:    face = Card(suit: trump == .clubs ? .spades : .clubs, rank: .queen)
        }
        let card = trickTable.debugPlace(face, at: .bottom)
        guard moment == .firstCut else {
            // A steal: the trick is taken into your count.
            let others = [Card(suit: face.suit, rank: .nine), Card(suit: face.suit, rank: .ten)]
            let trick = [trickTable.debugPlace(others[0], at: .left), trickTable.debugPlace(others[1], at: .right), card]
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self else { return }
                self.moments.claim(trick, winner: card, into: self.selfBadge.tallyView,
                                   callout: self.callout(for: moment)) {}
            }
            return
        }
        moments.slam(card, card: face, trump: trump)
        moments.burst(card, card: face, callout: callout(for: moment))
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            UIView.animate(withDuration: 0.25, animations: { card.alpha = 0 }) { _ in card.removeFromSuperview() }
        }
    }
    #endif

    private func showScores() {
        guard let view = lastView, presentedViewController == nil else { return }
        let sheet = TDPScoresViewController(view: view) { [weak self] seat in
            self?.name(seat, in: view) ?? "—"
        }
        sheet.presentAsSheet(from: self)
    }

    private func confirmLeave() {
        let alert = UIAlertController(title: "Leave the table?",
                                      message: "The game in progress will end.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Stay", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.didTapLeaveConfirmed()
        })
        present(alert, animated: true)
    }

    @objc private func didTapLeaveConfirmed() {
        driver.stop()
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func showEnded(_ reason: String) {
        let alert = UIAlertController(title: "Table ended", message: reason, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.didTapLeaveConfirmed()
        })
        present(alert, animated: true)
    }
}
