//
//  HostLobbyViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Screen B — "Your table". The host's pre-game lobby. Mirrors the Claude
//  Design handoff bundle (poker/project/Multiplayer.html — screen B):
//  cancel top-left, "Live · X of N" badge top-right, eyebrow + title,
//  recessed felt seat slots (host rail in gold, open seats show a card-back
//  medallion), a 2×2 settings grid (Blinds, Buy-in, Seats, AI Fill), then
//  a primary "Start Game" CTA pinned to the bottom.
//

import UIKit

final class HostLobbyViewController: UIViewController {

    private let displayName: String
    private let hostService: PokerHostService
    private let transport: MPCTransport

    // Layout
    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let liveBadge = MPLiveBadge(text: "Live · 1 of 6")
    private let titleBlock = MPTitleView(
        eyebrow: "Host Lobby",
        title: "Your table",
        subtitle: "Friends nearby can join now"
    )
    private let seatsStack = UIStackView()
    private let gameEyebrow = mpSectionEyebrow("Game")

    // Settings pills (held as properties so we can update their values
    // when host service config changes).
    private let blindsPill = MPStepperPill(label: "Blinds", value: "10 / 20")
    private let buyInPill = MPStepperPill(label: "Buy-in", value: "$1,000")
    private let seatsPill = MPStepperPill(label: "Seats", value: "6")
    private let aiPill = MPTogglePill(label: "AI Fill", isOn: true)

    private let startButton = MPPrimaryButton(title: "Start Game")

    init(displayName: String) {
        self.displayName = displayName
        self.transport = MPCTransport(displayName: displayName)
        self.hostService = PokerHostService(
            config: PokerHostService.Config(
                displayName: displayName,
                smallBlind: 10,
                bigBlind: 20,
                startingChips: 1000,
                totalSeats: 6,
                aiFillEnabled: true
            ),
            transport: transport
        )
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
        hostService.observer = self
        do {
            try hostService.startAdvertising()
        } catch {
            presentAlert(title: "Couldn't host", message: error.localizedDescription) { [weak self] in
                self?.leaveScreen()
            }
        }
        refreshSeatsFromService()
        refreshSettingsFromService()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
        // Only tear down when this VC is actually going away. A
        // modal full-screen presentation from this VC (e.g., the
        // NetworkGameViewController) also fires viewWillDisappear, and
        // calling endTable there would kill the live session.
        guard isBeingDismissed || isMovingFromParent else { return }
        if !hostService.hasStarted {
            hostService.endTable(reason: "Host left the lobby.")
        }
    }

    // MARK: UI

    private func setupUI() {
        [backdrop, backButton, liveBadge, titleBlock, seatsStack,
         gameEyebrow, blindsPill, buyInPill, seatsPill, aiPill, startButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        seatsStack.axis = .vertical
        seatsStack.spacing = 6
        seatsStack.alignment = .fill

        // Settings grid — 2 columns × 2 rows, 6pt gutter (matches JSX).
        let row1 = UIStackView(arrangedSubviews: [blindsPill, buyInPill])
        let row2 = UIStackView(arrangedSubviews: [seatsPill, aiPill])
        for row in [row1, row2] {
            row.axis = .horizontal
            row.spacing = 6
            row.distribution = .fillEqually
        }
        let grid = UIStackView(arrangedSubviews: [row1, row2])
        grid.axis = .vertical
        grid.spacing = 6
        grid.distribution = .fill
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)

        // Wire stepper handlers
        blindsPill.onMinus = { [weak self] in self?.bumpBlinds(by: -5) }
        blindsPill.onPlus  = { [weak self] in self?.bumpBlinds(by:  5) }
        buyInPill.onMinus  = { [weak self] in self?.bumpBuyIn(by: -100) }
        buyInPill.onPlus   = { [weak self] in self?.bumpBuyIn(by:  100) }
        seatsPill.onMinus  = { [weak self] in self?.bumpSeats(by: -1) }
        seatsPill.onPlus   = { [weak self] in self?.bumpSeats(by:  1) }
        aiPill.onValueChange = { [weak self] isOn in
            self?.hostService.updateSettings { c in c.aiFillEnabled = isOn }
        }

        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            liveBadge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            liveBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            titleBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            titleBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            seatsStack.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 18),
            seatsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            seatsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            gameEyebrow.topAnchor.constraint(equalTo: seatsStack.bottomAnchor, constant: 14),
            gameEyebrow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),

            grid.topAnchor.constraint(equalTo: gameEyebrow.bottomAnchor, constant: 8),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: Settings handlers

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leaveScreen()
    }

    private func bumpBlinds(by delta: Int) {
        let newSb = max(1, min(200, hostService.config.smallBlind + delta))
        hostService.updateSettings { c in
            c.smallBlind = newSb
            c.bigBlind = newSb * 2
        }
        refreshSettingsFromService()
    }

    private func bumpBuyIn(by delta: Int) {
        let v = max(100, min(5000, hostService.config.startingChips + delta))
        hostService.updateSettings { c in c.startingChips = v }
        refreshSettingsFromService()
    }

    private func bumpSeats(by delta: Int) {
        let occupied = hostService.seatRegistry.seats.filter { $0.kind != .open }.count
        let v = max(occupied, max(2, min(PokerProtocol.maxTotalSeats, hostService.config.totalSeats + delta)))
        hostService.updateSettings { c in c.totalSeats = v }
        refreshSettingsFromService()
    }

    private func refreshSettingsFromService() {
        let cfg = hostService.config
        blindsPill.value = "\(cfg.smallBlind) / \(cfg.bigBlind)"
        buyInPill.value = "$\(formatted(cfg.startingChips))"
        seatsPill.value = "\(cfg.totalSeats)"
        blindsPill.minusEnabled = cfg.smallBlind > 1
        blindsPill.plusEnabled = cfg.smallBlind < 200
        buyInPill.minusEnabled = cfg.startingChips > 100
        buyInPill.plusEnabled = cfg.startingChips < 5000
        let occupied = hostService.seatRegistry.seats.filter { $0.kind != .open }.count
        seatsPill.minusEnabled = cfg.totalSeats > max(2, occupied)
        seatsPill.plusEnabled = cfg.totalSeats < PokerProtocol.maxTotalSeats
        aiPill.isOn = cfg.aiFillEnabled
    }

    @objc private func startTapped() {
        let occupied = hostService.seatRegistry.seats.filter { $0.kind != .open }.count
        if occupied < 2 && !hostService.config.aiFillEnabled {
            presentAlert(title: "Not enough players",
                         message: "Wait for at least one friend to join, or turn on AI fill.")
            return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Present the network game BEFORE calling startGame so the new
        // VC is registered as the service's observer before any initial
        // `cardsDealt` / `gamePhaseDidChange` / `currentPlayerChanged`
        // callbacks fire. Otherwise the lobby (still observer) would
        // discard the first private-cards delivery and the host would
        // see no cards until the flop. The replay-on-attach in the
        // service is the belt; this is the suspenders.
        let vc = NetworkGameViewController(role: .host(hostService))
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true) { [weak self] in
            guard let self else { return }
            let didStart = self.hostService.startGame()
            if !didStart {
                self.presentAlert(title: "Couldn't start",
                                  message: "Need at least 2 seats to play.")
            }
        }
    }

    // MARK: Seats UI

    private func refreshSeatsFromService() {
        seatsStack.arrangedSubviews.forEach {
            seatsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for seat in hostService.seatRegistry.seats {
            seatsStack.addArrangedSubview(seatRow(seat))
        }
        let occupied = hostService.seatRegistry.seats.filter { $0.kind != .open }.count
        let total = hostService.config.totalSeats
        liveBadge.setText("Live · \(occupied) of \(total)")
    }

    private func seatRow(_ seat: SeatRegistry.SeatRecord) -> UIView {
        let kind: MPSeatSlot.Kind
        let isDealer = seat.seatId == 0
        switch seat.kind {
        case .host:
            kind = .host(name: seat.displayName, isDealer: isDealer)
        case .remote:
            let name = seat.isDisconnected ? "\(seat.displayName) · Reconnecting…" : seat.displayName
            kind = .occupied(name: name, isAI: false, isDealer: isDealer)
        case .ai:
            kind = .occupied(name: seat.displayName, isAI: true, isDealer: isDealer)
        case .open:
            kind = .open
        }
        return MPSeatSlot(seatNumber: seat.seatId + 1, kind: kind)
    }

    // MARK: Helpers

    private func formatted(_ value: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.groupingSeparator = ","
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func presentAlert(title: String, message: String, then: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in then?() })
        present(alert, animated: true)
    }

    /// Pop if pushed, otherwise dismiss — works in both navigation
    /// modes so we don't need a separate code path for legacy callers.
    private func leaveScreen() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

extension HostLobbyViewController: PokerHostServiceObserver {
    func host(_ service: PokerHostService, didUpdateLobby snapshot: LobbySnapshotPayload) {
        refreshSeatsFromService()
        refreshSettingsFromService()
    }
    func host(_ service: PokerHostService, didUpdateSnapshot snapshot: TableSnapshotPayload) {}
    func host(_ service: PokerHostService, didReceivePrivateCards payload: PrivateCardsPayload) {}
    func host(_ service: PokerHostService, didCompleteRound payload: RoundResultPayload) {}
    func host(_ service: PokerHostService, didEndSession payload: SessionResultPayload) {}
    func host(_ service: PokerHostService, didRequestAction payload: ActionRequestPayload) {}
    func host(_ service: PokerHostService, didFinishWithReason reason: String) {}
}
