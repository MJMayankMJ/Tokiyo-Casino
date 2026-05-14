//
//  MultiplayerEntryViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Entry chooser shown after the user picks "Play With Friends".
//  Name capture is one-time: on first launch the user is prompted via
//  an alert; on subsequent launches the saved name is reused and shown
//  with a "Change" affordance so they can update it without being
//  asked every visit.
//

import UIKit

/// Shared player-name store. All multiplayer screens read/write through
/// here so name updates apply uniformly to create + join flows.
enum MultiplayerProfile {
    private static let defaultsKey = "tokiyo.poker.mp.displayName"

    /// Currently saved name, or nil if the user has never entered one.
    static var savedName: String? {
        let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Persist a new name. Empty/whitespace input is rejected (the
    /// caller is expected to keep prompting).
    static func save(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)
        return true
    }
}

/// Persistent reconnect-token vault. Survives app force-quits so a
/// guest can reclaim their seat after the app is killed and reopened.
///
/// Keyed by the host's stable identifier (MPC display name), with the
/// table id stored alongside so we only offer the token to the same
/// host on the same table. If the host restarts the table the tableId
/// changes and we ignore the stale token.
enum ReconnectTokenStore {
    private static let defaultsKey = "tokiyo.poker.mp.reconnectTokens"

    /// One entry per host we've successfully joined.
    struct Entry: Codable {
        let hostPeerId: String
        let tableId: String
        let token: String
        let seatId: Int
        let savedAt: Date
    }

    static func token(forHost hostPeerId: String, tableId: String) -> String? {
        all().first { $0.hostPeerId == hostPeerId && $0.tableId == tableId }?.token
    }

    static func save(hostPeerId: String, tableId: String, token: String, seatId: Int) {
        var entries = all().filter { $0.hostPeerId != hostPeerId }
        entries.append(Entry(
            hostPeerId: hostPeerId, tableId: tableId,
            token: token, seatId: seatId, savedAt: Date()
        ))
        // Cap the list so it can't grow unbounded.
        if entries.count > 16 {
            entries = Array(entries.suffix(16))
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func clear(hostPeerId: String) {
        let entries = all().filter { $0.hostPeerId != hostPeerId }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func all() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }
}

final class MultiplayerEntryViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let createButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let nameChip = UIButton(type: .system)

    /// Cached name used for the next create/join flow. Set on
    /// `viewWillAppear` from the shared profile store.
    private var currentName: String = "Player"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.05, green: 0.07, blue: 0.13, alpha: 1.0)

        titleLabel.text = "Play With Friends"
        titleLabel.font = UIFont(name: "Copperplate-Bold", size: 30) ?? .boldSystemFont(ofSize: 30)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel.text = "Nearby — no Wi-Fi or router required"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Name chip — tappable label like "Playing as Mayank  ✎ Change".
        // Replaces the previous always-on text field; the user enters
        // their name once and can edit here whenever they want.
        nameChip.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        nameChip.setTitleColor(.white, for: .normal)
        nameChip.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        nameChip.layer.cornerRadius = 18
        nameChip.layer.borderWidth = 1
        nameChip.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        nameChip.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        nameChip.addTarget(self, action: #selector(changeNameTapped), for: .touchUpInside)
        nameChip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameChip)

        styleButton(createButton, title: "CREATE TABLE",
                    background: UIColor(red: 0.18, green: 0.55, blue: 0.30, alpha: 1.0))
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        view.addSubview(createButton)

        styleButton(joinButton, title: "JOIN NEARBY TABLE",
                    background: UIColor(red: 0.20, green: 0.40, blue: 0.75, alpha: 1.0))
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
        view.addSubview(joinButton)

        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            nameChip.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            nameChip.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameChip.heightAnchor.constraint(equalToConstant: 36),

            createButton.topAnchor.constraint(equalTo: nameChip.bottomAnchor, constant: 50),
            createButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createButton.widthAnchor.constraint(equalToConstant: 260),
            createButton.heightAnchor.constraint(equalToConstant: 56),

            joinButton.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 18),
            joinButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            joinButton.widthAnchor.constraint(equalToConstant: 260),
            joinButton.heightAnchor.constraint(equalToConstant: 56),

            closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let saved = MultiplayerProfile.savedName {
            currentName = saved
            updateNameChip()
        } else {
            // First-time user: prompt now so the name is set before
            // they pick create/join.
            promptForName(initialValue: nil, isFirstTime: true)
        }
    }

    private func styleButton(_ button: UIButton, title: String, background: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "Copperplate-Bold", size: 18) ?? .boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = background
        button.layer.cornerRadius = 24
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowOpacity = 0.45
        button.layer.shadowRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func updateNameChip() {
        nameChip.setTitle("Playing as \(currentName)  •  Change", for: .normal)
    }

    // MARK: - Name prompt

    @objc private func changeNameTapped() {
        promptForName(initialValue: currentName, isFirstTime: false)
    }

    /// Shows the one-time / change-name alert. The "Cancel" path is
    /// only enabled when the user already has a saved name —
    /// first-time users must enter something to proceed.
    private func promptForName(initialValue: String?, isFirstTime: Bool) {
        let alert = UIAlertController(
            title: isFirstTime ? "What should we call you?" : "Change your name",
            message: "Other players see this on the felt. You can change it any time from this screen.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Your name"
            field.text = initialValue
            field.autocapitalizationType = .words
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
            field.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let entered = alert?.textFields?.first?.text ?? ""
            if MultiplayerProfile.save(entered),
               let saved = MultiplayerProfile.savedName {
                self.currentName = saved
                self.updateNameChip()
            } else {
                // Empty input: reprompt.
                self.promptForName(initialValue: nil, isFirstTime: isFirstTime)
            }
        })
        if !isFirstTime {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        }
        present(alert, animated: true)
    }

    // MARK: - Flow

    @objc private func createTapped() {
        guard !currentName.isEmpty else {
            promptForName(initialValue: nil, isFirstTime: true); return
        }
        let vc = HostLobbyViewController(displayName: currentName)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func joinTapped() {
        guard !currentName.isEmpty else {
            promptForName(initialValue: nil, isFirstTime: true); return
        }
        let vc = JoinLobbyViewController(displayName: currentName)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
