//
//  JackarooGameViewController.swift
//  Tokiyo Casino — Jackaroo
//
//  Phase 2 game screen. Solo mode only — 1 human at seat 0, 3 AIs.
//  Hot-seat, lobby, settings, and rules are deferred to Phase 3+.
//
//  Flow:
//  1. Tap a card in the hand strip → enumerate that card's legal
//     moves → highlight destinations on the board (cells / marbles).
//  2. Tap a destination → look up the matching move → engine plays.
//  3. After each move resolves we either ask the AI for its next move
//     or wait for the next human card tap.
//

import UIKit

final class JackarooGameViewController: UIViewController, JackarooEngineDelegate {

    // MARK: - Engine

    private let engine: JackarooEngine
    private let humanSeat: SeatID = 0

    // MARK: - UI

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let gearButton = MPGearPill()
    private let infoPill = MPInfoPill()
    private let turnPill = JKTurnPillView()

    private let boardView: JKBoardView
    private let handStrip = JKHandStripView()

    private let playerCorners: [JKPlayerCornerView] = (0..<4).map { JKPlayerCornerView(seat: $0) }

    // MARK: - Selection state

    /// Index into the active human player's hand of the lifted card.
    private var pickedCardIndex: Int?

    /// All moves that match the picked card. Reset every time the user
    /// changes their selection.
    private var candidateMoves: [JKMove] = []

    /// Convenience — the active player's hand if it's the human's turn.
    private var humanHand: [JKCard] {
        engine.state.players[humanSeat].hand
    }

    // MARK: - Init

    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        let players: [JKPlayer] = (0..<4).map { seat in
            if seat == 0 {
                return JKPlayer(seat: seat, name: "You", kind: .human)
            } else {
                let p: JKPersonality = [.tightAggressive, .balanced, .loosePassive][seat - 1]
                return JKPlayer(seat: seat, name: p.displayName, kind: .ai(personality: p))
            }
        }
        self.engine = JackarooEngine(players: players, seed: seed)
        self.boardView = JKBoardView(graph: engine.graph)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    private var didStartEngine = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Defer engine startup until the board has real bounds —
        // snapMarbles() depends on JKBoardLayout being able to
        // compute cell centres, which needs non-zero width.
        guard !didStartEngine, boardView.bounds.width > 0 else {
            // Even before startup, keep marbles snapped to whatever
            // state we already have (handles rotation).
            boardView.snapMarbles(from: engine.state)
            return
        }
        didStartEngine = true
        engine.delegate = self
        engine.start()
        boardView.snapMarbles(from: engine.state)
        refreshAllUI()
        scheduleAIStepIfNeeded()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    // MARK: - UI setup

    private func setupUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        for v in [backButton, gearButton, infoPill, turnPill, boardView, handStrip] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        for corner in playerCorners {
            corner.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(corner)
        }

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        gearButton.addTarget(self, action: #selector(gearTapped), for: .touchUpInside)

        boardView.onTrackCellTapped = { [weak self] cellID in
            self?.handleBoardTrackTap(cellID: cellID)
        }
        boardView.onSafeCellTapped = { [weak self] seat, lane in
            self?.handleBoardSafeTap(seat: seat, lane: lane)
        }
        handStrip.delegate = self

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            gearButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            gearButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            infoPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoPill.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            turnPill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            turnPill.topAnchor.constraint(equalTo: infoPill.bottomAnchor, constant: 10),
            turnPill.widthAnchor.constraint(lessThanOrEqualToConstant: 280),

            boardView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            boardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -10),
            boardView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.92),
            boardView.heightAnchor.constraint(equalTo: boardView.widthAnchor),

            handStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            handStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            handStrip.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            handStrip.heightAnchor.constraint(equalToConstant: 96),
        ])

        // Player-corner placement — each anchored to one screen corner.
        let cornerInsets: CGFloat = 12
        let layouts: [(SeatID, NSLayoutConstraint, NSLayoutConstraint)] = [
            (0, playerCorners[0].leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: cornerInsets),
                playerCorners[0].topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 18)),
            (1, playerCorners[1].trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -cornerInsets),
                playerCorners[1].topAnchor.constraint(equalTo: gearButton.bottomAnchor, constant: 18)),
            (2, playerCorners[2].trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -cornerInsets),
                playerCorners[2].bottomAnchor.constraint(equalTo: handStrip.topAnchor, constant: -18)),
            (3, playerCorners[3].leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: cornerInsets),
                playerCorners[3].bottomAnchor.constraint(equalTo: handStrip.topAnchor, constant: -18)),
        ]
        for (_, c1, c2) in layouts { NSLayoutConstraint.activate([c1, c2]) }
    }

    // MARK: - Engine delegate

    func didDeal() {
        refreshAllUI()
    }

    func didChangeTurn(_ seat: SeatID) {
        clearSelection()
        refreshAllUI()
        scheduleAIStepIfNeeded()
    }

    func willResolve(_ move: JKMove, by seat: SeatID, path: [CellID]) {
        handStrip.isInteractive = false
    }

    func didResolve(_ move: JKMove, by seat: SeatID) {
        // Update fire pile display.
        boardView.setFirePileTop(engine.state.firePile.last)
        // Snap marbles into place — Phase 2 uses snap rather than full
        // per-step animation, because move resolution happens before
        // the delegate fires and the engine doesn't expose the path
        // here. Real step-by-step animation comes from `animateMove`
        // hooks in `willResolve`, which we'll wire fully in Phase 6.
        boardView.snapMarbles(from: engine.state)
        refreshPlayerCorners()
        handStrip.isInteractive = true

        if engine.state.winner != nil {
            handStrip.isInteractive = false
            return
        }
    }

    func didCapture(_ marble: MarbleID, by seat: SeatID) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func didEngageHandoff(_ seat: SeatID) {
        // No-op for V1 — the partner-handoff state is reflected on the
        // player corner UI.
    }

    func didEnd(winner: JKTeam) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let alert = UIAlertController(
            title: "Team \(winner == .a ? "A" : "B") wins!",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Play again", style: .default) { [weak self] _ in
            self?.restartGame()
        })
        alert.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
            self?.backTapped()
        })
        present(alert, animated: true)
    }

    // MARK: - AI driving

    private func scheduleAIStepIfNeeded() {
        guard engine.state.winner == nil else { return }
        guard case .ai = engine.state.players[engine.state.currentSeat].kind else { return }
        let delay = Double.random(in: 0.6...1.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            // Re-check in case the user navigated away.
            guard self.view.window != nil else { return }
            self.engine.stepAIIfNeeded()
        }
    }

    // MARK: - UI refresh

    private func refreshAllUI() {
        let s = engine.state
        infoPill.set(blinds: "Hand \(s.handsDealt)",
                     hand: "Jackaroo Basic",
                     phase: s.winner == nil
                         ? (s.currentSeat == humanSeat ? "Your turn" : "\(s.players[s.currentSeat].name)'s turn")
                         : "Game over")
        turnPill.set(name: s.players[s.currentSeat].name,
                     status: s.currentSeat == humanSeat ? "→ play a card"
                                                       : "thinking…")
        boardView.setFirePileTop(s.firePile.last)
        boardView.snapMarbles(from: s)
        refreshHandStrip()
        refreshPlayerCorners()
    }

    private func refreshHandStrip() {
        if engine.state.currentSeat == humanSeat && engine.state.winner == nil {
            handStrip.setHand(humanHand)
            // If every legal move is a burn, surface the burn affordance.
            let moves = engine.legalMovesForCurrentSeat()
            handStrip.showBurnAffordance = !moves.isEmpty && moves.allSatisfy { $0.isBurn }
            handStrip.isInteractive = true
        } else {
            handStrip.setHand([])
            handStrip.showBurnAffordance = false
            handStrip.isInteractive = false
        }
    }

    private func refreshPlayerCorners() {
        for (idx, corner) in playerCorners.enumerated() {
            let p = engine.state.players[idx]
            corner.configure(
                name: p.name,
                team: p.team,
                isActive: idx == engine.state.currentSeat && engine.state.winner == nil,
                handoffEngaged: engine.state.handoffEngaged[idx]
            )
        }
    }

    // MARK: - Selection + tap handling

    private func clearSelection() {
        pickedCardIndex = nil
        candidateMoves = []
        boardView.clearHighlights()
        boardView.setSelectedMarble(nil)
        handStrip.clearSelection()
    }

    private func handleBoardTrackTap(cellID: CellID) {
        guard engine.state.currentSeat == humanSeat else { return }
        guard let move = candidateMoves.first(where: { matchesTrackTarget($0, cellID: cellID) }) else {
            return
        }
        clearSelection()
        engine.play(move)
    }

    private func handleBoardSafeTap(seat: SeatID, lane: Int) {
        guard engine.state.currentSeat == humanSeat else { return }
        guard let move = candidateMoves.first(where: { matchesSafeTarget($0, seat: seat, lane: lane) }) else {
            return
        }
        clearSelection()
        engine.play(move)
    }

    /// True if applying `move` lands the moving marble on `cellID`.
    private func matchesTrackTarget(_ move: JKMove, cellID: CellID) -> Bool {
        guard let dest = destination(of: move) else { return false }
        if case .track(let c) = dest, c == cellID { return true }
        return false
    }

    private func matchesSafeTarget(_ move: JKMove, seat: SeatID, lane: Int) -> Bool {
        guard let dest = destination(of: move) else { return false }
        if case .safe(let li) = dest, li == lane,
           movingMarbleOwner(of: move) == seat { return true }
        return false
    }

    /// Where the (primary) marble would land after this move resolves.
    /// Used purely for tap matching; we ignore the secondary-marble
    /// movement in a 7-split for Phase 2 simplification.
    private func destination(of move: JKMove) -> JKPosition? {
        let state = engine.state
        let mover = movingMarble(of: move, state: state)
        switch move {
        case .fieldFromHome:
            guard let m = mover, let baseID = engine.graph.baseCell[m.owner] else { return nil }
            return .track(baseID)
        case let .forward(_, _, steps):
            guard let m = mover else { return nil }
            let gen = JKLegalMoveGenerator(graph: engine.graph)
            return gen.walkForward(marble: m, steps: steps,
                                   seat: state.currentSeat,
                                   state: state)?.destination
        case let .backward(_, _, steps):
            guard let m = mover else { return nil }
            let gen = JKLegalMoveGenerator(graph: engine.graph)
            return gen.walkBackward(marble: m, steps: steps,
                                    seat: state.currentSeat, state: state)?.destination
        case let .anyMarble5(_, _, steps):
            guard let m = mover else { return nil }
            let gen = JKLegalMoveGenerator(graph: engine.graph)
            return gen.walkForward(marble: m, steps: steps,
                                   seat: state.currentSeat,
                                   state: state,
                                   preferSafeEntry: false)?.destination
        case .split7, .swap, .redQueenDiscard, .burnHand, .burnCard:
            return nil
        }
    }

    private func movingMarble(of move: JKMove, state: JKGameState) -> JKMarble? {
        let id: MarbleID
        switch move {
        case let .fieldFromHome(_, m): id = m
        case let .forward(_, m, _):    id = m
        case let .backward(_, m, _):   id = m
        case let .anyMarble5(_, m, _): id = m
        case let .swap(_, own, _):     id = own
        default: return nil
        }
        return state.marbles.first { $0.id == id }
    }

    private func movingMarbleOwner(of move: JKMove) -> SeatID? {
        movingMarble(of: move, state: engine.state)?.owner
    }

    // MARK: - Disambiguation helpers

    /// Compute the set of destination cell IDs + safe-lane indices
    /// reachable by any of the candidate moves. Used to light up
    /// legal targets after a card is picked.
    private func computeHighlights() -> (tracks: Set<CellID>, safe: [SeatID: Set<Int>]) {
        var tracks = Set<CellID>()
        var safe: [SeatID: Set<Int>] = [:]
        for move in candidateMoves {
            guard let dest = destination(of: move) else { continue }
            switch dest {
            case .track(let c):
                tracks.insert(c)
            case .safe(let li):
                if let owner = movingMarbleOwner(of: move) {
                    safe[owner, default: []].insert(li)
                }
            case .home:
                break
            }
        }
        return (tracks, safe)
    }

    private func handleSpecialCaseMove(_ moves: [JKMove]) {
        // Phase 2: when the picked card produces moves with no track
        // destination (swap, split7, burnHand, redQueenDiscard,
        // burnCard), surface a quick action sheet rather than building
        // a bespoke disambiguation flow per card type. Phase 6 polishes
        // each with a proper interaction.
        let action = UIAlertController(title: "Pick an action",
                                       message: nil,
                                       preferredStyle: .actionSheet)
        for (i, m) in moves.enumerated() {
            let label = describe(m)
            action.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.clearSelection()
                self?.engine.play(moves[i])
            })
        }
        action.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = action.popoverPresentationController {
            popover.sourceView = handStrip
            popover.sourceRect = handStrip.bounds
        }
        present(action, animated: true)
    }

    private func describe(_ m: JKMove) -> String {
        switch m {
        case .swap(_, let own, let other):
            return "Swap marble \(own) with marble \(other)"
        case .split7(_, let allocs):
            let parts = allocs.map { "m\($0.marble) +\($0.steps)" }
            return "Split 7: \(parts.joined(separator: ", "))"
        case .redQueenDiscard(_, let v):
            return "Make \(engine.state.players[v].name) discard"
        case .burnHand(let cards):
            return "Burn whole hand (\(cards.count))"
        case .burnCard(let c):
            return "Burn \(c.debugDescription)"
        case .fieldFromHome:
            return "Field a marble"
        case .forward(_, let m, let s):
            return "Forward \(s) on marble \(m)"
        case .backward(_, let m, let s):
            return "Backward \(s) on marble \(m)"
        case .anyMarble5(_, let m, let s):
            return "Any +\(s) on marble \(m)"
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func gearTapped() {
        let alert = UIAlertController(title: "Settings", message: "Coming in Phase 5", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func restartGame() {
        // Phase 2: easiest restart = pop + push a fresh instance.
        let fresh = JackarooGameViewController()
        fresh.modalPresentationStyle = .fullScreen
        if let nav = navigationController {
            var stack = nav.viewControllers
            if let idx = stack.firstIndex(of: self) {
                stack[idx] = fresh
                nav.setViewControllers(stack, animated: false)
            } else {
                nav.pushViewController(fresh, animated: false)
            }
        } else {
            dismiss(animated: true) {
                // Caller will need to re-present.
            }
        }
    }
}

// MARK: - Hand strip delegate

extension JackarooGameViewController: JKHandStripDelegate {
    func handStrip(_ strip: JKHandStripView, didSelect card: JKCard, at index: Int) {
        guard engine.state.currentSeat == humanSeat else { return }
        pickedCardIndex = index
        let allMoves = engine.legalMovesForCurrentSeat()
        candidateMoves = allMoves.filter { moveUsesCard($0, card) }

        if candidateMoves.isEmpty {
            // Visual shake — nothing to do with this card.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            strip.clearSelection()
            return
        }

        // Highlight cell-based targets.
        let highlights = computeHighlights()
        boardView.highlightLegalTargets(trackCells: highlights.tracks,
                                        safeCells: highlights.safe)

        // For moves without a track destination, show an action sheet.
        let nonCellMoves = candidateMoves.filter { destination(of: $0) == nil }
        if highlights.tracks.isEmpty && highlights.safe.isEmpty && !nonCellMoves.isEmpty {
            handleSpecialCaseMove(nonCellMoves)
        }
    }

    func handStripDidTapBurn(_ strip: JKHandStripView) {
        let burns = engine.legalMovesForCurrentSeat().filter { $0.isBurn }
        if let first = burns.first {
            clearSelection()
            engine.play(first)
        }
    }

    private func moveUsesCard(_ move: JKMove, _ card: JKCard) -> Bool {
        switch move {
        case let .fieldFromHome(c, _),
             let .forward(c, _, _),
             let .backward(c, _, _),
             let .anyMarble5(c, _, _),
             let .split7(c, _),
             let .swap(c, _, _),
             let .redQueenDiscard(c, _),
             let .burnCard(c):
            return c == card
        case .burnHand(let cards):
            return cards.contains(card)
        }
    }
}

// MARK: - Player corner chip

private final class JKPlayerCornerView: UIView {
    let seat: SeatID
    private let avatar: AvatarView
    private let pill = UIView()
    private let nameLabel = UILabel()
    private let teamLabel = UILabel()
    private let teamDot = UIView()

    init(seat: SeatID) {
        self.seat = seat
        let hueByteSeat = [12.0, 150.0, 38.0, 200.0]
        self.avatar = AvatarView(name: "P\(seat)", hue: hueByteSeat[seat], size: 44)
        super.init(frame: .zero)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avatar)

        pill.backgroundColor = MPTheme.glass
        pill.layer.cornerRadius = 12
        pill.layer.borderWidth = 1
        pill.layer.borderColor = MPTheme.border.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)

        nameLabel.font = MPFont.display(13, weight: .medium)
        nameLabel.textColor = MPTheme.ink
        teamLabel.font = MPFont.ui(9, weight: .heavy)
        teamLabel.textColor = MPTheme.muted
        teamDot.layer.cornerRadius = 3
        teamDot.layer.masksToBounds = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        teamLabel.translatesAutoresizingMaskIntoConstraints = false
        teamDot.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(nameLabel)
        pill.addSubview(teamDot)
        pill.addSubview(teamLabel)

        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: topAnchor),
            avatar.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),

            pill.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 6),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.leadingAnchor.constraint(equalTo: leadingAnchor),
            pill.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.bottomAnchor.constraint(equalTo: bottomAnchor),
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 34),

            nameLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 4),
            nameLabel.centerXAnchor.constraint(equalTo: pill.centerXAnchor),

            teamDot.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 8),
            teamDot.centerYAnchor.constraint(equalTo: teamLabel.centerYAnchor),
            teamDot.widthAnchor.constraint(equalToConstant: 6),
            teamDot.heightAnchor.constraint(equalToConstant: 6),

            teamLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            teamLabel.leadingAnchor.constraint(equalTo: teamDot.trailingAnchor, constant: 4),
            teamLabel.trailingAnchor.constraint(lessThanOrEqualTo: pill.trailingAnchor, constant: -8),
            teamLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -4),

            widthAnchor.constraint(equalToConstant: 92),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, team: JKTeam, isActive: Bool, handoffEngaged: Bool) {
        nameLabel.text = name
        teamLabel.text = team == .a ? "TEAM A" : "TEAM B"
        teamDot.backgroundColor = team == .a
            ? UIColor.dyn(light: 0xD5604E, dark: 0xE8786A)   // coral
            : UIColor.dyn(light: 0x5E9466, dark: 0x7BB07A)   // forest
        layer.shadowColor = UIColor(red: 0.85, green: 0.66, blue: 0.30, alpha: 1).cgColor
        layer.shadowOpacity = isActive ? 0.55 : 0
        layer.shadowRadius = 8
        layer.shadowOffset = .zero
        avatar.alpha = isActive ? 1.0 : 0.88
        pill.alpha = isActive ? 1.0 : 0.92
        nameLabel.text = handoffEngaged ? "\(name) ♛" : name
    }
}

// MARK: - MPInfoPill (minimal reproduction of TopInfoBar's centre pill)

private final class MPInfoPill: UIView {
    private let label = UILabel()
    init() {
        super.init(frame: .zero)
        backgroundColor = MPTheme.glass
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = MPTheme.border.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 30),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    func set(blinds: String, hand: String?, phase: String?) {
        let muted: [NSAttributedString.Key: Any] = [
            .foregroundColor: MPTheme.muted,
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
        ]
        let inked: [NSAttributedString.Key: Any] = [
            .foregroundColor: MPTheme.ink,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
        ]
        let separator = NSAttributedString(string: "  |  ", attributes: muted)
        let out = NSMutableAttributedString(string: blinds, attributes: inked)
        if let hand {
            out.append(separator)
            out.append(NSAttributedString(string: hand, attributes: inked))
        }
        if let phase {
            out.append(separator)
            out.append(NSAttributedString(string: phase, attributes: inked))
        }
        label.attributedText = out
    }
}
