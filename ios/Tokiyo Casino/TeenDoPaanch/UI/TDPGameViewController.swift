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

        [header, leftBadge, rightBadge, trickTable, selfBadge, fan, prompt, toast, curtain]
            .forEach { view.addSubview($0) }
        view.addLayoutGuide(tableArea)
        prompt.isHidden = true

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
                            isActive: acting.contains(me))

        renderTable(view, previous: previous)
        renderHand(view, animated: previous != nil)
        renderPrompt(view)
        renderCurtain(view)
    }

    private func configure(_ badge: TDPOpponentBadge, with seat: TDPSeatView?, tint: TDPTheme.Tint, active: Bool) {
        guard let seat else { badge.isHidden = true; return }
        badge.isHidden = false
        var detail = "\(seat.handCount) card\(seat.handCount == 1 ? "" : "s")"
        if seat.kind == "ai" { detail += " · bot" }
        if !seat.isConnected { detail += " · offline" }
        badge.configure(name: seat.name, tally: tally(seat), quotaMet: quotaMet(seat),
                        detail: detail, isActive: active, tint: tint, isOffline: !seat.isConnected)
    }

    private func tally(_ seat: TDPSeatView?) -> String {
        guard let seat else { return "—" }
        return seat.quota > 0 ? "\(seat.tricksWon) / \(seat.quota)" : "\(seat.tricksWon)"
    }

    private func quotaMet(_ seat: TDPSeatView?) -> Bool {
        guard let seat, seat.quota > 0 else { return false }
        return seat.tricksWon >= seat.quota
    }

    /// Seats the table is waiting on — they get the glowing ring.
    private func actingSeats(_ view: TDPClientView) -> Set<TDPSeat> {
        switch view.phase {
        case .play:
            return view.currentTurnSeat.map { [$0] } ?? []
        case .trumpSelect:
            let selector = view.seats.first { $0.role == TDPRole.trumpSelector.rawValue }?.seat
            return selector.map { [$0] } ?? []
        case .khichai:
            return view.khichai.map { [$0.creditorSeat] } ?? []
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
            guard let lead = view.leadSuit else {
                let heldBack = view.trickNumber == 0 && view.myLegalCardIDs.count < view.myHand.count
                return (heldBack ? "Your lead · no trump on the first trick" : "Your lead", true)
            }
            let suit = TDPTheme.suitName(lead)
            let canFollow = view.myHand.contains { $0.suit == lead }
            return (canFollow ? "Your turn · follow \(suit)" : "Your turn · no \(suit) — trump or throw", true)
        case .chooseTrump:
            return ("Call trump from your first five", true)
        case .khichaiDraw:
            return ("Pull a card", true)
        case .khichaiReturn:
            return (selectedCardID == nil ? "Give back a different card" : "Tap again to give it back", true)
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
        case .khichai:
            guard let pull = view.khichai else { return ("Settling up", false) }
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
        case .khichai:                            return "Khichai"
        case .roundEnd:                           return "Round \(view.roundHistory.count) complete"
        case .sessionEnd:                         return "Session complete"
        case .lobby:                              return "Waiting for players"
        }
    }

    // MARK: Hand

    private func renderHand(_ view: TDPClientView, animated: Bool) {
        // Pulling: the fan becomes the debtor's face-down hand. Positions
        // only — the host shuffled them, so an index names no card.
        if let pull = view.khichai, pull.iAmCreditor, pull.drawnCard == nil {
            let items = (0..<pull.fanCount).map {
                TDPHandFanView.Item(key: "fan-\($0)", card: nil, tag: $0,
                                    enabled: true, dimmed: false, lift: .hint, highlighted: false)
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
        prompt.reset(title: "Pull a card from \(debtor)",
                     subtitle: reason + "Tap any face-down card — you'll see it, they won't know which.")
        let random = TDPButton(title: "Pick for me", style: .secondary)
        random.addTarget(self, action: #selector(didTapRandomPull), for: .touchUpInside)
        prompt.primaryRow.addArrangedSubview(random)
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
            // Classic rules: the pulled card stays, and you may not strip a
            // suit below two cards — which is why some cards are greyed out.
            prompt.reset(title: "You drew \(drawn)",
                         subtitle: "Choose a different card to give \(debtor). You must keep at least two of its suit.")
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
