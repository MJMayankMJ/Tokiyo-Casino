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

/// Poker's view of the app-wide `PlayerProfile`, so a name changed here,
/// in Profile or in another game is the same name everywhere.
enum MultiplayerProfile {

    /// The profile name. Never nil since onboarding; kept optional for the
    /// callers written before profiles existed.
    static var savedName: String? { PlayerProfile.name }

    /// Persist a new name. Empty/whitespace input is rejected (the
    /// caller is expected to keep prompting).
    static func save(_ name: String) -> Bool {
        PlayerProfile.setName(name)
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
        dprint("⚠️ Poker MP: failed to encode reconnect token store")
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
        dprint("⚠️ Poker MP: failed to encode reconnect token store while clearing")
        #endif
        return false
    }

    private static func all() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            #if DEBUG
            dprint("⚠️ Poker MP: corrupt reconnect token store removed: \(error)")
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
        refreshName()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshName),
                                               name: PlayerProfile.didChange, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: PlayerProfile.didChange, object: nil)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    @objc private func refreshName() {
        currentName = PlayerProfile.name
        identityChip.name = currentName
    }

    // MARK: - Profile

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leaveScreen()
    }

    /// The same Profile sheet every game uses — name, photo and cards.
    @objc private func changeNameTapped() {
        present(ProfileViewController.sheet(), animated: true)
    }

    // MARK: - Flow

    @objc private func createTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pushOrPresent(HostLobbyViewController(displayName: currentName))
    }

    @objc private func joinTapped() {
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
