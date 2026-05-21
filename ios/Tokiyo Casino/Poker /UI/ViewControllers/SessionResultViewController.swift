//
//  SessionResultViewController.swift
//  Tokiyo Casino
//
//  Shown only when the poker session ends (human busts, only one player has
//  chips left, or user cashes out). Different from the per-round banner.
//

import UIKit

final class SessionResultViewController: UIViewController {

    enum Outcome {
        case win, loss, cashout

        var title: String {
            switch self {
            case .win:     return "You're up"
            case .loss:    return "You busted"
            case .cashout: return "Cashed out"
            }
        }
    }

    struct Config {
        let outcome: Outcome
        let netDelta: Int   // net chips gained (negative = lost)
        let finalChips: Int
        let handsPlayed: Int
        let handsWon: Int
        let biggestPot: Int
    }

    private let config: Config
    var onPlayAgain: (() -> Void)?
    var onExit: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let deltaLabel = UILabel()
    private let statsStack = UIStackView()
    private let playAgainButton = UIButton(type: .system)
    private let exitButton = UIButton(type: .system)

    init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom(identifier: .init("session.result")) { _ in 460 },
                    .large()
                ]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PokerTheme.pageBg
        layoutContent()
    }

    private func layoutContent() {
        card.backgroundColor = PokerTheme.surface
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = PokerTheme.border.cgColor
        PokerTheme.applyShadowMd(card.layer)
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        titleLabel.text = config.outcome.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor = PokerTheme.ink
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        let isUp = config.netDelta >= 0
        let sign = isUp ? "+" : "−"
        let magnitude = abs(config.netDelta)
        deltaLabel.text = "\(sign)$\(ChipFormatter.string(magnitude))"
        deltaLabel.font = .systemFont(ofSize: 38, weight: .heavy)
        deltaLabel.textColor = isUp ? PokerTheme.forestDeep : PokerTheme.coralDeep
        deltaLabel.textAlignment = .center
        deltaLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(deltaLabel)

        statsStack.axis = .vertical
        statsStack.alignment = .fill
        statsStack.spacing = 10
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(statsStack)

        statsStack.addArrangedSubview(makeStatRow(title: "Final chips",
                                                  value: "$\(ChipFormatter.string(config.finalChips))"))
        statsStack.addArrangedSubview(makeStatRow(title: "Hands played",
                                                  value: "\(config.handsPlayed)"))
        statsStack.addArrangedSubview(makeStatRow(title: "Hands won",
                                                  value: "\(config.handsWon)"))
        if config.biggestPot > 0 {
            statsStack.addArrangedSubview(makeStatRow(title: "Biggest pot",
                                                      value: "$\(ChipFormatter.string(config.biggestPot))"))
        }

        styleSolidButton(playAgainButton, title: "Play Again",
                         background: PokerTheme.primaryAction, foreground: PokerTheme.primaryActionText)
        playAgainButton.addTarget(self, action: #selector(playAgainTapped), for: .touchUpInside)
        view.addSubview(playAgainButton)

        styleOutlineButton(exitButton, title: "Exit")
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        view.addSubview(exitButton)

        playAgainButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            deltaLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            deltaLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            deltaLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            statsStack.topAnchor.constraint(equalTo: deltaLabel.bottomAnchor, constant: 18),
            statsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            statsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            statsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),

            playAgainButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            playAgainButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            playAgainButton.bottomAnchor.constraint(equalTo: exitButton.topAnchor, constant: -10),
            playAgainButton.heightAnchor.constraint(equalToConstant: 52),

            exitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            exitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            exitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            exitButton.heightAnchor.constraint(equalToConstant: 46),
        ])
    }

    private func makeStatRow(title: String, value: String) -> UIView {
        let row = UIView()

        let t = UILabel()
        t.text = title
        t.font = .systemFont(ofSize: 13, weight: .medium)
        t.textColor = PokerTheme.muted
        t.translatesAutoresizingMaskIntoConstraints = false

        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 14, weight: .heavy)
        v.textColor = PokerTheme.ink
        v.textAlignment = .right
        v.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(t)
        row.addSubview(v)
        NSLayoutConstraint.activate([
            t.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            t.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            v.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            v.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 22),
        ])
        return row
    }

    private func styleSolidButton(_ button: UIButton, title: String,
                                  background: UIColor, foreground: UIColor) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .heavy)
        button.setTitleColor(foreground, for: .normal)
        button.backgroundColor = background
        button.layer.cornerRadius = 16
        PokerTheme.applyShadowMd(button.layer)
    }

    private func styleOutlineButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.setTitleColor(PokerTheme.ink, for: .normal)
        button.backgroundColor = PokerTheme.surface
        button.layer.cornerRadius = 14
        button.layer.borderWidth = 1
        button.layer.borderColor = PokerTheme.borderStrong.cgColor
    }

    @objc private func playAgainTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss(animated: true) { self.onPlayAgain?() }
    }

    @objc private func exitTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true) { self.onExit?() }
    }
}
