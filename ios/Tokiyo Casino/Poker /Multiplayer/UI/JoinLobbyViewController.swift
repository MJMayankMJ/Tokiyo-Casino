//
//  JoinLobbyViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Screens C + D — "Nearby tables".
//
//   C · Scanning state — empty results: large central chip framed by an
//       animated sonar, "Scanning hosts in range…" indicator, and a hint
//       about Bluetooth proximity.
//   D · Results state — once one or more tables are discovered: list of
//       table-slot rows (host name, seat counts, blinds, buy-in) with a
//       Join pill on the right, plus a Scan Again CTA.
//
//  Once the guest is admitted, the lobby fades into a waiting-for-host
//  view that shares the seat-slot styling from Screen B.
//

import UIKit

final class JoinLobbyViewController: UIViewController {

    private let displayName: String
    private let transport: MPCTransport
    private let clientService: PokerClientService

    // Common chrome
    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let liveBadge = MPLiveBadge(text: "Scanning")
    private let titleBlock = MPTitleView(
        eyebrow: "Multiplayer",
        title: "Nearby tables",
        subtitle: "Scanning hosts in range…",
        showLiveDot: true
    )

    // Scanning state
    private let scanContainer = UIView()
    private let scanArea = UIView()
    private let sonar = MPSonarView()
    private let scanFelt = UIView()
    private let centerChip = MPChipView(size: 72, color: MPTheme.amber)
    private let scanHint = UILabel()

    // Results state
    private let resultsStack = UIStackView()
    private let scanAgainButton = MPSecondaryButton(
        title: "Scan Again",
        leadingIcon: UIImage(systemName: "arrow.clockwise")
    )

    // Joined-lobby (waiting for host) state
    private let waitingTitle = MPTitleView(
        eyebrow: "Joined",
        title: "Waiting for host",
        subtitle: "The host will start the game shortly"
    )
    private let waitingSeatsStack = UIStackView()
    private let waitingContainer = UIView()

    // State
    private var tables: [DiscoveredTable] = []
    private var currentLobby: LobbySnapshotPayload?
    private var hasPushedToGame: Bool = false
    private var hasJoined: Bool = false

    init(displayName: String) {
        self.displayName = displayName
        self.transport = MPCTransport(displayName: displayName)
        self.clientService = PokerClientService(displayName: displayName, transport: transport)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
        clientService.observer = self
        do {
            try clientService.startBrowsing()
        } catch {
            // Surface the error in the scan hint so the user sees what went wrong.
            scanHint.text = error.localizedDescription
        }
        applyState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
        sonar.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
        sonar.stop()
        // Avoid tearing down the live MPC session when we're just
        // presenting the network game on top of this lobby.
        guard isBeingDismissed || isMovingFromParent else { return }
        clientService.leaveTable()
    }

    private func setupUI() {
        // Common
        [backdrop, backButton, liveBadge, titleBlock,
         scanContainer, resultsStack, scanAgainButton,
         waitingContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // Scanning area
        scanArea.translatesAutoresizingMaskIntoConstraints = false
        sonar.translatesAutoresizingMaskIntoConstraints = false
        scanFelt.translatesAutoresizingMaskIntoConstraints = false
        centerChip.translatesAutoresizingMaskIntoConstraints = false
        scanHint.translatesAutoresizingMaskIntoConstraints = false

        scanContainer.addSubview(scanArea)
        scanArea.addSubview(scanFelt)
        scanArea.addSubview(sonar)
        scanArea.addSubview(centerChip)
        scanContainer.addSubview(scanHint)

        // Felt circle — radial gradient, then recessed inset shadow.
        scanFelt.backgroundColor = MPTheme.feltDepth
        scanFelt.layer.cornerRadius = 120
        scanFelt.layer.borderColor = MPTheme.feltEdge.cgColor
        scanFelt.layer.borderWidth = 1
        let feltGlow = CAGradientLayer()
        feltGlow.type = .radial
        feltGlow.colors = [
            MPTheme.felt.cgColor,
            MPTheme.feltDepth.cgColor,
            MPTheme.feltEdge.cgColor,
        ]
        feltGlow.locations = [0.0, 0.70, 1.0]
        feltGlow.startPoint = CGPoint(x: 0.5, y: 0.3)
        feltGlow.endPoint = CGPoint(x: 1.0, y: 1.0)
        feltGlow.cornerRadius = 120
        scanFelt.layer.insertSublayer(feltGlow, at: 0)
        self.scanFeltGlow = feltGlow

        scanHint.text = "Keep Bluetooth on and stay in the same room as the host."
        scanHint.textColor = MPTheme.muted
        scanHint.font = MPFont.ui(12.5)
        scanHint.textAlignment = .center
        scanHint.numberOfLines = 0

        // Results
        resultsStack.axis = .vertical
        resultsStack.spacing = 8
        resultsStack.alignment = .fill
        scanAgainButton.addTarget(self, action: #selector(scanAgainTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        // Waiting container holds the title + seat stack.
        waitingContainer.translatesAutoresizingMaskIntoConstraints = false
        waitingTitle.translatesAutoresizingMaskIntoConstraints = false
        waitingSeatsStack.translatesAutoresizingMaskIntoConstraints = false
        waitingContainer.addSubview(waitingTitle)
        waitingContainer.addSubview(waitingSeatsStack)
        waitingSeatsStack.axis = .vertical
        waitingSeatsStack.spacing = 6

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

            // Scanning state fills the area between title and bottom safe area
            scanContainer.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 12),
            scanContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),

            scanArea.topAnchor.constraint(equalTo: scanContainer.topAnchor),
            scanArea.leadingAnchor.constraint(equalTo: scanContainer.leadingAnchor),
            scanArea.trailingAnchor.constraint(equalTo: scanContainer.trailingAnchor),
            scanArea.bottomAnchor.constraint(equalTo: scanHint.topAnchor, constant: -12),

            scanFelt.centerXAnchor.constraint(equalTo: scanArea.centerXAnchor),
            scanFelt.centerYAnchor.constraint(equalTo: scanArea.centerYAnchor),
            scanFelt.widthAnchor.constraint(equalToConstant: 240),
            scanFelt.heightAnchor.constraint(equalToConstant: 240),

            sonar.centerXAnchor.constraint(equalTo: scanFelt.centerXAnchor),
            sonar.centerYAnchor.constraint(equalTo: scanFelt.centerYAnchor),
            sonar.widthAnchor.constraint(equalToConstant: 240),
            sonar.heightAnchor.constraint(equalToConstant: 240),

            centerChip.centerXAnchor.constraint(equalTo: scanFelt.centerXAnchor),
            centerChip.centerYAnchor.constraint(equalTo: scanFelt.centerYAnchor),
            centerChip.widthAnchor.constraint(equalToConstant: 72),
            centerChip.heightAnchor.constraint(equalToConstant: 72),

            scanHint.leadingAnchor.constraint(equalTo: scanContainer.leadingAnchor, constant: 32),
            scanHint.trailingAnchor.constraint(equalTo: scanContainer.trailingAnchor, constant: -32),
            scanHint.bottomAnchor.constraint(equalTo: scanContainer.bottomAnchor, constant: -18),

            // Results state
            resultsStack.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 18),
            resultsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            resultsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),

            scanAgainButton.topAnchor.constraint(equalTo: resultsStack.bottomAnchor, constant: 14),
            scanAgainButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scanAgainButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Waiting (joined) state
            waitingContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            waitingContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            waitingContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            waitingContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),

            waitingTitle.topAnchor.constraint(equalTo: waitingContainer.topAnchor),
            waitingTitle.leadingAnchor.constraint(equalTo: waitingContainer.leadingAnchor, constant: 24),
            waitingTitle.trailingAnchor.constraint(equalTo: waitingContainer.trailingAnchor, constant: -24),

            waitingSeatsStack.topAnchor.constraint(equalTo: waitingTitle.bottomAnchor, constant: 18),
            waitingSeatsStack.leadingAnchor.constraint(equalTo: waitingContainer.leadingAnchor, constant: 18),
            waitingSeatsStack.trailingAnchor.constraint(equalTo: waitingContainer.trailingAnchor, constant: -18),
        ])
    }

    private weak var scanFeltGlow: CAGradientLayer?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scanFeltGlow?.frame = scanFelt.bounds
    }

    // MARK: State machine

    /// Routes the three states (scanning, results, joined) by toggling
    /// the parent containers — keeps each block laid out independently
    /// in `setupUI` so re-rendering is cheap.
    private func applyState() {
        if hasJoined {
            scanContainer.isHidden = true
            resultsStack.isHidden = true
            scanAgainButton.isHidden = true
            waitingContainer.isHidden = false
            // (no Cancel button — the shared poker back pill handles dismissal)
            liveBadge.isHidden = true
            titleBlock.isHidden = true
        } else if tables.isEmpty {
            scanContainer.isHidden = false
            resultsStack.isHidden = true
            scanAgainButton.isHidden = true
            waitingContainer.isHidden = true
            titleBlock.setSubtitle("Scanning hosts in range…")
            liveBadge.setText("Scanning")
        } else {
            scanContainer.isHidden = true
            resultsStack.isHidden = false
            scanAgainButton.isHidden = false
            waitingContainer.isHidden = true
            titleBlock.setSubtitle("Tap a table to join")
            let openCount = tables.filter { !$0.advert.isStarted && $0.advert.humansJoined < $0.advert.totalSeats }.count
            liveBadge.setText("\(openCount) Open")
        }
    }

    private func rebuildResults() {
        resultsStack.arrangedSubviews.forEach {
            resultsStack.removeArrangedSubview($0); $0.removeFromSuperview()
        }
        // Stable chip colors based on table index (matches the design's
        // varied chip palette per table row).
        let palette: [UIColor] = [
            MPTheme.coral,
            UIColor(red: 0x9B/255.0, green: 0x7F/255.0, blue: 0xFF/255.0, alpha: 1),
            MPTheme.amber,
            MPTheme.forest,
            MPTheme.coralDeep,
        ]
        for (i, t) in tables.enumerated() {
            let advert = t.advert
            let players = advert.humansJoined
            let max = advert.totalSeats
            let blindsStr = "\(advert.smallBlind)/\(advert.bigBlind)"
            let row = MPTableSlot(
                host: advert.hostName,
                players: players,
                max: max,
                blinds: blindsStr,
                buyIn: nil,
                chipColor: palette[i % palette.count]
            )
            row.onJoin = { [weak self] in
                self?.handleJoinTapped(t)
            }
            resultsStack.addArrangedSubview(row)
        }
    }

    private func handleJoinTapped(_ table: DiscoveredTable) {
        do {
            try clientService.join(table: table)
        } catch {
            presentAlert(title: "Couldn't join", message: error.localizedDescription)
        }
    }

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leaveScreen()
    }

    @objc private func scanAgainTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        tables = []
        applyState()
        clientService.leaveTable()
        do { try clientService.startBrowsing() }
        catch { scanHint.text = error.localizedDescription }
    }

    // MARK: Joined-lobby presentation

    private func showLobby(_ snapshot: LobbySnapshotPayload) {
        currentLobby = snapshot
        hasJoined = true
        waitingSeatsStack.arrangedSubviews.forEach {
            waitingSeatsStack.removeArrangedSubview($0); $0.removeFromSuperview()
        }
        for seat in snapshot.seats {
            waitingSeatsStack.addArrangedSubview(lobbySeatRow(seat))
        }
        applyState()
    }

    private func lobbySeatRow(_ seat: LobbySeatPayload) -> UIView {
        // Treat the joining user's own seat as occupied; the host renders
        // with the gold rail; AIs and other humans get a regular chip; open
        // shows the cardback medallion.
        let isDealer = seat.seatId == 0
        let kind: MPSeatSlot.Kind
        if seat.isHost {
            kind = .host(name: seat.displayName, isDealer: isDealer)
        } else if seat.kind == "open" {
            kind = .open
        } else {
            let isAI = seat.kind.lowercased() == "ai"
            kind = .occupied(name: seat.displayName, isAI: isAI, isDealer: isDealer)
        }
        return MPSeatSlot(seatNumber: seat.seatId + 1, kind: kind)
    }

    private func presentNetworkGame() {
        guard !hasPushedToGame else { return }
        hasPushedToGame = true
        let vc = NetworkGameViewController(role: .client(clientService))
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func leaveScreen() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - PokerClientServiceObserver

extension JoinLobbyViewController: PokerClientServiceObserver {
    func client(_ service: PokerClientService, didFindTables tables: [DiscoveredTable]) {
        guard !hasJoined else { return }
        self.tables = tables
        rebuildResults()
        applyState()
    }

    func client(_ service: PokerClientService, didReceiveJoinAccepted payload: JoinAcceptedPayload) {
        showLobby(payload.lobby)
    }

    func client(_ service: PokerClientService, didReceiveJoinRejected payload: JoinRejectedPayload) {
        presentAlert(title: "Couldn't join", message: payload.reason)
    }

    func client(_ service: PokerClientService, didReceiveLobby snapshot: LobbySnapshotPayload) {
        showLobby(snapshot)
    }

    func client(_ service: PokerClientService, didReceiveSettings payload: LobbySettingsChangedPayload) {}

    func client(_ service: PokerClientService, didStartGame payload: StartGamePayload) {
        presentNetworkGame()
    }

    func client(_ service: PokerClientService, didReceiveSnapshot snapshot: TableSnapshotPayload) {
        presentNetworkGame()
    }

    func client(_ service: PokerClientService, didReceivePrivateCards payload: PrivateCardsPayload) {}
    func client(_ service: PokerClientService, didReceiveActionRequest payload: ActionRequestPayload) {}
    func client(_ service: PokerClientService, didReceiveActionAccepted payload: ActionAcceptedPayload) {}
    func client(_ service: PokerClientService, didReceiveActionRejected payload: ActionRejectedPayload) {}
    func client(_ service: PokerClientService, didReceiveRoundResult payload: RoundResultPayload) {}
    func client(_ service: PokerClientService, didReceiveSessionResult payload: SessionResultPayload) {}
    func client(_ service: PokerClientService, didPause payload: PausePayload) {}
    func client(_ service: PokerClientService, didResume payload: ResumePayload) {}

    func client(_ service: PokerClientService, hostEnded reason: String) {
        let alert = UIAlertController(title: "Host disconnected",
                                      message: "Table ended.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self else { return }
            if let nav = self.navigationController, nav.viewControllers.first !== self {
                nav.popViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        })
        present(alert, animated: true)
    }

    func client(_ service: PokerClientService, transportError error: Error) {
        scanHint.text = "Network error: \(error.localizedDescription)"
    }
}
