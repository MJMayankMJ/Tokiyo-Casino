//
//  TDPEntryViewController.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Mode picker. Everything here is offline: practice and pass-and-play use
//  no network at all, and friends play is peer-to-peer over local Wi-Fi /
//  Bluetooth with no server involved.
//

import UIKit

final class TDPEntryViewController: UIViewController {

    private let nameField = UITextField()

    private var playerName: String {
        let raw = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "You" : raw
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPDesign.felt
        title = "Teen Do Paanch"
        navigationItem.largeTitleDisplayMode = .never
        build()
    }

    private func build() {
        let heading = TDPDesign.label("TEEN DO PAANCH", size: 26, weight: .heavy)
        let subtitle = TDPDesign.label("5 · 3 · 2", size: 15, weight: .semibold, color: TDPDesign.accent)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholder = "Your name"
        nameField.text = UIDevice.current.name
        nameField.textColor = TDPTheme.ink
        nameField.attributedPlaceholder = NSAttributedString(
            string: "Your name",
            attributes: [.foregroundColor: TDPDesign.dim]
        )
        nameField.backgroundColor = TDPTheme.raised
        nameField.layer.cornerRadius = 10
        nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        nameField.leftViewMode = .always
        nameField.autocorrectionType = .no
        nameField.returnKeyType = .done
        nameField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)

        let practice = TDPDesign.button("Practice  ·  you vs 2 AI")
        practice.addTarget(self, action: #selector(didTapPractice), for: .touchUpInside)

        let pass = TDPDesign.button("Pass & play  ·  share this device", filled: false)
        pass.addTarget(self, action: #selector(didTapPassAndPlay), for: .touchUpInside)

        let host = TDPDesign.button("Host a table  ·  nearby friends", filled: false)
        host.addTarget(self, action: #selector(didTapHost), for: .touchUpInside)

        let join = TDPDesign.button("Join a table", filled: false)
        join.addTarget(self, action: #selector(didTapJoin), for: .touchUpInside)

        let rules = TDPDesign.button("How to play", filled: false)
        rules.addTarget(self, action: #selector(didTapRules), for: .touchUpInside)

        let note = TDPDesign.label(
            "Friends play is peer-to-peer over local Wi-Fi or Bluetooth.\nNo internet, no account, no server.",
            size: 12, weight: .regular, color: TDPDesign.dim
        )
        note.numberOfLines = 0
        note.textAlignment = .center

        var items: [UIView] = [heading, subtitle, nameField, practice, pass, host, join, rules]
        #if DEBUG
        let debug = TDPDesign.button("Debug · khichai", filled: false)
        debug.addTarget(self, action: #selector(didTapDebugKhichai), for: .touchUpInside)
        items.append(debug)
        #endif
        items.append(note)
        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: heading)
        stack.setCustomSpacing(24, after: subtitle)
        stack.setCustomSpacing(24, after: nameField)
        stack.setCustomSpacing(24, after: items[items.count - 2])
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            nameField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func dismissKeyboard() { view.endEditing(true) }

    // MARK: Modes

    @objc private func didTapPractice() {
        let service = TDPHostService(mode: .practice, hostName: playerName)
        push(TDPGameViewController(driver: TDPHostDriver(service: service)))
    }

    @objc private func didTapPassAndPlay() {
        let sheet = UIAlertController(title: "Pass & play",
                                      message: "How many people are sharing this device?",
                                      preferredStyle: .actionSheet)
        for count in 2...3 {
            sheet.addAction(UIAlertAction(title: "\(count) players", style: .default) { [weak self] _ in
                guard let self else { return }
                let service = TDPHostService(mode: .passAndPlay(humanSeats: count), hostName: self.playerName)
                self.push(TDPGameViewController(driver: TDPHostDriver(service: service)))
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    @objc private func didTapHost() {
        push(TDPLobbyViewController(role: .host(name: playerName)))
    }

    @objc private func didTapJoin() {
        push(TDPLobbyViewController(role: .guest(name: playerName)))
    }

    #if DEBUG
    /// Debug builds: jump straight to settling up in round 2+.
    @objc private func didTapDebugKhichai() {
        let sheet = UIAlertController(
            title: "Debug · khichai",
            message: "Starts at settle-up with the cards dealt. You and Player 2 share this phone; Meera is a bot.",
            preferredStyle: .actionSheet)
        for scenario in TDPDebugScenario.allCases {
            sheet.addAction(UIAlertAction(title: scenario.title, style: .default) { [weak self] _ in
                self?.launchDebug(scenario)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    private func launchDebug(_ scenario: TDPDebugScenario) {
        let service = TDPHostService(mode: .passAndPlay(humanSeats: 2), hostName: playerName)
        let driver = TDPHostDriver(service: service)       // attach before the first publish
        service.debugStart(with: scenario.makeState(playerName: playerName))
        push(TDPGameViewController(driver: driver))
    }
    #endif

    @objc private func didTapRules() {
        push(TDPRulesViewController())
    }

    private func push(_ controller: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(controller, animated: true)
        } else {
            controller.modalPresentationStyle = .fullScreen
            present(controller, animated: true)
        }
    }
}

// MARK: - Rules

final class TDPRulesViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPDesign.felt
        title = "How to play"

        let text = """
        THE PACK
        30 cards — 8 to Ace in every suit, plus only the 7♥ and 7♠.
        Ace is high, 7 is low.

        SEATS AND QUOTAS
        Three players. Each seat owes a fixed number of tricks:
          • Trump selector (dealer's left) — 5
          • Third player (dealer's right) — 3
          • Dealer — 2
        That's 10 tricks between them, which is exactly how many there are.
        So every trick you take is one somebody else doesn't.

        THE DEAL
        Five cards each, then trump is chosen, then three, then two —
        which is where "5-3-2" comes from. The trump call is made on
        partial information, and that's the point.

        CHOOSING TRUMP
        Looking at your first five, you may:
          • name a suit outright, or
          • open your 7th card (the middle of the next three) and take
            its suit, or
          • take the suit of the highest of your next three, face down.
        The last two leak less about your hand, but you give up the choice.

        PLAY
        The trump selector leads and may lead any card. Follow suit if you can.
        If you can't, trump it or throw anything away. Highest trump wins,
        otherwise the highest card of the suit led. Winner leads next.

        SCORING
        Every trick you win scores one point. Your tricks-minus-quota result
        determines next round's card pulls, but does not change your points.

        KHICHAI — THE PULL
        This is what the game is remembered for. If you finished a round
        under quota, whoever finished over it may pull cards out of your
        hand — one for each trick they were owed.

        Before any card moves you choose, for each player you owe: give up the
        tricks — no cards move, but this round your target rises by what you
        owe and theirs falls by the same (never to the same player two rounds
        running) — or give cards.

        Giving cards: if a person is pulling, you get 10 seconds to arrange
        your cards face down. They pull blind, then hand you back any card —
        even the one they drew — which lands at a random spot in your cards.

        A session runs three rounds, or any multiple of three, so everyone
        deals, selects trump and sits third the same number of times.
        """

        let label = TDPDesign.label(text, size: 13, weight: .regular)
        label.numberOfLines = 0

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(label)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            label.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: scroll.leadingAnchor, constant: 22),
            label.trailingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: -22),
            label.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -40),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -44)
        ])
    }
}
