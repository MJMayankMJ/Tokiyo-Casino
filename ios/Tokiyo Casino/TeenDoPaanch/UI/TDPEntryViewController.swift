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

        let practice = TDPDesign.button("Play vs bots")
        practice.addTarget(self, action: #selector(didTapPractice), for: .touchUpInside)

        let pass = TDPDesign.button("Pass & play", filled: false)
        pass.addTarget(self, action: #selector(didTapPassAndPlay), for: .touchUpInside)

        let host = TDPDesign.button("Host a table", filled: false)
        host.addTarget(self, action: #selector(didTapHost), for: .touchUpInside)

        let join = TDPDesign.button("Join a table", filled: false)
        join.addTarget(self, action: #selector(didTapJoin), for: .touchUpInside)

        let rules = TDPTutorialEntryTile()
        rules.addTarget(self, action: #selector(didTapRules), for: .touchUpInside)

        var items: [UIView] = [heading, subtitle, nameField, practice, pass, host, join]
        #if DEBUG
        let debug = TDPDesign.button("Debug · khichai", filled: false)
        debug.addTarget(self, action: #selector(didTapDebugKhichai), for: .touchUpInside)
        items.append(debug)
        #endif
        items.append(rules)
        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: heading)
        stack.setCustomSpacing(24, after: subtitle)
        stack.setCustomSpacing(24, after: nameField)
        stack.setCustomSpacing(28, after: items[items.count - 2])
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Centred when it fits; scrolls on a small phone instead of running
        // up under the navigation bar.
        let scroll = UIScrollView()
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        let content = scroll.contentLayoutGuide
        let frame = scroll.frameLayoutGuide
        let snug = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        snug.priority = .defaultLow
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            snug,
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -16),
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
        let sheet = UIAlertController(title: "Players on this phone", message: nil, preferredStyle: .actionSheet)
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
            message: "You and Player 2 share this phone; Meera is a bot.",
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
        push(TDPTutorialViewController())
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
