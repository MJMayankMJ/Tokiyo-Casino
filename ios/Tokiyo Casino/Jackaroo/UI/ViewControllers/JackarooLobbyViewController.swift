//
//  JackarooLobbyViewController.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  Hot-seat lobby. The chosen number of humans take the first seats and
//  AI fills the rest; partners sit opposite (seats 1 & 3 vs 2 & 4). Each
//  human gets an editable name; Start is enabled once every human is
//  named.
//

import UIKit

final class JackarooLobbyViewController: UIViewController {

    private let humanCount: Int

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let scrollView = UIScrollView()
    private let titleBlock = MPTitleView(eyebrow: "Hot-Seat", title: "Who's playing?",
                                         subtitle: "Pass the device on each turn")
    private let startButton = MPPrimaryButton(title: "Start Game")

    private var nameFields: [Int: UITextField] = [:]   // seat -> field

    init(humanCount: Int) {
        self.humanCount = max(2, min(4, humanCount))
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
        validate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    private func setupUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        let center = UIStackView()
        center.axis = .vertical
        center.alignment = .fill
        center.spacing = 12
        center.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(center)

        titleBlock.translatesAutoresizingMaskIntoConstraints = false
        center.addArrangedSubview(titleBlock)
        center.setCustomSpacing(8, after: titleBlock)

        let teamHint = UILabel()
        teamHint.attributedText = NSAttributedString(
            string: "Partners sit opposite — Team A (seats 1 & 3) vs Team B (seats 2 & 4)",
            attributes: [.font: MPFont.ui(12, weight: .medium), .foregroundColor: MPTheme.muted])
        teamHint.numberOfLines = 0
        teamHint.textAlignment = .center
        center.addArrangedSubview(teamHint)
        center.setCustomSpacing(18, after: teamHint)

        for seat in 0..<4 {
            center.addArrangedSubview(makeSeatRow(seat: seat))
        }

        center.setCustomSpacing(24, after: center.arrangedSubviews.last!)
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        center.addArrangedSubview(startButton)

        let preferredWidth = center.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            center.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            preferredWidth,
            center.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            center.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            center.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func makeSeatRow(seat: SeatID) -> UIView {
        let isHuman = seat < humanCount
        let row = UIView()
        row.backgroundColor = MPTheme.glass
        row.layer.cornerRadius = 14
        row.layer.borderWidth = 1
        row.layer.borderColor = MPTheme.border.cgColor
        row.translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.backgroundColor = JKMarbleView.SeatPalette.seat(seat).body
        dot.layer.cornerRadius = 9
        dot.layer.borderWidth = 1.5
        dot.layer.borderColor = JKMarbleView.SeatPalette.seat(seat).outline.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(dot)

        let eyebrow = UILabel()
        let team = JKTeam.of(seat: seat) == .a ? "TEAM A" : "TEAM B"
        eyebrow.attributedText = NSAttributedString(string: "SEAT \(seat + 1) · \(team)", attributes: [
            .kern: 1.0, .font: MPFont.ui(10, weight: .bold), .foregroundColor: MPTheme.muted,
        ])
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(eyebrow)

        let trailing: UIView
        if isHuman {
            let field = UITextField()
            field.text = "Player \(seat + 1)"
            field.placeholder = "Name"
            field.font = MPFont.ui(16, weight: .heavy)
            field.textColor = MPTheme.ink
            field.textAlignment = .right
            field.returnKeyType = .done
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
            field.delegate = self
            field.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
            nameFields[seat] = field
            trailing = field
        } else {
            let p = aiPersonality(forSeat: seat)
            let label = UILabel()
            label.text = "\(p.displayName)  ·  AI"
            label.font = MPFont.ui(15, weight: .heavy)
            label.textColor = MPTheme.muted
            label.textAlignment = .right
            trailing = label
        }
        trailing.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(trailing)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 18),
            dot.heightAnchor.constraint(equalToConstant: 18),

            eyebrow.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            eyebrow.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            trailing.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            trailing.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            trailing.leadingAnchor.constraint(greaterThanOrEqualTo: eyebrow.trailingAnchor, constant: 10),

            row.heightAnchor.constraint(equalToConstant: 58),
        ])
        return row
    }

    private func aiPersonality(forSeat seat: SeatID) -> JKPersonality {
        // AI seats are those at index >= humanCount; cycle the roster.
        let aiIndex = seat - humanCount
        let roster = JackarooSeating.aiPersonalities
        return roster[((aiIndex % roster.count) + roster.count) % roster.count]
    }

    private func trimmedName(forSeat seat: SeatID) -> String {
        (nameFields[seat]?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @objc private func nameChanged() { validate() }

    private func validate() {
        let allNamed = (0..<humanCount).allSatisfy { !trimmedName(forSeat: $0).isEmpty }
        startButton.isEnabled = allNamed
    }

    // MARK: - Actions

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        navigationController?.popViewController(animated: true)
    }

    @objc private func startTapped() {
        view.endEditing(true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        var players: [JKPlayer] = []
        for seat in 0..<4 {
            if seat < humanCount {
                let name = trimmedName(forSeat: seat).isEmpty ? "Player \(seat + 1)" : trimmedName(forSeat: seat)
                players.append(JKPlayer(seat: seat, name: name, kind: .human))
            } else {
                let p = aiPersonality(forSeat: seat)
                players.append(JKPlayer(seat: seat, name: p.displayName, kind: .ai(personality: p)))
            }
        }
        let game = JackarooGameViewController(players: players,
                                             seed: UInt64.random(in: 1...UInt64.max))
        game.modalPresentationStyle = .fullScreen
        navigationController?.pushViewController(game, animated: true)
    }
}

extension JackarooLobbyViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
