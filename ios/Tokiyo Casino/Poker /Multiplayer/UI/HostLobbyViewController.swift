//
//  HostLobbyViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  The host's pre-game lobby. Lists current seats (host + remote + AI +
//  open), exposes blinds/buy-in/AI-fill knobs, and starts the game when
//  the host taps "Start" (≥2 occupied seats required).
//

import UIKit

final class HostLobbyViewController: UIViewController {

    private let displayName: String
    private let hostService: PokerHostService
    private let transport: MPCTransport

    private let titleLabel = UILabel()
    private let codeLabel = UILabel()
    private let seatsStack = UIStackView()
    private let settingsStack = UIStackView()
    private let aiToggle = UISwitch()
    private let aiLabel = UILabel()
    private let blindsLabel = UILabel()
    private let buyInLabel = UILabel()
    private let seatsLabel = UILabel()
    private let blindsStepper = UIStepper()
    private let buyInStepper = UIStepper()
    private let seatsStepper = UIStepper()
    private let startButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

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
        view.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.05, alpha: 1.0)
        setupUI()
        hostService.observer = self
        do {
            try hostService.startAdvertising()
        } catch {
            presentAlert(title: "Couldn't host", message: error.localizedDescription) { [weak self] in
                self?.dismiss(animated: true)
            }
        }
        refreshSeatsFromService()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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
        titleLabel.text = "Your Table"
        titleLabel.font = UIFont(name: "Copperplate-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        codeLabel.text = "Friends nearby can join now"
        codeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        codeLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        codeLabel.textAlignment = .center
        codeLabel.translatesAutoresizingMaskIntoConstraints = false

        seatsStack.axis = .vertical
        seatsStack.spacing = 8
        seatsStack.alignment = .fill
        seatsStack.translatesAutoresizingMaskIntoConstraints = false

        settingsStack.axis = .vertical
        settingsStack.spacing = 10
        settingsStack.alignment = .fill
        settingsStack.translatesAutoresizingMaskIntoConstraints = false

        blindsLabel.text = "Blinds: 10 / 20"
        buyInLabel.text = "Buy-in: $1,000"
        seatsLabel.text = "Seats: 6"
        aiLabel.text = "Fill empty seats with AI"
        [blindsLabel, buyInLabel, seatsLabel, aiLabel].forEach {
            $0.textColor = .white
            $0.font = .systemFont(ofSize: 14, weight: .medium)
        }

        blindsStepper.minimumValue = 1
        blindsStepper.maximumValue = 200
        blindsStepper.stepValue = 5
        blindsStepper.value = 10
        blindsStepper.addTarget(self, action: #selector(blindsChanged), for: .valueChanged)

        buyInStepper.minimumValue = 100
        buyInStepper.maximumValue = 5000
        buyInStepper.stepValue = 100
        buyInStepper.value = 1000
        buyInStepper.addTarget(self, action: #selector(buyInChanged), for: .valueChanged)

        seatsStepper.minimumValue = 2
        seatsStepper.maximumValue = Double(PokerProtocol.maxTotalSeats)
        seatsStepper.stepValue = 1
        seatsStepper.value = 6
        seatsStepper.addTarget(self, action: #selector(seatsChanged), for: .valueChanged)

        aiToggle.isOn = true
        aiToggle.addTarget(self, action: #selector(aiToggled), for: .valueChanged)

        settingsStack.addArrangedSubview(rowStack(blindsLabel, blindsStepper))
        settingsStack.addArrangedSubview(rowStack(buyInLabel, buyInStepper))
        settingsStack.addArrangedSubview(rowStack(seatsLabel, seatsStepper))
        settingsStack.addArrangedSubview(rowStack(aiLabel, aiToggle))

        startButton.setTitle("START GAME", for: .normal)
        startButton.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor(red: 0.18, green: 0.55, blue: 0.30, alpha: 1.0)
        startButton.layer.cornerRadius = 24
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(codeLabel)
        view.addSubview(seatsStack)
        view.addSubview(settingsStack)
        view.addSubview(startButton)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            codeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            codeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            seatsStack.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 22),
            seatsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            seatsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            settingsStack.topAnchor.constraint(equalTo: seatsStack.bottomAnchor, constant: 22),
            settingsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            settingsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            startButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 260),
            startButton.heightAnchor.constraint(equalToConstant: 52),

            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func rowStack(_ label: UILabel, _ control: UIView) -> UIStackView {
        let s = UIStackView(arrangedSubviews: [label, UIView(), control])
        s.axis = .horizontal
        s.alignment = .center
        return s
    }

    // MARK: Settings handlers

    @objc private func blindsChanged() {
        let sb = Int(blindsStepper.value)
        blindsLabel.text = "Blinds: \(sb) / \(sb * 2)"
        hostService.updateSettings { c in
            c.smallBlind = sb
            c.bigBlind = sb * 2
        }
    }

    @objc private func buyInChanged() {
        let v = Int(buyInStepper.value)
        buyInLabel.text = "Buy-in: $\(formatted(v))"
        hostService.updateSettings { c in c.startingChips = v }
    }

    @objc private func seatsChanged() {
        let v = Int(seatsStepper.value)
        seatsLabel.text = "Seats: \(v)"
        hostService.updateSettings { c in c.totalSeats = v }
    }

    @objc private func aiToggled() {
        hostService.updateSettings { c in c.aiFillEnabled = self.aiToggle.isOn }
    }

    @objc private func startTapped() {
        let occupied = hostService.seatRegistry.seats.filter { $0.kind != .open }.count
        if occupied < 2 && !hostService.config.aiFillEnabled {
            presentAlert(title: "Not enough players",
                         message: "Wait for at least one friend to join, or turn on AI fill.")
            return
        }
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

    @objc private func cancelTapped() {
        hostService.endTable(reason: "Host cancelled the table.")
        dismiss(animated: true)
    }

    // MARK: Seats UI

    private func refreshSeatsFromService() {
        seatsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for seat in hostService.seatRegistry.seats {
            seatsStack.addArrangedSubview(seatRow(seat))
        }
    }

    private func seatRow(_ seat: SeatRegistry.SeatRecord) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        row.layer.cornerRadius = 10

        let title = UILabel()
        title.text = "Seat \(seat.seatId + 1)"
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = UIColor.white.withAlphaComponent(0.6)
        title.translatesAutoresizingMaskIntoConstraints = false

        let name = UILabel()
        name.text = seat.displayName
        name.font = .systemFont(ofSize: 16, weight: .bold)
        name.textColor = .white
        name.translatesAutoresizingMaskIntoConstraints = false

        let kind = UILabel()
        switch seat.kind {
        case .host: kind.text = "Host (you)"
        case .remote: kind.text = seat.isDisconnected ? "Reconnecting…" : "Remote"
        case .ai: kind.text = "AI"
        case .open: kind.text = "Open"
        }
        kind.font = .systemFont(ofSize: 12, weight: .medium)
        kind.textColor = UIColor.white.withAlphaComponent(0.75)
        kind.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(title)
        row.addSubview(name)
        row.addSubview(kind)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 56),
            title.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            title.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            name.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            name.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            kind.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            kind.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
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
}

extension HostLobbyViewController: PokerHostServiceObserver {
    func host(_ service: PokerHostService, didUpdateLobby snapshot: LobbySnapshotPayload) {
        refreshSeatsFromService()
    }
    func host(_ service: PokerHostService, didUpdateSnapshot snapshot: TableSnapshotPayload) {}
    func host(_ service: PokerHostService, didReceivePrivateCards payload: PrivateCardsPayload) {}
    func host(_ service: PokerHostService, didCompleteRound payload: RoundResultPayload) {}
    func host(_ service: PokerHostService, didEndSession payload: SessionResultPayload) {}
    func host(_ service: PokerHostService, didRequestAction payload: ActionRequestPayload) {}
    func host(_ service: PokerHostService, didFinishWithReason reason: String) {}
}
