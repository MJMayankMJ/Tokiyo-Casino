//
//  JackarooEntryViewController.swift
//  Tokiyo Casino — Jackaroo
//
//  Phase 1 entry point. The board UI lands in Phase 2; for now this
//  screen exercises the deterministic engine so the home-tile is
//  end-to-end functional and we can validate the rules layer from
//  inside the running app.
//
//  Replaces the old Coino flip game.
//

import UIKit

final class JackarooEntryViewController: UIViewController {

    // MARK: - Subviews

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let titleBlock = MPTitleView(
        eyebrow: "Coming Soon",
        title: "Jackaroo",
        subtitle: "Engine is ready — board UI is next"
    )
    private let logView = UITextView()
    private let runButton = MPPrimaryButton(title: "Run a deterministic game")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    // MARK: - Setup

    private func setupUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBlock)

        // Log surface — glass card.
        logView.translatesAutoresizingMaskIntoConstraints = false
        logView.isEditable = false
        logView.backgroundColor = MPTheme.glassWeak
        logView.layer.cornerRadius = 16
        logView.layer.borderWidth = 1
        logView.layer.borderColor = MPTheme.border.cgColor
        logView.font = MPFont.uiTabular(11, weight: .regular)
        logView.textColor = MPTheme.ink
        logView.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        logView.text = "Tap below to run a 4-AI Jackaroo game using seed 0xC0FFEE.\n\nThe stub AI picks the first legal move every turn. Replay determinism is enforced — the log below should be identical every run."
        view.addSubview(logView)

        runButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(runButton)
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            titleBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            titleBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            logView.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 20),
            logView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            logView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            logView.bottomAnchor.constraint(equalTo: runButton.topAnchor, constant: -16),

            runButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            runButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            runButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Actions

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func runTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        runDeterministicGame()
    }

    // MARK: - Engine harness

    private func runDeterministicGame() {
        let players: [JKPlayer] = (0..<4).map {
            JKPlayer(seat: $0, name: "P\($0)",
                     kind: .ai(personality: .balanced))
        }
        let engine = JackarooEngine(players: players, seed: 0xC0FFEE)
        engine.start()

        var safety = 5_000
        while engine.state.winner == nil && safety > 0 {
            engine.stepAIIfNeeded()
            safety -= 1
        }

        let s = engine.state
        let winner = s.winner.map { "Team \($0 == .a ? "A" : "B")" } ?? "(no winner — stopped at safety cap)"
        let safeCount = s.marbles.filter {
            if case .safe = $0.position { return true }
            return false
        }.count

        var lines: [String] = []
        lines.append("Result: \(winner)")
        lines.append("Hands dealt: \(s.handsDealt)")
        lines.append("Total log events: \(s.log.count)")
        lines.append("Safe marbles: \(safeCount) / 16")
        lines.append("Fire pile: \(s.firePile.count)   Deck: \(s.deck.count)")
        lines.append("Handoff engaged: \(s.handoffEngaged)")
        lines.append("")
        lines.append("Last 20 events:")
        for evt in s.log.suffix(20) {
            lines.append("  \(formatEvent(evt))")
        }
        logView.text = lines.joined(separator: "\n")
    }

    private func formatEvent(_ e: JKGameLog.Event) -> String {
        switch e {
        case .dealStart(let dealer, let n):
            return "deal dealer=\(dealer) cards=\(n)"
        case .played(let seat, let move):
            return "P\(seat) plays \(formatMove(move))"
        case .marbleMoved(let id, _, let to, _):
            return "    marble \(id) → \(formatPosition(to))"
        case .captured(let id, let by):
            return "    P\(by) captured marble \(id)"
        case .swapped(let a, let b, let by):
            return "    P\(by) swapped \(a) ↔ \(b)"
        case .redQueenResolved(let v, let c):
            return "    red-queen victim=P\(v) lost \(c.debugDescription)"
        case .handoffEngaged(let s):
            return "*** P\(s) handoff engaged"
        case .burned(let s, let cards):
            return "P\(s) burned \(cards.map { $0.debugDescription }.joined(separator: " "))"
        case .reshuffled:
            return "(deck reshuffled)"
        case .gameOver(let w):
            return "*** game over — Team \(w == .a ? "A" : "B") wins"
        }
    }

    private func formatMove(_ m: JKMove) -> String {
        switch m {
        case .fieldFromHome(let c, let id):   return "\(c.debugDescription) field marble \(id)"
        case .forward(let c, let id, let s):  return "\(c.debugDescription) fwd \(s) on marble \(id)"
        case .backward(let c, let id, let s): return "\(c.debugDescription) bwd \(s) on marble \(id)"
        case .anyMarble5(let c, let id, _):   return "\(c.debugDescription) any-fwd-5 on marble \(id)"
        case .kingThirteen(let c, let id):    return "\(c.debugDescription) king-13 on marble \(id)"
        case .split7(_, let allocs):
            let parts = allocs.map { "(m\($0.marble):\($0.steps))" }.joined(separator: "+")
            return "7 split \(parts)"
        case .swap(_, let a, let b):          return "Jack swap \(a) ↔ \(b)"
        case .redQueenDiscard(_, let v):      return "RedQ on P\(v)"
        case .burnHand(let cards):            return "burn \(cards.count) cards"
        case .burnCard(let c):                return "burn 1 card \(c.debugDescription)"
        }
    }

    private func formatPosition(_ p: JKPosition) -> String {
        switch p {
        case .home(let slot):     return "home[\(slot)]"
        case .track(let cell):    return "track[\(cell)]"
        case .safe(let lane):     return "safe[\(lane)]"
        }
    }
}
