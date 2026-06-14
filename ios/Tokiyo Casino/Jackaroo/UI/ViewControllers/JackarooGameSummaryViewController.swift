//
//  JackarooGameSummaryViewController.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  End-of-game sheet: which team won, the eight team marbles parked in
//  Safe, the MVP marble (most progress), and a play-again CTA.
//

import UIKit

final class JackarooGameSummaryViewController: UIViewController {

    private let state: JKGameState
    private let winner: JKTeam
    private let humanSeats: Set<SeatID>

    var onPlayAgain: (() -> Void)?
    var onClose: (() -> Void)?

    private let header = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    init(state: JKGameState, winner: JKTeam, humanSeats: Set<SeatID>) {
        self.state = state
        self.winner = winner
        self.humanSeats = humanSeats
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        isModalInPresentation = true   // force an explicit choice (Play again / Done)
        if let sheet = sheetPresentationController {
            if #available(iOS 16.0, *) {
                sheet.detents = [.custom(identifier: .init("jackaroo.summary")) { $0.maximumDetentValue * 0.62 }, .large()]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    private var winningSeats: [SeatID] { winner == .a ? [0, 2] : [1, 3] }
    private var humanWon: Bool { !humanSeats.isDisjoint(with: Set(winningSeats)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupChrome()
        layoutContent()
    }

    private func setupChrome() {
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let winnerNames = winningSeats.map { state.players[$0].name }.joined(separator: " & ")
        titleLabel.text = humanWon ? "You win!" : "Game over"
        titleLabel.font = MPFont.display(28, weight: .semibold)
        titleLabel.textColor = MPTheme.ink
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        subtitleLabel.text = "\(teamName(winner)) — \(winnerNames)"
        subtitleLabel.font = MPFont.ui(13, weight: .semibold)
        subtitleLabel.textColor = MPTheme.muted
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(subtitleLabel)

        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeButton.tintColor = MPTheme.ink
        closeButton.backgroundColor = MPTheme.glass
        closeButton.layer.cornerRadius = 18
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(closeButton)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            header.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: header.topAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

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
        contentStack.addArrangedSubview(makeMarblesCard())
        if let mvp = mvpMarble() {
            contentStack.addArrangedSubview(makeMVPCard(mvp))
        }

        let playAgain = MPPrimaryButton(title: "Play again")
        playAgain.addTarget(self, action: #selector(playAgainTapped), for: .touchUpInside)
        let done = MPSecondaryButton(title: "Done")
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        let cta = UIStackView(arrangedSubviews: [playAgain, done])
        cta.axis = .vertical
        cta.spacing = 10
        contentStack.addArrangedSubview(cta)
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews[contentStack.arrangedSubviews.count - 2])
    }

    private func makeMarblesCard() -> UIView {
        let card = cardContainer()
        let label = UILabel()
        label.text = "TEAM MARBLES HOME"
        label.attributedText = NSAttributedString(string: "TEAM MARBLES HOME", attributes: [
            .kern: 1.2, .font: MPFont.ui(10, weight: .bold), .foregroundColor: MPTheme.muted,
        ])
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        let dotsRow = UIStackView()
        dotsRow.axis = .horizontal
        dotsRow.spacing = 10
        dotsRow.alignment = .center
        dotsRow.translatesAutoresizingMaskIntoConstraints = false
        for seat in winningSeats {
            for _ in 0..<4 {
                dotsRow.addArrangedSubview(makeMarbleDot(seat: seat))
            }
        }
        card.addSubview(dotsRow)

        card.isAccessibilityElement = true
        card.accessibilityLabel = "All eight \(teamName(winner)) marbles are home in Safe."

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            dotsRow.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            dotsRow.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            dotsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeMVPCard(_ mvp: JKMarble) -> UIView {
        let card = cardContainer()
        let dot = makeMarbleDot(seat: mvp.owner, size: 26)
        dot.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(dot)

        let title = UILabel()
        title.attributedText = NSAttributedString(string: "MVP MARBLE", attributes: [
            .kern: 1.2, .font: MPFont.ui(10, weight: .bold), .foregroundColor: MPTheme.muted,
        ])
        title.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(title)

        let detail = UILabel()
        detail.text = "\(state.players[mvp.owner].name) brought a marble the furthest."
        detail.font = MPFont.ui(13, weight: .semibold)
        detail.textColor = MPTheme.ink
        detail.numberOfLines = 0
        detail.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(detail)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 26),
            dot.heightAnchor.constraint(equalToConstant: 26),

            title.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            detail.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func cardContainer() -> UIView {
        let card = UIView()
        card.backgroundColor = MPTheme.glass
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = MPTheme.border.cgColor
        return card
    }

    private func makeMarbleDot(seat: SeatID, size: CGFloat = 18) -> UIView {
        let dot = UIView()
        dot.backgroundColor = JKMarbleView.SeatPalette.seat(seat).body
        dot.layer.cornerRadius = size / 2
        dot.layer.borderWidth = 1.5
        dot.layer.borderColor = JKMarbleView.SeatPalette.seat(seat).outline.cgColor
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: size).isActive = true
        dot.heightAnchor.constraint(equalToConstant: size).isActive = true
        return dot
    }

    /// Most-progressed marble on the winning team. Home = 0, on track = 1,
    /// in Safe = 2 + lane depth — for a won game this surfaces the deepest
    /// parked marble.
    private func mvpMarble() -> JKMarble? {
        func score(_ m: JKMarble) -> Int {
            switch m.position {
            case .home: return 0
            case .track: return 1
            case .safe(let lane): return 2 + lane
            }
        }
        return state.marbles
            .filter { winningSeats.contains($0.owner) }
            .max { (a, b) in
                let sa = score(a), sb = score(b)
                return sa == sb ? a.id > b.id : sa < sb
            }
    }

    private func teamName(_ t: JKTeam) -> String { t == .a ? "Team A" : "Team B" }

    @objc private func playAgainTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss(animated: true) { self.onPlayAgain?() }
    }

    @objc private func doneTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss(animated: true) { self.onClose?() }
    }
}
