//
//  TDPLobbyViewController.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Host and join, in one screen. The host advertises a table and watches
//  seats fill; a guest browses nearby tables and joins one. Empty seats
//  become AI when the host starts, so a table can be 1, 2 or 3 humans.
//

import UIKit

final class TDPLobbyViewController: UIViewController {

    enum Role {
        /// `rounds` is fixed here, before anyone joins.
        case host(name: String, rounds: Int)
        case guest(name: String)
    }

    private let role: Role
    private var hostService: TDPHostService?
    private var clientService: TDPClientService?

    private let statusLabel = TDPDesign.label(size: 14, weight: .semibold, color: TDPDesign.dim)
    private let seatStack = UIStackView()
    private let tableStack = UIStackView()
    private let startButton = TDPDesign.button("Start with AI filling empty seats")

    private var discovered: [TDPDiscoveredTable] = []
    private var didLaunchGame = false

    init(role: Role) {
        self.role = role
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPDesign.felt
        build()

        switch role {
        case .host(let name, let rounds):
            title = "Your table"
            let service = TDPHostService(mode: .friends, hostName: name, targetRounds: rounds)
            service.delegate = self
            service.startHosting(displayName: name)
            hostService = service
            statusLabel.text = "\(rounds) rounds. Friends nearby can join — or start now and bots fill in."
        case .guest(let name):
            title = "Nearby tables"
            startButton.isHidden = true
            let service = TDPClientService(displayName: name)
            service.delegate = self
            service.startBrowsing()
            clientService = service
            statusLabel.text = "Looking for tables nearby…"
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || isBeingDismissed, !didLaunchGame else { return }
        hostService?.stopHosting()
        clientService?.leave()
    }

    private func build() {
        statusLabel.numberOfLines = 0
        seatStack.axis = .vertical
        seatStack.spacing = 8
        tableStack.axis = .vertical
        tableStack.spacing = 8

        startButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [statusLabel, seatStack, tableStack, startButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24)
        ])
    }

    // MARK: Rendering

    private func renderSeats(_ snapshot: TDPLobbySnapshot) {
        seatStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for seat in snapshot.seats {
            let quota = seat.seat == 0 ? "" : ""
            let text = "Seat \(seat.seat + 1) — \(seat.name)\(quota)"
            let label = TDPDesign.label(text, size: 15, weight: .semibold,
                                        color: seat.kind == "open" ? TDPDesign.dim : TDPDesign.text)
            let row = UIView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.backgroundColor = TDPTheme.raised
            row.alpha = seat.kind == "open" ? 0.55 : 1
            row.layer.cornerRadius = 10
            row.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
                label.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14)
            ])
            seatStack.addArrangedSubview(row)
        }
    }

    private func renderTables() {
        tableStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !discovered.isEmpty else {
            tableStack.addArrangedSubview(
                TDPDesign.label("No tables found yet.", size: 14, weight: .regular, color: TDPDesign.dim)
            )
            return
        }
        for (index, table) in discovered.enumerated() {
            let title = "\(table.advert.hostName)  ·  \(table.advert.humansJoined)/3  ·  \(table.advert.targetRounds) rounds"
            let button = TDPDesign.button(table.advert.isStarted ? "\(title) (started)" : title,
                                          filled: !table.advert.isStarted)
            button.isEnabled = !table.advert.isStarted
            button.tag = index
            button.addTarget(self, action: #selector(didTapTable(_:)), for: .touchUpInside)
            tableStack.addArrangedSubview(button)
        }
    }

    // MARK: Actions

    @objc private func didTapStart() {
        guard let hostService else { return }
        didLaunchGame = true
        let driver = TDPHostDriver(service: hostService)
        navigationController?.pushViewController(TDPGameViewController(driver: driver), animated: true)
    }

    @objc private func didTapTable(_ sender: UIButton) {
        guard sender.tag < discovered.count, let clientService else { return }
        statusLabel.text = "Joining \(discovered[sender.tag].advert.hostName)'s table…"
        clientService.join(discovered[sender.tag])
    }

    private func launchGuestGame() {
        guard !didLaunchGame, let clientService else { return }
        didLaunchGame = true
        let driver = TDPClientDriver(service: clientService)
        navigationController?.pushViewController(TDPGameViewController(driver: driver), animated: true)
    }

    private func alert(_ message: String) {
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "OK", style: .default))
        present(controller, animated: true)
    }
}

// MARK: - Host

extension TDPLobbyViewController: TDPHostServiceDelegate {

    func host(_ service: TDPHostService, didUpdateLobby snapshot: TDPLobbySnapshot) {
        renderSeats(snapshot)
    }

    func host(_ service: TDPHostService, didUpdateLocalView view: TDPClientView, seat: TDPSeat) {
        // Ignored here — the game screen takes over as delegate once started.
    }
}

// MARK: - Guest

extension TDPLobbyViewController: TDPClientServiceDelegate {

    func client(_ service: TDPClientService, didUpdateTables tables: [TDPDiscoveredTable]) {
        discovered = tables
        statusLabel.text = tables.isEmpty
            ? "Looking for tables nearby…"
            : "Tap a table to join."
        renderTables()
    }

    func client(_ service: TDPClientService, didJoinSeat seat: TDPSeat) {
        statusLabel.text = "You're in at seat \(seat + 1). Waiting for the host to start…"
    }

    func client(_ service: TDPClientService, didUpdateLobby snapshot: TDPLobbySnapshot) {
        renderSeats(snapshot)
    }

    func client(_ service: TDPClientService, didUpdateView view: TDPClientView) {
        // The first view means the host has dealt — move to the table.
        launchGuestGame()
    }

    func client(_ service: TDPClientService, didFailWith reason: String) {
        guard !didLaunchGame else { return }
        statusLabel.text = reason
        alert(reason)
    }
}
