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
    private let arrangeView = TDPArrangeView()
    private let countdown = TDPCountdownView(diameter: 120 * TDPTheme.scale)
    private let banner = TDPBannerView()

    /// Settle-up choices being made on this screen, per creditor, reset
    /// each round.
    private var settleSelection: [TDPSeat: TDPSettleMethod] = [:]
    private var settleRound: Int?
    private var showWhy = false

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
        fan.onTap = { [weak self] card in self?.didTapCard(card) }
        curtain.onReveal = { [weak self] in
            guard let self, let view = self.lastView else { return }
            self.revealedSeat = view.mySeat
        }

        driver.onViewChanged = { [weak self] view in self?.render(view) }
        driver.onRejected = { [weak self] reason in self?.toast.show(reason) }
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

        [header, leftBadge, rightBadge, trickTable, countdown, banner, selfBadge, fan,
         arrangeView, prompt, toast, curtain]
            .forEach { view.addSubview($0) }
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

        let me = view.mySeat
        let leftSeat = TDPRoles.nextSeat(me)     // plays after you
        let rightSeat = TDPRoles.prevSeat(me)    // plays before you
        let seats = Dictionary(view.seats.map { ($0.seat, $0) }, uniquingKeysWith: { a, _ in a })
        let acting = actingSeats(view)

        header.configure(round: max(view.roundNumber, 1),
                         points: seats[me]?.score ?? 0,
                         trump: view.trump,
                         trumpDetail: view.revealedTrumpCard.map { "\($0.description) shown" })

        configure(leftBadge, with: seats[leftSeat], tint: .amber, active: acting.contains(leftSeat))
        configure(rightBadge, with: seats[rightSeat], tint: .blue, active: acting.contains(rightSeat))

        let myInfo = seats[me]
        let (status, isAction) = statusLine(view)
        selfBadge.configure(name: driver.isSharedDevice ? (myInfo?.name ?? "You") : "You",
                            tally: tally(myInfo),
                            quotaMet: quotaMet(myInfo),
                            status: status,
                            statusIsAction: isAction,
                            isActive: acting.contains(me),
                            chip: targetChip(myInfo))

        renderTable(view, previous: previous)
        renderHand(view, animated: previous != nil)
        renderPrompt(view)
        renderArrange(view)
        renderCountdownAndBanner(view)
        renderCurtain(view)
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

    private func tally(_ seat: TDPSeatView?) -> String {
        guard let seat else { return "—" }
        return targetKnown(seat) ? "\(seat.tricksWon) / \(max(0, seat.quota))" : "\(seat.tricksWon)"
    }

    private func quotaMet(_ seat: TDPSeatView?) -> Bool {
        guard let seat, targetKnown(seat) else { return false }
        return seat.tricksWon >= seat.quota
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
            let suit = TDPTheme.suitName(lead)
            let canFollow = view.myHand.contains { $0.suit == lead }
            return (canFollow ? "Your turn · follow \(suit)" : "Your turn · no \(suit) — trump or throw", true)
        case .chooseTrump:
            return ("Call trump from your first five", true)
        case .settleUp:
            let owed = (view.settlement?.mine ?? []).map { name($0.creditorSeat, in: view) }
            return ("Settle up with \(owed.joined(separator: " and "))", true)
        case .arrangeCards:
            return ("Arrange your cards", true)
        case .khichaiDraw:
            guard let pull = view.khichai, pull.pullTotal > 1 else { return ("Pull a card", true) }
            return ("Pull a card — \(pull.pullNumber) of \(pull.pullTotal)", true)
        case .khichaiReturn:
            return (selectedCardID == nil ? "Give a card back — any card" : "Tap again to give it back", true)
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
            return ("\(waiting.joined(separator: " and ")) \(waiting.count == 1 ? "is" : "are") deciding how to settle up", false)
        case .khichai:
            guard let pull = view.khichai else { return ("Settling up", false) }
            if pull.isArranging {
                if pull.iAmCreditor { return ("Then you pull \(pull.pullTotal), blind", false) }
                return ("\(name(pull.debtorSeat, in: view)) is arranging for \(name(pull.creditorSeat, in: view))", false)
            }
            if pull.iAmDebtor { return ("\(name(pull.creditorSeat, in: view)) is pulling a card from you", false) }
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

    private func renderTable(_ view: TDPClientView, previous: TDPClientView?) {
        let me = view.mySeat

        // A trick was just collected — sweep it toward the winner.
        if previous?.phase == .trickResolve, view.currentTrick.isEmpty, view.phase != .trickResolve {
            trickTable.collect(toward: previous?.lastTrickWinnerSeat.map { spot($0, me: me) })
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
            guard let pull = view.khichai else { return "Khichai" }
            if pull.isArranging {
                return "\(name(pull.debtorSeat, in: view)) \(pull.iAmDebtor ? "are" : "is") arranging their cards"
            }
            return pull.pullTotal > 1 ? "Khichai · \(pull.pullNumber) of \(pull.pullTotal)" : "Khichai"
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
            driver.send(TDPIntent(kind: .playCard, cardID: id))
        } else {
            selectedCardID = id
            UISelectionFeedbackGenerator().selectionChanged()
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
        prompt.reset(title: "Call trump",
                     subtitle: "You need 5 tricks. Pick from your first five — or leave it to the cards.")
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
        let owed = view.debts.filter { $0.to == view.mySeat && $0.from == view.khichai?.debtorSeat }
            .reduce(0) { $0 + $1.amount }
        let reason = owed > 0
            ? "\(debtor) came up \(owed) short of quota last round. "
            : ""
        let pull = view.khichai
        let count = (pull?.pullTotal ?? 1) > 1 ? " · \(pull!.pullNumber) of \(pull!.pullTotal)" : ""
        prompt.reset(title: "Pull a card from \(debtor)\(count)",
                     subtitle: reason + "Tap any face-down card — you'll see it, they won't know which.")
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
            showWhy = false
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
            prompt.reset(title: "You owe \(total) tricks",
                         subtitle: mine.map { "\(name($0.creditorSeat, in: view)) is owed \($0.amount)" }
                            .joined(separator: ", ") + ". Settle each one.")
            for debt in mine { prompt.bodyStack.addArrangedSubview(settleRow(view, debt: debt)) }
            prompt.bodyStack.addArrangedSubview(settleSummary(view, mine: mine, myBase: myBase, seats: seats))
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
        let theirBase = seats[debt.creditorSeat]?.baseQuota ?? 0
        let isPerson = seats[debt.creditorSeat]?.kind != "ai"
        prompt.reset(title: "You owe \(creditor) \(tricks)",
                     subtitle: "\(creditor) won \(n) more than their target last round.")

        let giveUp = TDPOptionCard(
            title: "Give up \(tricks)",
            chip: debt.giveTricksLocked ? nil : "\(myBase) \u{2192} \(myBase + n)",
            body: debt.giveTricksLocked
                ? "Not this round."
                : "No cards move. This round you need \(myBase + n) (instead of \(myBase)) and \(creditor) needs \(max(0, theirBase - n)) (instead of \(theirBase)).")
        giveUp.tag = debt.creditorSeat * 10
        giveUp.isEnabled = !debt.giveTricksLocked
        giveUp.isSelected = settleSelection[debt.creditorSeat] == .giveTricks
        giveUp.addTarget(self, action: #selector(didTapSettleOption(_:)), for: .touchUpInside)

        let giveCards = TDPOptionCard(
            title: "Give \(cards)",
            chip: "blind",
            body: "\(creditor) pulls \(cards) from your hand, blind."
                + (isPerson ? " You get 10 seconds to arrange them first." : " A bot picks at random."))
        giveCards.tag = debt.creditorSeat * 10 + 1
        giveCards.isSelected = settleSelection[debt.creditorSeat] == .giveCards
        giveCards.addTarget(self, action: #selector(didTapSettleOption(_:)), for: .touchUpInside)

        prompt.bodyStack.addArrangedSubview(giveUp)
        prompt.bodyStack.addArrangedSubview(giveCards)
        if debt.giveTricksLocked { prompt.bodyStack.addArrangedSubview(lockedNote(creditor)) }

        let method = settleSelection[debt.creditorSeat] ?? .giveCards
        let confirm = TDPButton(title: method == .giveTricks ? "Give up \(tricks)" : "Give \(cards)", style: .primary)
        confirm.addTarget(self, action: #selector(didTapConfirmSettle), for: .touchUpInside)
        prompt.primaryRow.addArrangedSubview(confirm)
    }

    /// Explains the "not twice in a row" rule — the part players won't expect.
    private func lockedNote(_ creditor: String) -> UIView {
        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
        lock.tintColor = TDPTheme.inkSoft
        lock.setContentHuggingPriority(.required, for: .horizontal)
        let text = UILabel()
        text.text = "You gave \(creditor) tricks last round — two in a row isn't allowed, so this time they pull cards."
        text.font = TDPTheme.font(13)
        text.textColor = TDPTheme.inkSoft
        text.numberOfLines = 0
        let line = UIStackView(arrangedSubviews: [lock, text])
        line.spacing = 10
        line.alignment = .top

        let why = UIButton(type: .system)
        why.setTitle(showWhy ? "Hide" : "Why?", for: .normal)
        why.titleLabel?.font = TDPTheme.font(13, .semibold)
        why.tintColor = TDPTheme.accent
        why.contentHorizontalAlignment = .leading
        why.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        why.addTarget(self, action: #selector(didTapWhy), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [line])
        stack.axis = .vertical
        stack.spacing = 4
        if showWhy {
            let detail = UILabel()
            detail.text = "Giving up tricks moves a debt into this round. If it could be done every round the debt would never be paid — so the next time you owe the same player, it's settled in cards. Owing someone else is a fresh start."
            detail.font = TDPTheme.font(12)
            detail.textColor = TDPTheme.muted
            detail.numberOfLines = 0
            stack.addArrangedSubview(detail)
        }
        stack.addArrangedSubview(why)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 2, trailing: 14)
        stack.backgroundColor = TDPTheme.raisedAlt
        stack.layer.cornerRadius = 14
        stack.layer.cornerCurve = .continuous
        return stack
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

    private func settleSummary(_ view: TDPClientView, mine: [TDPSettleDebt],
                               myBase: Int, seats: [TDPSeat: TDPSeatView]) -> UIView {
        var targets: [TDPSeat: Int] = [view.mySeat: myBase]
        var pulls: [String] = []
        for debt in mine {
            let theirBase = seats[debt.creditorSeat]?.baseQuota ?? 0
            if settleSelection[debt.creditorSeat] == .giveTricks {
                targets[view.mySeat, default: myBase] += debt.amount
                targets[debt.creditorSeat] = theirBase - debt.amount
            } else {
                targets[debt.creditorSeat] = theirBase
                pulls.append("\(name(debt.creditorSeat, in: view)) pulls \(debt.amount)")
            }
        }
        let order = [view.mySeat] + mine.map(\.creditorSeat)
        let line = order.map { seat -> String in
            let who = seat == view.mySeat ? "you" : name(seat, in: view)
            return "\(who) \(max(0, targets[seat] ?? 0))"
        }.joined(separator: " · ")
        let summary = UILabel()
        summary.text = "This round: " + line
        summary.font = TDPTheme.mono(13)
        summary.textColor = TDPTheme.ink
        summary.numberOfLines = 0
        let pullLine = UILabel()
        pullLine.text = pulls.isEmpty ? "No cards move." : pulls.joined(separator: " and ") + ", blind."
        pullLine.font = TDPTheme.font(12)
        pullLine.textColor = TDPTheme.muted
        let stack = UIStackView(arrangedSubviews: [summary, pullLine])
        stack.axis = .vertical
        stack.spacing = 4
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        stack.backgroundColor = TDPTheme.raisedAlt
        stack.layer.cornerRadius = 14
        stack.layer.cornerCurve = .continuous
        return stack
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

    @objc private func didTapWhy() {
        showWhy.toggle()
        if let view = lastView { render(view) }
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
                         subtitle: needs.joined(separator: ", ") + " — this round only.")
        banner.isHidden = false
    }

    private func buildReturnPrompt(_ view: TDPClientView) {
        let drawn = view.khichai?.drawnCard?.description ?? "a card"
        let debtor = name(view.khichai?.debtorSeat, in: view)
        if let selected = selectedCardID, let card = Card(tdpID: selected) {
            prompt.reset(title: "You drew \(drawn)", subtitle: "Give \(card.description) to \(debtor)?")
            let confirm = TDPButton(title: "Confirm · return \(card.description)", style: .primary)
            confirm.addTarget(self, action: #selector(didTapConfirmReturn), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(confirm)
        } else {
            // Any card may go back — the outlined one you just drew included.
            prompt.reset(title: "You drew \(drawn)",
                         subtitle: "Choose a card to give \(debtor) — keep it, or hand the same one back.")
        }
    }

    private func buildRoundPrompt(_ view: TDPClientView) {
        let me = view.mySeat
        let tints: [TDPSeat: TDPTheme.Tint] = [
            me: .green, TDPRoles.nextSeat(me): .amber, TDPRoles.prevSeat(me): .blue
        ]
        let final = view.phase == .sessionEnd
        let ordered = final
            ? view.seats.sorted { $0.score > $1.score }
            : [me, TDPRoles.nextSeat(me), TDPRoles.prevSeat(me)].compactMap { s in view.seats.first { $0.seat == s } }

        if final {
            let top = ordered.first?.score ?? 0
            let leaders = ordered.filter { $0.score == top }.map { name($0.seat, in: view) }
            let verdict = leaders.count > 1
                ? "\(leaders.joined(separator: " and ")) tie"
                : (leaders.first == "You" ? "You win" : "\(leaders.first ?? "—") wins")
            prompt.reset(title: "Final scores", subtitle: "\(verdict) after \(view.roundHistory.count) rounds.")
        } else {
            prompt.reset(title: "Round \(view.roundHistory.count)",
                         subtitle: "Over quota pulls from under quota next deal.")
        }

        let last = view.roundHistory.last
        for seat in ordered {
            let key = String(seat.seat)
            prompt.bodyStack.addArrangedSubview(TDPPromptCard.scoreRow(
                name: name(seat.seat, in: view),
                tint: tints[seat.seat] ?? .green,
                tricks: last?.tricks[key] ?? 0,
                quota: last?.quotas[key] ?? 0,
                delta: last?.delta[key] ?? 0,
                total: seat.score
            ))
        }

        if final {
            let done = TDPButton(title: "Done", style: .primary)
            done.addTarget(self, action: #selector(didTapLeaveConfirmed), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(done)
            if view.isHost {
                let more = TDPButton(title: "Play 3 more", style: .secondary)
                more.addTarget(self, action: #selector(didTapExtend), for: .touchUpInside)
                prompt.secondaryRow.addArrangedSubview(more)
            }
        } else if view.isHost {
            let next = TDPButton(title: "Next round", style: .primary)
            next.addTarget(self, action: #selector(didTapNextRound), for: .touchUpInside)
            prompt.primaryRow.addArrangedSubview(next)
            if view.canEndSession {
                let end = TDPButton(title: "End session", style: .secondary)
                end.addTarget(self, action: #selector(didTapEndSession), for: .touchUpInside)
                prompt.secondaryRow.addArrangedSubview(end)
            }
        } else {
            let waiting = UILabel()
            waiting.text = "Waiting for the host to deal…"
            waiting.font = TDPTheme.font(13)
            waiting.textColor = TDPTheme.muted
            waiting.textAlignment = .center
            prompt.bodyStack.addArrangedSubview(waiting)
        }
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
    @objc private func didTapEndSession() { driver.send(TDPIntent(kind: .endSession)) }
    @objc private func didTapExtend() { driver.send(TDPIntent(kind: .extendSession)) }

    @objc private func didTapConfirmReturn() { commitReturn() }

    private func commitReturn() {
        guard let cardID = selectedCardID else { return }
        selectedCardID = nil
        driver.send(TDPIntent(kind: .khichaiReturn, cardID: cardID))
    }

    // MARK: Menu

    @objc private func didTapMenu() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Scores", style: .default) { [weak self] _ in self?.showScores() })
        sheet.addAction(UIAlertAction(title: "How to play", style: .default) { [weak self] _ in self?.showRules() })
        sheet.addAction(UIAlertAction(title: "Leave table", style: .destructive) { [weak self] _ in self?.confirmLeave() })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = header.menuButton
        sheet.popoverPresentationController?.sourceRect = header.menuButton.bounds
        present(sheet, animated: true)
    }

    private func showScores() {
        guard let view = lastView else { return }
        let order = [view.mySeat, TDPRoles.nextSeat(view.mySeat), TDPRoles.prevSeat(view.mySeat)]
        var lines: [String] = []
        for round in view.roundHistory {
            let parts = order.map { seat in
                "\(name(seat, in: view)) \(TDPFormat.signed(round.delta[String(seat)] ?? 0))"
            }
            lines.append("Round \(round.round):  " + parts.joined(separator: "   "))
        }
        let totals = order.map { seat in
            "\(name(seat, in: view)) \(TDPFormat.signed(view.seats.first { $0.seat == seat }?.score ?? 0))"
        }
        lines.append("")
        lines.append("Total:  " + totals.joined(separator: "   "))
        let alert = UIAlertController(title: "Scores",
                                      message: view.roundHistory.isEmpty ? "No rounds finished yet." : lines.joined(separator: "\n"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func showRules() {
        let rules = TDPRulesViewController()
        rules.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak rules] _ in
            rules?.dismiss(animated: true)
        })
        present(UINavigationController(rootViewController: rules), animated: true)
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
