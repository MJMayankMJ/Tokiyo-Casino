//
//  NetworkGameViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Snapshot-driven poker table that works for both host and guest. It
//  reuses `PokerTableView` (and therefore the entire existing poker
//  visual language) without touching the solo `GameViewController`.
//
//  Seats are rotated so the local player always renders at the bottom,
//  exactly mirroring the solo UX. Action controls only enable on the
//  local player's turn. Showdown reveals come from the host's snapshot
//  / round-result, never from local card knowledge of opponents.
//

import UIKit

enum NetworkGameRole {
    case host(PokerHostService)
    case client(PokerClientService)
}

final class NetworkGameViewController: UIViewController {

    // MARK: Layout

    private let tableView = PokerTableView()
    private let bettingControls = BettingControlsView()
    private var bettingControlsHeightConstraint: NSLayoutConstraint?
    private let topInfoBar = TopInfoBar()
    private let exitButton = UIButton(type: .system)
    private let statusBanner = UILabel()

    // MARK: State

    private let role: NetworkGameRole
    private var localSeatId: Int = 0
    private var localHoleCards: [Card] = []
    private var lastSnapshot: TableSnapshotPayload?
    private var lastRoundResult: RoundResultPayload?
    private var pendingActionRequest: ActionRequestPayload?
    /// Synthesized roster mirroring the snapshot, rotated so the local
    /// seat is at index 0.
    private var renderedPlayers: [Player] = []
    /// Mapping from rendered-index → original seat id. Lets us translate
    /// snapshot seat ids back and forth without confusing the table view.
    private var renderedSeatBySeatId: [Int: Int] = [:]
    private var renderedSeatIdByRenderedIndex: [Int: Int] = [:]

    init(role: NetworkGameRole) {
        self.role = role
        super.init(nibName: nil, bundle: nil)
        switch role {
        case .host(let h):
            self.localSeatId = h.hostSeatId
            h.observer = self
        case .client(let c):
            self.localSeatId = c.seatId ?? 0
            c.observer = self
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PokerTheme.pageBg
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        switch role {
        case .host(let h): h.endTable(reason: "Host left the table.")
        case .client(let c): c.leaveTable()
        }
    }

    // MARK: UI

    private func setupUI() {
        topInfoBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topInfoBar)
        topInfoBar.backButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        topInfoBar.menuButton.isHidden = true

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        bettingControls.translatesAutoresizingMaskIntoConstraints = false
        bettingControls.isHidden = true
        bettingControls.onAction = { [weak self] action in
            self?.submitLocalAction(action)
        }
        bettingControls.onHeightChanged = { [weak self] height in
            guard let self else { return }
            self.bettingControlsHeightConstraint?.constant = self.bettingControls.isHidden ? 0 : height
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
                self.view.layoutIfNeeded()
            }
        }
        view.addSubview(bettingControls)

        statusBanner.font = .systemFont(ofSize: 14, weight: .semibold)
        statusBanner.textColor = .white
        statusBanner.textAlignment = .center
        statusBanner.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        statusBanner.layer.cornerRadius = 10
        statusBanner.layer.masksToBounds = true
        statusBanner.translatesAutoresizingMaskIntoConstraints = false
        statusBanner.isHidden = true
        view.addSubview(statusBanner)

        let controlsHeight = bettingControls.heightAnchor.constraint(equalToConstant: 0)
        bettingControlsHeightConstraint = controlsHeight

        NSLayoutConstraint.activate([
            topInfoBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            topInfoBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topInfoBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topInfoBar.heightAnchor.constraint(equalToConstant: 48),

            tableView.topAnchor.constraint(equalTo: topInfoBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bettingControls.topAnchor, constant: -8),

            bettingControls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bettingControls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bettingControls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            controlsHeight,

            statusBanner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusBanner.topAnchor.constraint(equalTo: topInfoBar.bottomAnchor, constant: 8),
            statusBanner.heightAnchor.constraint(equalToConstant: 32),
            statusBanner.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
        ])
    }

    // MARK: Snapshot rendering

    /// Rebuilds the synthesized roster from the snapshot, rotates so the
    /// local seat is at index 0, and feeds it into PokerTableView.
    private func render(snapshot: TableSnapshotPayload) {
        // New-hand transition — clear the felt before re-rendering.
        if let prev = lastSnapshot, prev.handNumber != snapshot.handNumber {
            localHoleCards = []
            tableView.clearTable()
        }
        let previousCommunityCount = lastSnapshot?.communityCards.count ?? -1
        lastSnapshot = snapshot

        // Build rotation maps (snapshotSeatId → renderedIndex).
        let totalSeats = snapshot.players.count
        guard totalSeats > 0 else { return }
        let localIdx = snapshot.players.firstIndex(where: { $0.seatId == localSeatId }) ?? 0

        renderedSeatBySeatId.removeAll()
        renderedSeatIdByRenderedIndex.removeAll()

        var rendered: [Player] = []
        for offset in 0..<totalSeats {
            let snapshotIdx = (localIdx + offset) % totalSeats
            let ps = snapshot.players[snapshotIdx]
            let renderedIdx = offset
            renderedSeatBySeatId[ps.seatId] = renderedIdx
            renderedSeatIdByRenderedIndex[renderedIdx] = ps.seatId

            let isLocal = ps.seatId == localSeatId
            let type: PlayerType
            if isLocal {
                type = .human
            } else if let personality = AIPersonality.allCases.first(where: { _ in ps.kind == "ai" || ps.kind == "human" }) {
                // Remote humans use AI personality only to drive the
                // face-down rendering path in PlayerView; the actual
                // type label is purely cosmetic for the renderer.
                type = .ai(personality: personality)
            } else {
                type = .ai(personality: .balanced)
            }
            let player = Player(id: ps.seatId, name: ps.displayName, type: type, chips: ps.chips)
            player.currentBet = ps.currentBet
            player.totalInvested = ps.totalInvested
            player.isFolded = ps.isFolded
            player.isAllIn = ps.isAllIn
            player.isActive = ps.isActive

            if let lastName = ps.lastAction,
               let action = SnapshotBuilder.decodeAction(name: lastName,
                                                         raiseAmount: ps.lastActionAmount) {
                player.lastAction = action
            }

            if isLocal && !localHoleCards.isEmpty {
                player.holeCards = localHoleCards
            } else if let revealed = ps.revealedHoleCards {
                player.holeCards = revealed.compactMap { Card(dto: $0) }
            } else if ps.hasCards {
                // Placeholder backs so the renderer shows two face-down cards.
                player.holeCards = [
                    Card(suit: .spades, rank: .two),
                    Card(suit: .spades, rank: .two)
                ]
            }
            rendered.append(player)
        }
        renderedPlayers = rendered

        // Find the rendered index of the dealer.
        let renderedDealer = renderedSeatBySeatId[snapshot.dealerSeat] ?? 0

        // Set up seats once, then update on subsequent snapshots.
        if tableView.playerViews.isEmpty {
            tableView.setupPlayers(rendered, dealerIndex: renderedDealer)
        } else {
            tableView.updatePlayers(rendered, dealerIndex: renderedDealer)
        }

        if snapshot.communityCards.count != previousCommunityCount {
            tableView.showCommunityCards(snapshot.communityCards.compactMap { Card(dto: $0) })
        }
        tableView.updatePot(snapshot.pot)
        tableView.updatePhase(SnapshotBuilder.decodePhase(snapshot.phase))
        topInfoBar.setInfo(
            blinds: "\(snapshot.smallBlind)/\(snapshot.bigBlind)",
            hand: "Hand \(snapshot.handNumber)",
            phase: SnapshotBuilder.decodePhase(snapshot.phase).description
        )

        // Highlight current player.
        if let currentSeat = snapshot.currentPlayerSeat,
           let renderedIdx = renderedSeatBySeatId[currentSeat],
           renderedIdx < rendered.count {
            tableView.highlightCurrentPlayer(rendered[renderedIdx])
        }

        // Show pause banner if needed.
        if snapshot.isPaused, let waiting = snapshot.pausedForSeatId,
           let player = snapshot.players.first(where: { $0.seatId == waiting }) {
            statusBanner.text = "Waiting for \(player.displayName) to reconnect…"
            statusBanner.isHidden = false
        } else {
            statusBanner.isHidden = true
        }

        // Hide betting controls if it's no longer our turn.
        if snapshot.currentPlayerSeat != localSeatId {
            hideBettingControls()
        }
    }

    // MARK: Action controls

    private func presentActionRequest(_ request: ActionRequestPayload) {
        guard request.seatId == localSeatId else { return }
        pendingActionRequest = request

        // Map validActions strings → PlayerAction stubs for the view.
        let actions: [PlayerAction] = request.validActions.compactMap { name in
            SnapshotBuilder.decodeAction(name: name, raiseAmount: request.minRaise)
        }
        bettingControls.isHidden = false
        bettingControls.updateForActions(
            actions,
            callAmount: request.callAmount,
            minRaise: request.minRaise,
            maxRaise: request.maxRaise,
            currentBet: request.currentBet,
            allInTotal: request.allInTotal
        )
        bettingControlsHeightConstraint?.constant = bettingControls.preferredHeight
        UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }

    private func hideBettingControls() {
        bettingControls.isHidden = true
        bettingControlsHeightConstraint?.constant = 0
        UIView.animate(withDuration: 0.2) { self.view.layoutIfNeeded() }
    }

    private func submitLocalAction(_ action: PlayerAction) {
        hideBettingControls()
        switch role {
        case .host(let h):
            h.submitHostAction(action)
        case .client(let c):
            c.sendActionIntent(action)
        }
    }

    @objc private func exitTapped() {
        let alert = UIAlertController(title: "Leave Table?", message: nil,
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.dismissBackToEntry()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Dismiss both this VC and its presenting lobby in one step so the
    /// user lands on the multiplayer entry screen, never on a stale
    /// lobby that is no longer connected.
    private func dismissBackToEntry() {
        if let lobby = presentingViewController {
            lobby.dismiss(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: Round result

    fileprivate func handleRoundResult(_ payload: RoundResultPayload) {
        lastRoundResult = payload

        // Apply revealed cards to non-folded seats so PlayerView's
        // revealCards() animation shows the right faces.
        for reveal in payload.revealedHoleCards {
            guard let renderedIdx = renderedSeatBySeatId[reveal.seatId],
                  renderedIdx < renderedPlayers.count else { continue }
            renderedPlayers[renderedIdx].holeCards = reveal.cards.compactMap { Card(dto: $0) }
        }
        if let snapshot = lastSnapshot {
            tableView.updatePlayers(
                renderedPlayers,
                dealerIndex: renderedSeatBySeatId[snapshot.dealerSeat] ?? 0
            )
        }
        tableView.revealAllCards()

        // Build banner entries.
        let multi = payload.winners.count > 1
        let entries: [RoundResultBanner.Entry] = payload.winners.map { w in
            let isHuman = w.seatId == localSeatId
            let nameLead = isHuman ? "You" : w.displayName
            let amount = "$\(ChipFormatter.string(w.amount))"
            let title: String
            if multi {
                title = isHuman ? "You win side pot \(amount)" : "\(nameLead) wins side pot \(amount)"
            } else {
                title = isHuman ? "You win \(amount)" : "\(nameLead) wins \(amount)"
            }
            return RoundResultBanner.Entry(title: title,
                                           subtitle: w.handDescription,
                                           isHuman: isHuman)
        }

        // Pot animation to the largest winner.
        if let main = payload.winners.max(by: { $0.amount < $1.amount }),
           let renderedIdx = renderedSeatBySeatId[main.seatId],
           renderedIdx < renderedPlayers.count {
            tableView.animatePotTo(playerId: renderedPlayers[renderedIdx].id)
            tableView.showWinner(renderedPlayers[renderedIdx])
        }

        let duration: TimeInterval = multi ? 3.5 : 2.8
        tableView.showRoundResultBanner(entries: entries, duration: duration) { [weak self] in
            self?.tableView.clearWinningHighlights()
            // Host kicks off the next hand from its own service. Clients
            // wait for the next `tableSnapshot` to arrive.
        }
    }

    fileprivate func handleSessionResult(_ payload: SessionResultPayload) {
        let alert = UIAlertController(title: "Session ended", message: payload.reason,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Back to menu", style: .default) { [weak self] _ in
            self?.dismissBackToEntry()
        })
        present(alert, animated: true)
    }

    fileprivate func handleHostEnded(_ reason: String) {
        let alert = UIAlertController(title: "Host disconnected",
                                      message: "Table ended.\n\n\(reason)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismissBackToEntry()
        })
        present(alert, animated: true)
    }
}

// MARK: - Host observer

extension NetworkGameViewController: PokerHostServiceObserver {
    func host(_ service: PokerHostService, didUpdateLobby snapshot: LobbySnapshotPayload) {}
    func host(_ service: PokerHostService, didUpdateSnapshot snapshot: TableSnapshotPayload) {
        render(snapshot: snapshot)
    }
    func host(_ service: PokerHostService, didReceivePrivateCards payload: PrivateCardsPayload) {
        guard payload.seatId == localSeatId else { return }
        localHoleCards = payload.cards.compactMap { Card(dto: $0) }
        if let snapshot = lastSnapshot { render(snapshot: snapshot) }
    }
    func host(_ service: PokerHostService, didCompleteRound payload: RoundResultPayload) {
        handleRoundResult(payload)
    }
    func host(_ service: PokerHostService, didEndSession payload: SessionResultPayload) {
        handleSessionResult(payload)
    }
    func host(_ service: PokerHostService, didRequestAction payload: ActionRequestPayload) {
        presentActionRequest(payload)
    }
    func host(_ service: PokerHostService, didFinishWithReason reason: String) {
        handleHostEnded(reason)
    }
}

// MARK: - Client observer

extension NetworkGameViewController: PokerClientServiceObserver {
    func client(_ service: PokerClientService, didFindTables tables: [DiscoveredTable]) {}
    func client(_ service: PokerClientService, didReceiveJoinAccepted payload: JoinAcceptedPayload) {
        localSeatId = payload.seatId
    }
    func client(_ service: PokerClientService, didReceiveJoinRejected payload: JoinRejectedPayload) {
        handleHostEnded(payload.reason)
    }
    func client(_ service: PokerClientService, didReceiveLobby snapshot: LobbySnapshotPayload) {}
    func client(_ service: PokerClientService, didReceiveSettings payload: LobbySettingsChangedPayload) {}
    func client(_ service: PokerClientService, didStartGame payload: StartGamePayload) {}
    func client(_ service: PokerClientService, didReceiveSnapshot snapshot: TableSnapshotPayload) {
        render(snapshot: snapshot)
    }
    func client(_ service: PokerClientService, didReceivePrivateCards payload: PrivateCardsPayload) {
        guard payload.seatId == localSeatId else { return }
        localHoleCards = payload.cards.compactMap { Card(dto: $0) }
        if let snapshot = lastSnapshot { render(snapshot: snapshot) }
    }
    func client(_ service: PokerClientService, didReceiveActionRequest payload: ActionRequestPayload) {
        presentActionRequest(payload)
    }
    func client(_ service: PokerClientService, didReceiveActionAccepted payload: ActionAcceptedPayload) {}
    func client(_ service: PokerClientService, didReceiveActionRejected payload: ActionRejectedPayload) {
        let alert = UIAlertController(title: "Action rejected", message: payload.reason,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    func client(_ service: PokerClientService, didReceiveRoundResult payload: RoundResultPayload) {
        handleRoundResult(payload)
    }
    func client(_ service: PokerClientService, didReceiveSessionResult payload: SessionResultPayload) {
        handleSessionResult(payload)
    }
    func client(_ service: PokerClientService, didPause payload: PausePayload) {
        statusBanner.text = payload.reason
        statusBanner.isHidden = false
    }
    func client(_ service: PokerClientService, didResume payload: ResumePayload) {
        statusBanner.isHidden = true
    }
    func client(_ service: PokerClientService, hostEnded reason: String) {
        handleHostEnded(reason)
    }
    func client(_ service: PokerClientService, transportError error: Error) {
        handleHostEnded(error.localizedDescription)
    }
}
