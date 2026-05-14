//
//  GameSummaryViewController.swift
//  Poker
//
//  Hand-details sheet shown when the user taps the top-right info icon on
//  the table. Presents the last completed hand's winners, losers, folded
//  players, community cards, hole cards, and per-player best hand at ~75%
//  height. Only a close button — no game-flow buttons.
//

import UIKit

struct PlayerSummary {
    // Snapshotted — captured at the moment the hand finished so the sheet
    // keeps showing the previous hand's data even after the next hand has
    // dealt fresh hole cards / shifted stacks on the live Player.
    let playerId: Int
    let playerName: String
    let isHuman: Bool
    let holeCards: [Card]
    let chipsAfter: Int
    let handDescription: String?
    let category: PlayerCategory
    let winningCards: [Card]
    let amountWon: Int

    enum PlayerCategory {
        case winner
        case folded
        case lost
    }
}

class GameSummaryViewController: UIViewController {

    // MARK: - Properties
    private let playerSummaries: [PlayerSummary]
    private let totalPot: Int
    private let communityCards: [Card]

    private let header = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Callbacks
    var onClose: (() -> Void)?

    // MARK: - Initialization
    init(playerSummaries: [PlayerSummary], totalPot: Int, communityCards: [Card]) {
        self.playerSummaries = playerSummaries
        self.totalPot = totalPot
        self.communityCards = communityCards
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom(identifier: .init("hand.details")) { ctx in
                        ctx.maximumDetentValue * 0.75
                    },
                    .large()
                ]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PokerTheme.pageBg
        setupChrome()
        layoutContent()
    }

    // MARK: - Setup
    private func setupChrome() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.text = "Hand details"
        titleLabel.font = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = PokerTheme.ink
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        subtitleLabel.text = "Pot $\(ChipFormatter.string(totalPot))"
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        subtitleLabel.textColor = PokerTheme.muted
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeButton.tintColor = PokerTheme.ink
        closeButton.backgroundColor = PokerTheme.glass
        closeButton.layer.cornerRadius = 14
        PokerTheme.applyShadowSm(closeButton.layer)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            header.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor, constant: 2),

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
        // Community cards block
        contentStack.addArrangedSubview(makeCommunitySection())

        let winners = playerSummaries.filter { $0.category == .winner }
        let lost = playerSummaries.filter { $0.category == .lost }
        let folded = playerSummaries.filter { $0.category == .folded }

        if !winners.isEmpty {
            contentStack.addArrangedSubview(makeSectionHeader(title: "Winners",
                                                              accent: PokerTheme.amber))
            for s in winners { contentStack.addArrangedSubview(makePlayerCard(summary: s)) }
        }
        if !lost.isEmpty {
            contentStack.addArrangedSubview(makeSectionHeader(title: "Showdown",
                                                              accent: PokerTheme.muted))
            for s in lost { contentStack.addArrangedSubview(makePlayerCard(summary: s)) }
        }
        if !folded.isEmpty {
            contentStack.addArrangedSubview(makeSectionHeader(title: "Folded",
                                                              accent: PokerTheme.muted))
            for s in folded { contentStack.addArrangedSubview(makePlayerCard(summary: s)) }
        }
    }

    private func makeSectionHeader(title: String, accent: UIColor) -> UIView {
        let row = UIView()
        let dot = UIView()
        dot.backgroundColor = accent
        dot.layer.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(dot)

        let label = UILabel()
        label.text = title.uppercased()
        label.font = .systemFont(ofSize: 11, weight: .heavy)
        label.textColor = PokerTheme.muted
        label.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            label.topAnchor.constraint(equalTo: row.topAnchor),
            label.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: 18),
        ])
        return row
    }

    private func makeCommunitySection() -> UIView {
        let container = UIView()
        container.backgroundColor = PokerTheme.surface
        container.layer.cornerRadius = 16
        container.layer.borderWidth = 1
        container.layer.borderColor = PokerTheme.border.cgColor
        PokerTheme.applyShadowSm(container.layer)
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = "Board"
        header.font = .systemFont(ofSize: 12, weight: .heavy)
        header.textColor = PokerTheme.muted
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        let cardRow = UIView()
        cardRow.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(cardRow)

        // Build little card glyphs using the proper CardView for visual consistency.
        let winningPool: Set<Card> = playerSummaries
            .filter { $0.category == .winner }
            .flatMap { $0.winningCards }
            .reduce(into: Set<Card>()) { $0.insert($1) }
        let cardW: CGFloat = 38
        let cardH: CGFloat = 54
        let gap: CGFloat = 6

        for (idx, card) in communityCards.enumerated() {
            let cv = CardView()
            cv.style = .face
            cv.setCard(card, faceUp: true)
            cv.frame = CGRect(x: CGFloat(idx) * (cardW + gap), y: 0,
                              width: cardW, height: cardH)
            cv.highlightState = winningPool.contains(card) ? .winning : (winningPool.isEmpty ? .none : .unused)
            cardRow.addSubview(cv)
        }

        let rowWidth = CGFloat(max(1, communityCards.count)) * cardW
            + CGFloat(max(0, communityCards.count - 1)) * gap

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),

            cardRow.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            cardRow.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            cardRow.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            cardRow.heightAnchor.constraint(equalToConstant: cardH),
            cardRow.widthAnchor.constraint(equalToConstant: rowWidth),
        ])
        return container
    }

    private func makePlayerCard(summary: PlayerSummary) -> UIView {
        let card = UIView()
        card.backgroundColor = PokerTheme.surface
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = (summary.category == .winner ? PokerTheme.amber.withAlphaComponent(0.55)
                                                              : PokerTheme.border).cgColor
        PokerTheme.applyShadowSm(card.layer)

        let nameLabel = UILabel()
        nameLabel.text = summary.playerName
        nameLabel.font = .systemFont(ofSize: 14, weight: .heavy)
        nameLabel.textColor = PokerTheme.ink
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nameLabel)

        let handLabel = UILabel()
        if summary.category == .folded {
            handLabel.text = "Folded"
        } else if let desc = summary.handDescription {
            handLabel.text = desc
        } else {
            handLabel.text = nil
        }
        handLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        handLabel.textColor = (summary.category == .winner) ? PokerTheme.amber : PokerTheme.muted
        handLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(handLabel)

        let chipsLabel = UILabel()
        if summary.category == .winner, summary.amountWon > 0 {
            chipsLabel.text = "+$\(ChipFormatter.string(summary.amountWon)) · Stack $\(ChipFormatter.string(summary.chipsAfter))"
        } else {
            chipsLabel.text = "Stack $\(ChipFormatter.string(summary.chipsAfter))"
        }
        chipsLabel.font = .systemFont(ofSize: 11, weight: .medium)
        chipsLabel.textColor = PokerTheme.muted
        chipsLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chipsLabel)

        // Hole cards row (right side)
        let holeRow = UIView()
        holeRow.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(holeRow)

        let cardW: CGFloat = 36
        let cardH: CGFloat = 52
        let gap: CGFloat = 6
        let showHoles = !summary.holeCards.isEmpty
        if showHoles {
            for (idx, c) in summary.holeCards.enumerated() {
                let cv = CardView()
                cv.style = .face
                cv.setCard(c, faceUp: true)
                cv.frame = CGRect(x: CGFloat(idx) * (cardW + gap), y: 0,
                                  width: cardW, height: cardH)
                if summary.category == .winner {
                    cv.highlightState = summary.winningCards.contains(c) ? .winning : .unused
                } else {
                    cv.highlightState = .none
                }
                holeRow.addSubview(cv)
            }
        }
        let holeRowWidth: CGFloat = showHoles
            ? CGFloat(summary.holeCards.count) * cardW
              + CGFloat(max(0, summary.holeCards.count - 1)) * gap
            : 0

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),

            handLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            handLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),

            chipsLabel.topAnchor.constraint(equalTo: handLabel.bottomAnchor, constant: 4),
            chipsLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            chipsLabel.trailingAnchor.constraint(lessThanOrEqualTo: holeRow.leadingAnchor, constant: -10),
            chipsLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            holeRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            holeRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            holeRow.heightAnchor.constraint(equalToConstant: cardH),
            holeRow.widthAnchor.constraint(equalToConstant: max(0, holeRowWidth)),
        ])
        return card
    }

    @objc private func closeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true) { self.onClose?() }
    }
}
