//
//  MultiplayerEntryViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Screen A — "Play with friends". The entry chooser after the user picks
//  Play With Friends from the main menu. Visual design mirrors the
//  Claude Design handoff bundle (poker/project/Multiplayer.html — screen A):
//  cancel text button top-left, title block with eyebrow, identity chip,
//  chip-tray ornament, then primary "Create Table" + secondary "Join
//  Nearby Table" CTAs stacked at the bottom.
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

    @discardableResult
    static func save(hostPeerId: String, tableId: String, token: String, seatId: Int) -> Bool {
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
            return true
        }
        #if DEBUG
        print("⚠️ Poker MP: failed to encode reconnect token store")
        #endif
        return false
    }

    @discardableResult
    static func clear(hostPeerId: String) -> Bool {
        let entries = all().filter { $0.hostPeerId != hostPeerId }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            return true
        }
        #if DEBUG
        print("⚠️ Poker MP: failed to encode reconnect token store while clearing")
        #endif
        return false
    }

    private static func all() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            #if DEBUG
            print("⚠️ Poker MP: corrupt reconnect token store removed: \(error)")
            #endif
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return []
        }
    }
}

final class MultiplayerEntryViewController: UIViewController {

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let titleBlock = MPTitleView(
        eyebrow: "Multiplayer",
        title: "Play with friends",
        subtitle: "Nearby — no internet required"
    )
    private let identityChip = MPIdentityChip()
    private let chipTray = MPChipTrayOrnament()
    private let createButton = MPPrimaryButton(title: "Create Table")
    private let joinButton = MPSecondaryButton(title: "Join Nearby Table")

    /// Cached name used for the next create/join flow. Set on
    /// `viewWillAppear` from the shared profile store.
    private var currentName: String = "Player"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        titleBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBlock)

        identityChip.translatesAutoresizingMaskIntoConstraints = false
        identityChip.addTarget(self, action: #selector(changeNameTapped), for: .touchUpInside)
        view.addSubview(identityChip)

        chipTray.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chipTray)

        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.addTarget(self, action: #selector(createTapped), for: .touchUpInside)
        view.addSubview(createButton)

        joinButton.translatesAutoresizingMaskIntoConstraints = false
        joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
        view.addSubview(joinButton)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            titleBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            titleBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            identityChip.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 18),
            identityChip.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            chipTray.topAnchor.constraint(equalTo: identityChip.bottomAnchor, constant: 32),
            chipTray.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chipTray.widthAnchor.constraint(equalToConstant: 220),
            chipTray.heightAnchor.constraint(equalToConstant: 90),

            joinButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            joinButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            joinButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            createButton.bottomAnchor.constraint(equalTo: joinButton.topAnchor, constant: -10),
            createButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)

        if let saved = MultiplayerProfile.savedName {
            currentName = saved
            identityChip.name = saved
        } else {
            // First-time user: prompt now so the name is set before
            // they pick create/join.
            promptForName(initialValue: nil, isFirstTime: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    // MARK: - Name prompt

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leaveScreen()
    }

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
                self.identityChip.name = saved
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushOrPresent(HostLobbyViewController(displayName: currentName))
    }

    @objc private func joinTapped() {
        guard !currentName.isEmpty else {
            promptForName(initialValue: nil, isFirstTime: true); return
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushOrPresent(JoinLobbyViewController(displayName: currentName))
    }

    private func pushOrPresent(_ vc: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }

    private func leaveScreen() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
