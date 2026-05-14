//
//  MultiplayerEntryViewController.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  The "Create Table" / "Join Nearby Table" chooser surfaced from the
//  poker menu when the user picks "Play With Friends".
//

import UIKit

final class MultiplayerEntryViewController: UIViewController {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let createButton = UIButton(type: .system)
    private let joinButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let nameField = UITextField()

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

        nameField.placeholder = "Your name"
        nameField.text = UserDefaults.standard.string(forKey: "tokiyo.poker.mp.displayName") ?? "Player"
        nameField.borderStyle = .roundedRect
        nameField.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        nameField.autocorrectionType = .no
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameField)

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

            nameField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 50),
            nameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            nameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            nameField.heightAnchor.constraint(equalToConstant: 44),

            createButton.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 50),
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

    private func saveName() -> String {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = name.isEmpty ? "Player" : name
        UserDefaults.standard.set(safe, forKey: "tokiyo.poker.mp.displayName")
        return safe
    }

    @objc private func createTapped() {
        let name = saveName()
        let vc = HostLobbyViewController(displayName: name)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func joinTapped() {
        let name = saveName()
        let vc = JoinLobbyViewController(displayName: name)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

extension MultiplayerEntryViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder(); return true
    }
}
