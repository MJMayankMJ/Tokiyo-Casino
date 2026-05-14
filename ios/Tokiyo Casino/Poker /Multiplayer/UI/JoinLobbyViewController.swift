//
//  JoinLobbyViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Guest's discovery + lobby flow:
//   1. Browse for nearby tables (MPC).
//   2. Tap a table → request to join.
//   3. Wait in lobby until host starts the game.
//

import UIKit

final class JoinLobbyViewController: UIViewController {

    private let displayName: String
    private let transport: MPCTransport
    private let clientService: PokerClientService

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let tableView = UITableView()
    private let cancelButton = UIButton(type: .system)
    private let lobbyContainer = UIStackView()
    private let lobbySeatsStack = UIStackView()
    private let lobbyTitleLabel = UILabel()

    private var tables: [DiscoveredTable] = []
    private var currentLobby: LobbySnapshotPayload?
    private var hasPushedToGame: Bool = false

    init(displayName: String) {
        self.displayName = displayName
        self.transport = MPCTransport(displayName: displayName)
        self.clientService = PokerClientService(displayName: displayName, transport: transport)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.13, alpha: 1.0)
        setupUI()
        clientService.observer = self
        do {
            try clientService.startBrowsing()
            statusLabel.text = "Looking for nearby tables…"
        } catch {
            statusLabel.text = error.localizedDescription
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Avoid tearing down the live MPC session when we're just
        // presenting the network game on top of this lobby.
        guard isBeingDismissed || isMovingFromParent else { return }
        clientService.leaveTable()
    }

    private func setupUI() {
        titleLabel.text = "Nearby Tables"
        titleLabel.font = UIFont(name: "Copperplate-Bold", size: 26) ?? .boldSystemFont(ofSize: 26)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "Looking for nearby tables…"
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "row")

        lobbyContainer.axis = .vertical
        lobbyContainer.spacing = 12
        lobbyContainer.translatesAutoresizingMaskIntoConstraints = false
        lobbyContainer.isHidden = true

        lobbyTitleLabel.text = ""
        lobbyTitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        lobbyTitleLabel.textColor = .white

        lobbySeatsStack.axis = .vertical
        lobbySeatsStack.spacing = 8

        lobbyContainer.addArrangedSubview(lobbyTitleLabel)
        lobbyContainer.addArrangedSubview(lobbySeatsStack)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(statusLabel)
        view.addSubview(tableView)
        view.addSubview(lobbyContainer)
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            tableView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 18),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -12),

            lobbyContainer.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 18),
            lobbyContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            lobbyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    private func showLobby(_ snapshot: LobbySnapshotPayload) {
        currentLobby = snapshot
        tableView.isHidden = true
        lobbyContainer.isHidden = false
        statusLabel.text = "Joined — waiting for the host to start the game."
        lobbyTitleLabel.text = "Table seats"
        lobbySeatsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for seat in snapshot.seats {
            lobbySeatsStack.addArrangedSubview(seatRow(seat))
        }
    }

    private func seatRow(_ seat: LobbySeatPayload) -> UIView {
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
        kind.text = seat.isHost ? "Host" : seat.kind.uppercased()
        kind.font = .systemFont(ofSize: 12, weight: .medium)
        kind.textColor = UIColor.white.withAlphaComponent(0.75)
        kind.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(title); row.addSubview(name); row.addSubview(kind)
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

    private func presentNetworkGame() {
        guard !hasPushedToGame else { return }
        hasPushedToGame = true
        let vc = NetworkGameViewController(role: .client(clientService))
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - Discovery list

extension JoinLobbyViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tables.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath)
        let t = tables[indexPath.row]
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.7)
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.textLabel?.text = t.advert.displayName
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let t = tables[indexPath.row]
        statusLabel.text = "Joining \(t.advert.displayName)…"
        do { try clientService.join(table: t) }
        catch {
            statusLabel.text = "Failed to join: \(error.localizedDescription)"
        }
    }
}

// MARK: - PokerClientServiceObserver

extension JoinLobbyViewController: PokerClientServiceObserver {
    func client(_ service: PokerClientService, didFindTables tables: [DiscoveredTable]) {
        self.tables = tables
        tableView.reloadData()
        if tables.isEmpty {
            statusLabel.text = "Looking for nearby tables…"
        } else {
            statusLabel.text = "Found \(tables.count) nearby — tap one to join."
        }
    }

    func client(_ service: PokerClientService, didReceiveJoinAccepted payload: JoinAcceptedPayload) {
        showLobby(payload.lobby)
    }

    func client(_ service: PokerClientService, didReceiveJoinRejected payload: JoinRejectedPayload) {
        let alert = UIAlertController(title: "Couldn't join", message: payload.reason,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    func client(_ service: PokerClientService, transportError error: Error) {
        statusLabel.text = "Network error: \(error.localizedDescription)"
    }
}
