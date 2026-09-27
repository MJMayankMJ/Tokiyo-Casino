//
//  TDPScoreViews.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Scores as a grid: players across the top, one row per round, the total
//  at the bottom. Each round shows tricks won (the points) with the swing
//  against target underneath — the number that decides who pulls from whom.
//  The same grid serves the round-end card and the full score sheet.
//

import UIKit

// MARK: - Grid

final class TDPScoreGrid: UIView {

    struct Player {
        let name: String
        let tint: TDPTheme.Tint
        let total: Int
        let leads: Bool
    }

    struct Round {
        let label: String
        /// Per player, in column order.
        let tricks: [Int]
        let deltas: [Int]
    }

    private let labelWidth: CGFloat = 34 * TDPTheme.scale

    init(players: [Player], rounds: [Round]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        stack.addArrangedSubview(row(label: nil, cells: players.map(headerCell)))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)

        for round in rounds {
            stack.addArrangedSubview(Self.rule())
            let cells = zip(round.tricks, round.deltas).map { roundCell(tricks: $0, delta: $1) }
            stack.addArrangedSubview(row(label: round.label, cells: cells))
        }

        stack.addArrangedSubview(Self.rule(strong: true))
        stack.addArrangedSubview(row(label: "Total", cells: players.map(totalCell)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Pieces

    private func row(label: String?, cells: [UIView]) -> UIView {
        let tag = UILabel()
        tag.text = label
        tag.font = TDPTheme.font(11, .medium)
        tag.textColor = TDPTheme.muted
        tag.adjustsFontSizeToFitWidth = true
        tag.minimumScaleFactor = 0.8
        tag.widthAnchor.constraint(equalToConstant: labelWidth).isActive = true

        let columns = UIStackView(arrangedSubviews: cells)
        columns.distribution = .fillEqually
        let line = UIStackView(arrangedSubviews: [tag, columns])
        line.alignment = .center
        line.isLayoutMarginsRelativeArrangement = true
        line.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        return line
    }

    private func headerCell(_ player: Player) -> UIView {
        let avatar = TDPAvatarView(side: 30, radius: 10)
        avatar.setName(player.name)
        avatar.tint = player.tint
        let name = UILabel()
        name.text = player.name
        name.font = TDPTheme.font(12, .medium)
        name.textColor = TDPTheme.inkSoft
        name.textAlignment = .center
        name.lineBreakMode = .byTruncatingTail
        let cell = UIStackView(arrangedSubviews: [avatar, name])
        cell.axis = .vertical
        cell.alignment = .center
        cell.spacing = 6
        return cell
    }

    private func roundCell(tricks: Int, delta: Int) -> UIView {
        let points = UILabel()
        points.text = "\(tricks)"
        points.font = TDPTheme.mono(16, .medium)
        points.textColor = TDPTheme.ink
        let swing = UILabel()
        swing.text = TDPFormat.signed(delta)
        swing.font = TDPTheme.mono(11, .medium)
        swing.textColor = delta > 0 ? TDPTheme.accent : (delta < 0 ? TDPTheme.warn : TDPTheme.muted)
        let cell = UIStackView(arrangedSubviews: [points, swing])
        cell.axis = .vertical
        cell.alignment = .center
        cell.spacing = 1
        return cell
    }

    private func totalCell(_ player: Player) -> UIView {
        let total = UILabel()
        total.text = "\(player.total)"
        total.font = TDPTheme.mono(22, .semibold)
        total.textColor = player.leads ? TDPTheme.accent : TDPTheme.ink
        total.textAlignment = .center
        return total
    }

    private static func rule(strong: Bool = false) -> UIView {
        let line = UIView()
        line.backgroundColor = strong ? TDPTheme.slot : TDPTheme.hairline
        line.heightAnchor.constraint(equalToConstant: strong ? 1 : 0.5).isActive = true
        return line
    }
}

// MARK: - Building from a view

extension TDPScoreGrid {

    /// You, then the player after you, then the one before — the table's
    /// left-to-right order, in the table's avatar colours.
    static func make(from view: TDPClientView, rounds: [TDPRoundScore],
                     name: (TDPSeat) -> String) -> TDPScoreGrid {
        let me = view.mySeat
        let order = [me, TDPRoles.nextSeat(me), TDPRoles.prevSeat(me)]
            .filter { seat in view.seats.contains { $0.seat == seat } }
        let tints: [TDPTheme.Tint] = [.green, .amber, .blue]
        let totals = order.map { seat in view.seats.first { $0.seat == seat }?.score ?? 0 }
        let best = totals.max() ?? 0
        // Nobody "leads" while everyone is level.
        let someoneLeads = Set(totals).count > 1

        let players = order.enumerated().map { index, seat in
            Player(name: name(seat), tint: tints[index % 3], total: totals[index],
                   leads: someoneLeads && totals[index] == best)
        }
        let lines = rounds.map { round in
            Round(label: "R\(round.round)",
                  tricks: order.map { round.tricks[String($0)] ?? 0 },
                  deltas: order.map { round.delta[String($0)] ?? 0 })
        }
        return TDPScoreGrid(players: players, rounds: lines)
    }
}

// MARK: - Score sheet

/// Opened from the menu or the score in the header. A sheet, so the table
/// stays visible behind it.
final class TDPScoresViewController: UIViewController {

    private let clientView: TDPClientView
    private let name: (TDPSeat) -> String

    init(view: TDPClientView, name: @escaping (TDPSeat) -> String) {
        self.clientView = view
        self.name = name
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page

        let title = UILabel()
        title.text = "Scores"
        title.font = TDPTheme.font(20, .semibold)
        title.textColor = TDPTheme.ink
        let played = clientView.roundHistory.count
        let subtitle = UILabel()
        subtitle.text = "\(played) of \(clientView.targetRounds) rounds"
        subtitle.font = TDPTheme.font(13)
        subtitle.textColor = TDPTheme.muted
        let heading = UIStackView(arrangedSubviews: [title, subtitle])
        heading.axis = .vertical
        heading.spacing = 2

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)),
                       for: .normal)
        close.tintColor = TDPTheme.inkSoft
        close.backgroundColor = TDPTheme.raised
        close.layer.cornerRadius = 16
        close.accessibilityLabel = "Close"
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        close.widthAnchor.constraint(equalToConstant: 32).isActive = true
        close.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let top = UIStackView(arrangedSubviews: [heading, UIView(), close])
        top.alignment = .center

        let card = UIView()
        card.backgroundColor = TDPTheme.raised
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        let grid = TDPScoreGrid.make(from: clientView, rounds: clientView.roundHistory, name: name)
        card.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            grid.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            grid.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])

        let legend = UILabel()
        legend.text = played == 0 ? "No rounds played yet" : "Tricks won · ± against target"
        legend.font = TDPTheme.font(12)
        legend.textColor = TDPTheme.muted
        legend.textAlignment = .center

        let content = UIStackView(arrangedSubviews: [top, card, legend])
        content.axis = .vertical
        content.spacing = 16
        content.setCustomSpacing(10, after: card)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        view.addSubview(scroll)

        let fill = content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
        fill.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 480),
            fill
        ])
    }

    /// Half height with a grabber; pull up for a long session.
    func presentAsSheet(from host: UIViewController) {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        host.present(self, animated: true)
    }
}
