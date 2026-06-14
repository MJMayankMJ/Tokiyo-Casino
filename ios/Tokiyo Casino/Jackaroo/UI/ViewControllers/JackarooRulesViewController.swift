//
//  JackarooRulesViewController.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  Card-by-card rule listing for the active ruleset, presented as a
//  bottom sheet. Mirrors PokerRulesViewController's chrome + row style.
//  Built from JACKAROO_SPEC.md §3 (the default Jawaker Basic preset).
//

import UIKit

final class JackarooRulesViewController: UIViewController {

    private struct RuleRow {
        let title: String
        let detail: String
        let card: JKCard
    }

    private let preset: JKRulesPreset
    private let header = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(preset: JKRulesPreset = .jawakerBasic) {
        self.preset = preset
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom(identifier: .init("jackaroo.rules")) { $0.maximumDetentValue * 0.82 },
                    .large(),
                ]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    private var rows: [RuleRow] {
        [
            RuleRow(title: "Ace",
                    detail: "Bring a marble out of Home onto your Base, or move a marble forward 1 or 11.",
                    card: JKCard(suit: .spades, rank: .ace)),
            RuleRow(title: "King",
                    detail: "Bring a marble out of Home onto your Base.",
                    card: JKCard(suit: .clubs, rank: .king)),
            RuleRow(title: "Queen",
                    detail: "Move one marble forward 12.",
                    card: JKCard(suit: .hearts, rank: .queen)),
            RuleRow(title: "Jack",
                    detail: "Swap one of your marbles with an opponent's. Neither may be Home, on Base, or in Safe.",
                    card: JKCard(suit: .spades, rank: .jack)),
            RuleRow(title: "Seven",
                    detail: "Split 7 steps across two of your own marbles.",
                    card: JKCard(suit: .diamonds, rank: .seven)),
            RuleRow(title: "Four",
                    detail: "Move one marble backward 4.",
                    card: JKCard(suit: .clubs, rank: .four)),
            RuleRow(title: "Number cards",
                    detail: "2, 3, 5, 6, 8, 9, 10 move one marble forward by their face value.",
                    card: JKCard(suit: .hearts, rank: .six)),
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupChrome()
        layoutContent()
    }

    private func setupChrome() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.text = "Jackaroo rules"
        titleLabel.font = MPFont.ui(18, weight: .heavy)
        titleLabel.textColor = MPTheme.ink
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        subtitleLabel.text = "Jawaker Basic — card effects"
        subtitleLabel.font = MPFont.ui(12, weight: .semibold)
        subtitleLabel.textColor = MPTheme.muted
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeButton.tintColor = MPTheme.ink
        closeButton.backgroundColor = MPTheme.glass
        closeButton.layer.cornerRadius = 18
        closeButton.accessibilityLabel = "Close rules"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 10
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            header.heightAnchor.constraint(equalToConstant: 42),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func layoutContent() {
        contentStack.addArrangedSubview(makeGoalCard())
        for row in rows { contentStack.addArrangedSubview(makeRow(row)) }
        contentStack.addArrangedSubview(makeNoteCard())
    }

    private func makeGoalCard() -> UIView {
        infoCard(
            title: "How to win",
            body: "Four players, two teams — partners sit opposite. Get all four of your marbles around the track and into your Safe zone. The first team with all eight marbles home wins. Landing on a marble sends it back Home; a marble on its own Base is protected."
        )
    }

    private func makeNoteCard() -> UIView {
        infoCard(
            title: nil,
            body: "If you can't make any legal move with your whole hand, the hand is burned to the Fire Pile and play passes on."
        )
    }

    private func infoCard(title: String?, body: String) -> UIView {
        let card = UIView()
        card.backgroundColor = MPTheme.glass
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 1
        card.layer.borderColor = MPTheme.border.cgColor

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        if let title {
            let t = UILabel()
            t.text = title
            t.font = MPFont.ui(13, weight: .heavy)
            t.textColor = MPTheme.ink
            stack.addArrangedSubview(t)
        }
        let b = UILabel()
        b.text = body
        b.font = MPFont.ui(12, weight: .semibold)
        b.textColor = MPTheme.muted
        b.numberOfLines = 0
        stack.addArrangedSubview(b)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 11),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -11),
        ])
        return card
    }

    private func makeRow(_ row: RuleRow) -> UIView {
        let container = UIView()
        container.backgroundColor = MPTheme.glass
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1
        container.layer.borderColor = MPTheme.border.cgColor

        let cardView = CardView()
        cardView.style = .face
        cardView.setCard(row.card.asPokerCard, faceUp: true)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.isAccessibilityElement = false
        container.addSubview(cardView)

        let name = UILabel()
        name.text = row.title
        name.font = MPFont.ui(14, weight: .heavy)
        name.textColor = MPTheme.ink
        name.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(name)

        let detail = UILabel()
        detail.text = row.detail
        detail.font = MPFont.ui(12, weight: .semibold)
        detail.textColor = MPTheme.muted
        detail.numberOfLines = 0
        detail.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(detail)

        container.isAccessibilityElement = true
        container.accessibilityLabel = "\(row.title). \(row.detail)"

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            cardView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 38),
            cardView.heightAnchor.constraint(equalToConstant: 54),

            name.leadingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: 14),
            name.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            name.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            detail.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            detail.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3),
            detail.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        return container
    }

    @objc private func closeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true)
    }
}
