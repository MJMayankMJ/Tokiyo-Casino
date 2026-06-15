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

    let engine: JackarooEngine

    /// Seats controlled by a human. One = solo (Phase 2 behaviour);
    /// two or more = hot-seat, which adds the pass-the-device curtain.
    private let humanSeats: Set<SeatID>
    private var isHotSeat: Bool { humanSeats.count >= 2 }

    /// Whether the seated human has lifted the privacy curtain. Always
    /// true for solo and AI seats (they never get a curtain).
    private var handRevealed = true
    private let curtain = JKHandoffOverlay()
    private var autoHideTimer: Timer?
    /// Auto-hide the revealed hand after this many seconds of inactivity.
    private let autoHideSeconds: TimeInterval = 8

    // MARK: - Marble animation

    /// A marble is mid-flight: the board owns positions until it lands.
    private var isAnimating = false
    /// Bumped on every animation start and on cancel, so a stale
    /// completion (e.g. after backgrounding) is ignored.
    private var animationToken = 0
    /// The single-marble move to animate this turn, captured in willResolve
    /// (before the resolver mutates state) and consumed in didResolve.
    private var pendingPrimary: MarbleID?
    private var pendingPath: [CellID] = []

    /// Test seam. When true the VC does not auto-schedule AI turns on a
    /// timer and does not present the end-of-game alert, so a unit test
    /// can drive a full game synchronously and inspect the result.
    /// Production always leaves this `false`.
    var isAutomatedTestMode = false

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

    /// The seat currently on turn.
    private var currentHand: [JKCard] {
        engine.state.players[engine.state.currentSeat].hand
    }

    /// True when the seat on turn is a human who is allowed to act right
    /// now (curtain lifted).
    private var humanCanAct: Bool {
        humanSeats.contains(engine.state.currentSeat)
            && engine.state.winner == nil
            && handRevealed
    }

    // MARK: - Init

    /// Production entry: solo human at seat 0 against three stub AIs.
    convenience init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        let players: [JKPlayer] = (0..<4).map { seat in
            if seat == 0 {
                return JKPlayer(seat: seat, name: "You", kind: .human)
            } else {
                let p: JKPersonality = [.tightAggressive, .balanced, .loosePassive][seat - 1]
                return JKPlayer(seat: seat, name: p.displayName, kind: .ai(personality: p))
            }
        }
        self.init(players: players, seed: seed)
    }

    /// Designated init. Exposed so tests can stand up an all-AI table
    /// and drive a complete game through the real delegate pipeline.
    /// Pass `restoring:` to rebuild a saved mid-game state (resume).
    init(players: [JKPlayer], seed: UInt64,
         rules: JKRulesPreset = .jawakerBasic,
         restoring: JKGameState? = nil) {
        if let restoring {
            self.engine = JackarooEngine(restoring: restoring)
        } else {
            self.engine = JackarooEngine(players: players, rules: rules, seed: seed)
        }
        self.boardView = JKBoardView(graph: engine.graph)
        self.humanSeats = Set(players.compactMap { p in
            if case .human = p.kind { return p.seat }
            return nil
        })
        self.isResuming = (restoring != nil)
        super.init(nibName: nil, bundle: nil)
    }

    /// Resume a saved game. Players + ruleset come from the saved state.
    convenience init(restoring state: JKGameState) {
        self.init(players: state.players, seed: state.seed,
                  rules: state.rules, restoring: state)
    }
    required init?(coder: NSCoder) { fatalError() }

    private let isResuming: Bool

    // MARK: - Lifecycle

    private var didStartEngine = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        if !isAutomatedTestMode { JKAudio.shared.preload() }
        setupUI()
        // Backgrounding can freeze a CAAnimation mid-flight; reconcile the
        // board to engine truth so a marble never strands off-position.
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func appWillResignActive() {
        guard isAnimating else { return }
        animationToken += 1          // invalidate the in-flight completion
        isAnimating = false
        boardView.cancelMarbleAnimations()
        boardView.snapMarbles(from: engine.state)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Defer engine startup until the board has real bounds so the
        // board layout can compute cell centres from non-zero geometry.
        guard !didStartEngine, boardView.bounds.width > 0 else {
            // Even before startup, keep marbles snapped to whatever
            // state we already have (handles rotation).
            boardView.snapMarbles(from: engine.state)
            return
        }
        didStartEngine = true
        engine.delegate = self
        // start()/resume() fire didDeal + didChangeTurn, which refresh the
        // UI, snap the marbles, and schedule the first AI turn. Doing any
        // of that again here would double-drive the AI loop.
        if isResuming { engine.resume() } else { engine.start() }
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

        // Privacy curtain — full-screen, on top, hidden until a hot-seat
        // handoff raises it.
        curtain.translatesAutoresizingMaskIntoConstraints = false
        curtain.isHidden = true
        curtain.alpha = 0
        curtain.onReveal = { [weak self] in self?.revealHand() }
        view.addSubview(curtain)
        NSLayoutConstraint.activate([
            curtain.topAnchor.constraint(equalTo: view.topAnchor),
            curtain.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            curtain.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            curtain.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Engine delegate

    func didDeal() {
        refreshAllUI()
    }

    func didChangeTurn(_ seat: SeatID) {
        clearSelection()
        invalidateAutoHide()

        let needsCurtain = !isAutomatedTestMode && isHotSeat
            && humanSeats.contains(seat) && engine.state.winner == nil
        if needsCurtain {
            handRevealed = false
            presentCurtain(for: seat)
        } else {
            handRevealed = true
            hideCurtain(animated: false)
        }

        refreshAllUI()
        announceTurn(seat)
        autosaveIfNeeded()
        scheduleAIStepIfNeeded()
    }

    /// Persist the live game after every turn so a crash / force-quit
    /// can offer "Resume" on the menu. Skipped for pure-AI test tables.
    private func autosaveIfNeeded() {
        guard !isAutomatedTestMode, !humanSeats.isEmpty,
              engine.state.winner == nil else { return }
        JKAutosave.save(engine.state)
    }

    func willResolve(_ move: JKMove, by seat: SeatID, path: [CellID]) {
        handStrip.isInteractive = false
        // Capture what to animate *before* the resolver mutates state. The
        // moving marble's view is still at its pre-move position here.
        pendingPrimary = primaryAnimatableMarble(move)
        pendingPath = path
    }

    func didResolve(_ move: JKMove, by seat: SeatID) {
        boardView.setFirePileTop(engine.state.firePile.last)
        refreshPlayerCorners()

        if !isAutomatedTestMode && !move.isBurn {
            // Move resolves (DESIGN §6): coin_flip sound for all seats;
            // a medium haptic only for a human's own move (so a long AI
            // run doesn't buzz continuously).
            JKAudio.shared.play(.move)
            if humanSeats.contains(seat) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        if !isAutomatedTestMode,
           let primary = pendingPrimary, !pendingPath.isEmpty,
           let marble = engine.state.marbles.first(where: { $0.id == primary }) {
            // Snap everyone (captures home, etc.) except the mover, then
            // slide the mover step-by-step along the path to its landing.
            boardView.snapMarbles(from: engine.state, excluding: primary)
            isAnimating = true
            animationToken += 1
            let token = animationToken
            boardView.animateMove(marble: primary, from: marble.position,
                                  to: marble.position, via: pendingPath,
                                  owner: marble.owner,
                                  stepDuration: JKGamePreferences.marbleStepDuration) { [weak self] in
                guard let self, token == self.animationToken else { return }
                self.finishAnimation()
            }
        } else {
            boardView.snapMarbles(from: engine.state)
        }
        pendingPrimary = nil
        pendingPath = []

        if engine.state.winner != nil {
            handStrip.isInteractive = false
        }
    }

    /// The lone marble a move slides (others — swap/split7 — just snap).
    private func primaryAnimatableMarble(_ move: JKMove) -> MarbleID? {
        switch move {
        case let .fieldFromHome(_, m), let .forward(_, m, _),
             let .backward(_, m, _), let .anyMarble5(_, m, _),
             let .kingThirteen(_, m):
            return m
        default:
            return nil
        }
    }

    private func finishAnimation() {
        isAnimating = false
        boardView.snapMarbles(from: engine.state)
    }

    func didCapture(_ marble: MarbleID, by seat: SeatID) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if !isAutomatedTestMode { JKAudio.shared.play(.capture) }
    }

    func didEngageHandoff(_ seat: SeatID) {
        // No-op for V1 — the partner-handoff state is reflected on the
        // player corner UI.
    }

    func didEnd(winner: JKTeam) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        invalidateAutoHide()
        hideCurtain(animated: false)
        JKAutosave.clear()                 // finished game is not resumable
        guard !isAutomatedTestMode else { return }
        JKAudio.shared.play(.win)
        // Brass-spark celebration, then the summary modal (DESIGN §6).
        let confetti = JKConfettiView(frame: view.bounds)
        confetti.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(confetti)
        confetti.burst(duration: 1.5) { [weak self] in
            self?.presentSummary(winner: winner)
        }
    }

    private func presentSummary(winner: JKTeam) {
        guard presentedViewController == nil else { return }
        let summary = JackarooGameSummaryViewController(
            state: engine.state, winner: winner, humanSeats: humanSeats)
        summary.onPlayAgain = { [weak self] in self?.restartGame() }
        summary.onClose = { [weak self] in self?.backTapped() }
        present(summary, animated: true)
    }

    // MARK: - AI driving

    private func scheduleAIStepIfNeeded() {
        guard !isAutomatedTestMode else { return }
        guard engine.state.winner == nil else { return }
        guard case .ai = engine.state.players[engine.state.currentSeat].kind else { return }
        let delay = Double.random(in: 0.6...1.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.fireAIStep()
        }
    }

    /// Run the AI's move, but never while a marble is still sliding — wait
    /// for the in-flight animation so turns don't overlap.
    private func fireAIStep() {
        guard view.window != nil else { return }            // user navigated away
        guard engine.state.winner == nil else { return }
        guard case .ai = engine.state.players[engine.state.currentSeat].kind else { return }
        if isAnimating {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.fireAIStep()
            }
            return
        }
        engine.stepAIIfNeeded()
    }

    /// Test seam: play the first legal move for whoever is on turn,
    /// through the same `clearSelection` + `engine.play` path a human tap
    /// uses. Returns false when there is no move to make (game over).
    /// Lets a test drive a complete game through the real UI pipeline.
    @discardableResult
    func playFirstLegalMoveForCurrentSeat() -> Bool {
        guard engine.state.winner == nil else { return false }
        guard let move = engine.legalMovesForCurrentSeat().first else { return false }
        clearSelection()
        engine.play(move)
        return true
    }

    // MARK: - Privacy curtain (hot-seat)

    private func presentCurtain(for seat: SeatID) {
        curtain.configure(name: engine.state.players[seat].name, seat: seat)
        view.bringSubviewToFront(curtain)
        curtain.isHidden = false
        UIView.animate(withDuration: 0.22) { self.curtain.alpha = 1 }
        UIAccessibility.post(notification: .screenChanged, argument: curtain)
    }

    private func hideCurtain(animated: Bool) {
        guard !curtain.isHidden else { return }
        let finish = { self.curtain.isHidden = true }
        if animated {
            UIView.animate(withDuration: 0.2, animations: { self.curtain.alpha = 0 }) { _ in finish() }
        } else {
            curtain.alpha = 0
            finish()
        }
    }

    /// "Show my hand" tapped — reveal and start the inactivity timer.
    private func revealHand() {
        handRevealed = true
        hideCurtain(animated: true)
        refreshHandStrip()
        startAutoHide()
        UIAccessibility.post(notification: .screenChanged, argument: handStrip)
    }

    private func startAutoHide() {
        invalidateAutoHide()
        guard isHotSeat else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideSeconds,
                                             repeats: false) { [weak self] _ in
            self?.reHideForPrivacy()
        }
    }

    private func invalidateAutoHide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    /// Inactivity fired with no move played — drop the curtain again.
    private func reHideForPrivacy() {
        guard isHotSeat, engine.state.winner == nil,
              humanSeats.contains(engine.state.currentSeat) else { return }
        handRevealed = false
        clearSelection()
        presentCurtain(for: engine.state.currentSeat)
        refreshHandStrip()
    }

    private func announceTurn(_ seat: SeatID) {
        guard !isAutomatedTestMode else { return }
        // Hot-seat humans are announced by the curtain's screen-changed
        // event, so only narrate solo/AI turns here.
        guard !(isHotSeat && humanSeats.contains(seat)) else { return }
        let name = engine.state.players[seat].name
        let phrase = humanSeats.contains(seat) ? "Your turn, \(name)" : "\(name) is thinking"
        UIAccessibility.post(notification: .announcement, argument: phrase)
    }

    // MARK: - UI refresh

    private func refreshAllUI() {
        let s = engine.state
        let isHumanTurn = humanSeats.contains(s.currentSeat)
        infoPill.set(blinds: "Hand \(s.handsDealt)",
                     hand: "Jackaroo Basic",
                     phase: s.winner == nil
                         ? (isHumanTurn ? "\(s.players[s.currentSeat].name)'s turn"
                                        : "\(s.players[s.currentSeat].name) is thinking")
                         : "Game over")
        turnPill.set(name: s.players[s.currentSeat].name,
                     status: isHumanTurn ? "→ play a card" : "thinking…")
        turnPill.isAccessibilityElement = true
        turnPill.accessibilityLabel = s.winner != nil
            ? "Game over"
            : (isHumanTurn ? "\(s.players[s.currentSeat].name)'s turn to play a card"
                           : "\(s.players[s.currentSeat].name) is thinking")
        boardView.setFirePileTop(s.firePile.last)
        // While a marble is sliding, the board owns positions — snapping
        // here would teleport it. finishAnimation() reconciles when done.
        if !isAnimating { boardView.snapMarbles(from: s) }
        refreshHandStrip()
        refreshPlayerCorners()
    }

    private func refreshHandStrip() {
        if humanCanAct {
            handStrip.setHand(currentHand)
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
        guard humanCanAct else { return }
        guard let move = candidateMoves.first(where: { matchesTrackTarget($0, cellID: cellID) }) else {
            return
        }
        invalidateAutoHide()
        clearSelection()
        engine.play(move)
    }

    private func handleBoardSafeTap(seat: SeatID, lane: Int) {
        guard humanCanAct else { return }
        guard let move = candidateMoves.first(where: { matchesSafeTarget($0, seat: seat, lane: lane) }) else {
            return
        }
        invalidateAutoHide()
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
        case .kingThirteen:
            guard let m = mover else { return nil }
            let gen = JKLegalMoveGenerator(graph: engine.graph)
            return gen.walkKingThirteen(marble: m, seat: state.currentSeat,
                                        state: state)?.destination
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
        case let .kingThirteen(_, m):  id = m
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
        case .kingThirteen(_, let m):
            return "King 13 on marble \(m)"
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "How to play", style: .default) { [weak self] _ in
            guard let self else { return }
            self.present(JackarooRulesViewController(preset: self.engine.state.rules), animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Ruleset…", style: .default) { [weak self] _ in
            self?.presentRulesetPicker()
        })
        sheet.addAction(UIAlertAction(title: "Animation speed (\(JKGamePreferences.moveSpeed.label))…",
                                      style: .default) { [weak self] _ in
            self?.presentSpeedPicker()
        })
        let muteTitle = SoundManager.isMuted ? "Unmute sounds" : "Mute sounds"
        sheet.addAction(UIAlertAction(title: muteTitle, style: .default) { _ in
            SoundManager.setMuted(!SoundManager.isMuted)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = gearButton
            pop.sourceRect = gearButton.bounds
        }
        present(sheet, animated: true)
    }

    private func presentSpeedPicker() {
        let sheet = UIAlertController(title: "Marble animation speed", message: nil,
                                      preferredStyle: .actionSheet)
        for speed in JKMoveSpeed.allCases {
            let isCurrent = speed == JKGamePreferences.moveSpeed
            let title = isCurrent ? "✓ \(speed.label)" : speed.label
            sheet.addAction(UIAlertAction(title: title, style: .default) { _ in
                JKGamePreferences.moveSpeed = speed
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = gearButton
            pop.sourceRect = gearButton.bounds
        }
        present(sheet, animated: true)
    }

    /// Per-session ruleset picker. Presets are locked once a game
    /// starts, so choosing a different one starts a fresh game on the
    /// new ruleset; choosing the current one is a no-op.
    private func presentRulesetPicker() {
        let current = engine.state.rules
        let sheet = UIAlertController(
            title: "Ruleset",
            message: "Switching starts a new game on the chosen preset.",
            preferredStyle: .actionSheet)
        for option in JKRulesPreset.selectableOptions {
            let isCurrent = option.preset == current
            let title = isCurrent ? "✓ \(option.name)" : option.name
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard !isCurrent else { return }
                self?.restartGame(rules: option.preset)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = gearButton
            pop.sourceRect = gearButton.bounds
        }
        present(sheet, animated: true)
    }

    private func restartGame(rules: JKRulesPreset? = nil) {
        // Rebuild the same table (same humans + AIs, fresh hands) with a
        // new seed, replacing this VC in the nav stack. `rules` defaults
        // to the current ruleset (Play again) or a newly chosen preset
        // (Settings).
        let players = engine.state.players.map {
            JKPlayer(seat: $0.seat, name: $0.name, kind: $0.kind)
        }
        let fresh = JackarooGameViewController(players: players,
                                              seed: UInt64.random(in: 1...UInt64.max),
                                              rules: rules ?? engine.state.rules)
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
            dismiss(animated: true)
        }
    }
}

// MARK: - Hand strip delegate

extension JackarooGameViewController: JKHandStripDelegate {
    func handStrip(_ strip: JKHandStripView, didSelect card: JKCard, at index: Int) {
        guard humanCanAct else { return }
        startAutoHide()   // any interaction resets the inactivity curtain
        pickedCardIndex = index
        let allMoves = engine.legalMovesForCurrentSeat()
        candidateMoves = allMoves.filter { moveUsesCard($0, card) }

        if candidateMoves.isEmpty {
            // Visual shake — nothing to do with this card.
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            strip.clearSelection()
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(card.accessibleName) has no legal move")
            return
        }

        // Card select feedback (DESIGN §6: light haptic + button_tap).
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        JKAudio.shared.play(.select)

        // Highlight cell-based targets.
        let highlights = computeHighlights()
        boardView.highlightLegalTargets(trackCells: highlights.tracks,
                                        safeCells: highlights.safe)
        let targetCount = highlights.tracks.count + highlights.safe.values.reduce(0) { $0 + $1.count }
        if targetCount > 0 {
            UIAccessibility.post(notification: .announcement,
                                 argument: "\(card.accessibleName) selected, \(targetCount) target\(targetCount == 1 ? "" : "s")")
        }

        // For moves without a track destination, show an action sheet.
        let nonCellMoves = candidateMoves.filter { destination(of: $0) == nil }
        if highlights.tracks.isEmpty && highlights.safe.isEmpty && !nonCellMoves.isEmpty {
            handleSpecialCaseMove(nonCellMoves)
        }
    }

    func handStripDidTapBurn(_ strip: JKHandStripView) {
        guard humanCanAct else { return }
        let burns = engine.legalMovesForCurrentSeat().filter { $0.isBurn }
        if let first = burns.first {
            invalidateAutoHide()
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
             let .kingThirteen(c, _),
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
