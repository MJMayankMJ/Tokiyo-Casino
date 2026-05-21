//
//  PokerRulesViewController.swift
//  Tokiyo Casino
//

import UIKit

final class PokerRulesViewController: UIViewController {

    private struct RuleHand {
        let title: String
        let detail: String
        let cards: [Card]
    }

    private let header = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let hands: [RuleHand] = [
        RuleHand(
            title: "Royal Flush",
            detail: "A K Q J 10, same suit",
            cards: [.c(.hearts, .ace), .c(.hearts, .king), .c(.hearts, .queen), .c(.hearts, .jack), .c(.hearts, .ten)]
        ),
        RuleHand(
            title: "Straight Flush",
            detail: "Five in order, same suit",
            cards: [.c(.spades, .nine), .c(.spades, .eight), .c(.spades, .seven), .c(.spades, .six), .c(.spades, .five)]
        ),
        RuleHand(
            title: "Four of a Kind",
            detail: "Four cards of one rank",
            cards: [.c(.hearts, .queen), .c(.diamonds, .queen), .c(.clubs, .queen), .c(.spades, .queen), .c(.clubs, .three)]
        ),
        RuleHand(
            title: "Full House",
            detail: "Three of a kind plus a pair",
            cards: [.c(.hearts, .ten), .c(.diamonds, .ten), .c(.clubs, .ten), .c(.spades, .four), .c(.hearts, .four)]
        ),
        RuleHand(
            title: "Flush",
            detail: "Five cards of the same suit",
            cards: [.c(.diamonds, .ace), .c(.diamonds, .jack), .c(.diamonds, .eight), .c(.diamonds, .five), .c(.diamonds, .two)]
        ),
        RuleHand(
            title: "Straight",
            detail: "Five cards in order",
            cards: [.c(.clubs, .nine), .c(.diamonds, .eight), .c(.spades, .seven), .c(.hearts, .six), .c(.clubs, .five)]
        ),
        RuleHand(
            title: "Three of a Kind",
            detail: "Three cards of one rank",
            cards: [.c(.hearts, .seven), .c(.diamonds, .seven), .c(.clubs, .seven), .c(.spades, .king), .c(.hearts, .two)]
        ),
        RuleHand(
            title: "Two Pair",
            detail: "Two different pairs",
            cards: [.c(.hearts, .jack), .c(.spades, .jack), .c(.diamonds, .four), .c(.clubs, .four), .c(.spades, .ace)]
        ),
        RuleHand(
            title: "One Pair",
            detail: "Two cards of one rank",
            cards: [.c(.hearts, .ace), .c(.clubs, .ace), .c(.diamonds, .nine), .c(.spades, .six), .c(.clubs, .three)]
        ),
        RuleHand(
            title: "High Card",
            detail: "Highest card wins",
            cards: [.c(.spades, .ace), .c(.hearts, .queen), .c(.clubs, .nine), .c(.diamonds, .six), .c(.spades, .two)]
        ),
    ]

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [
                    .custom(identifier: .init("poker.rules")) { ctx in
                        ctx.maximumDetentValue * 0.78
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

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = PokerTheme.pageBg
        setupChrome()
        layoutHands()
    }

    private func setupChrome() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.text = "Poker rules"
        titleLabel.font = .systemFont(ofSize: 18, weight: .heavy)
        titleLabel.textColor = PokerTheme.ink
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        subtitleLabel.text = "Winning order, strongest first"
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

    private func layoutHands() {
        for (index, hand) in hands.enumerated() {
            contentStack.addArrangedSubview(makeHandRow(rank: index + 1, hand: hand))
        }
    }

    private func makeHandRow(rank: Int, hand: RuleHand) -> UIView {
        let row = UIView()
        row.backgroundColor = PokerTheme.surface
        row.layer.cornerRadius = 16
        row.layer.borderWidth = 1
        row.layer.borderColor = PokerTheme.border.cgColor
        PokerTheme.applyShadowSm(row.layer)

        let number = UILabel()
        number.text = "\(rank)"
        number.font = .systemFont(ofSize: 12, weight: .heavy)
        number.textColor = PokerTheme.primaryActionText
        number.textAlignment = .center
        number.backgroundColor = PokerTheme.primaryAction
        number.layer.cornerRadius = 13
        number.layer.masksToBounds = true
        number.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(number)

        let name = UILabel()
        name.text = hand.title
        name.font = .systemFont(ofSize: 14, weight: .heavy)
        name.textColor = PokerTheme.ink
        name.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(name)

        let detail = UILabel()
        detail.text = hand.detail
        detail.font = .systemFont(ofSize: 11, weight: .semibold)
        detail.textColor = PokerTheme.muted
        detail.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(detail)

        let cardRow = UIView()
        cardRow.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(cardRow)

        let cardW: CGFloat = 30
        let cardH: CGFloat = 43
        let gap: CGFloat = 5
        for (idx, card) in hand.cards.enumerated() {
            let cardView = CardView()
            cardView.style = .face
            cardView.setCard(card, faceUp: true)
            cardView.frame = CGRect(
                x: CGFloat(idx) * (cardW + gap),
                y: 0,
                width: cardW,
                height: cardH
            )
            cardRow.addSubview(cardView)
        }

        let cardsWidth = CGFloat(hand.cards.count) * cardW + CGFloat(max(0, hand.cards.count - 1)) * gap

        NSLayoutConstraint.activate([
            number.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            number.topAnchor.constraint(equalTo: row.topAnchor, constant: 14),
            number.widthAnchor.constraint(equalToConstant: 26),
            number.heightAnchor.constraint(equalToConstant: 26),

            name.leadingAnchor.constraint(equalTo: number.trailingAnchor, constant: 10),
            name.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            name.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),

            detail.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            detail.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 3),
            detail.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -12),

            cardRow.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            cardRow.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 10),
            cardRow.widthAnchor.constraint(equalToConstant: cardsWidth),
            cardRow.heightAnchor.constraint(equalToConstant: cardH),
            cardRow.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
        ])

        return row
    }

    @objc private func closeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true)
    }
}

private extension Card {
    static func c(_ suit: Suit, _ rank: Rank) -> Card {
        Card(suit: suit, rank: rank)
    }
}
