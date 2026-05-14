//
//  GameViewControllerSummary.swift
//  Poker
//
//  Round-end + session-end presentation. Each winner notification is
//  coalesced so multiple side pots produce a single banner; the banner
//  highlights the winning cards, animates the pot to the winner, and then
//  auto-starts the next hand — unless the session is over, in which case
//  the session-result sheet is presented instead.
//

import UIKit

extension GameViewController {

    @objc func showDelayedWinnerAlert(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let player = userInfo["player"] as? Player,
              let amount = userInfo["amount"] as? Int,
              let handDescription = userInfo["handDescription"] as? String else {
            return
        }

        handWinners.append((player: player, amount: amount, handDescription: handDescription))

        // Coalesce: cancel any pending presentation and re-schedule so multiple
        // side-pot notifications collapse into one banner.
        pendingResultWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.presentRoundResult()
        }
        pendingResultWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - Round result moment
    func presentRoundResult() {
        pendingResultWork = nil
        guard !handWinners.isEmpty else { return }
        guard let gm = gameManager else { return }

        // Evaluate every non-folded player so we can describe losing hands in
        // the details sheet and decide which cards to highlight.
        var evaluations: [Int: HandEvaluation] = [:]
        for p in gm.players where !p.isFolded && p.holeCards.count == 2 {
            let allCards = p.holeCards + gm.communityCards
            evaluations[p.id] = HandEvaluator.evaluateBestHand(from: allCards)
        }

        // Build per-player summary for the details sheet.
        let winnerIds = Set(handWinners.map { $0.player.id })
        let amountById: [Int: Int] = handWinners.reduce(into: [:]) { dict, info in
            dict[info.player.id, default: 0] += info.amount
        }
        let descById: [Int: String] = handWinners.reduce(into: [:]) { dict, info in
            // First winner notification per player wins (main hand description).
            if dict[info.player.id] == nil { dict[info.player.id] = info.handDescription }
        }

        var summaries: [PlayerSummary] = []
        for player in gm.players {
            let category: PlayerSummary.PlayerCategory
            var handDesc: String?
            var winningCards: [Card] = []

            if winnerIds.contains(player.id) {
                category = .winner
                handDesc = descById[player.id]
                winningCards = evaluations[player.id]?.cards ?? []
            } else if player.isFolded {
                category = .folded
            } else {
                category = .lost
                handDesc = evaluations[player.id]?.description
            }
            summaries.append(PlayerSummary(
                playerId: player.id,
                playerName: player.name,
                isHuman: player.isHuman,
                holeCards: player.holeCards,          // snapshot — Card is a value type
                chipsAfter: player.chips,             // chips at end-of-hand
                handDescription: handDesc,
                category: category,
                winningCards: winningCards,
                amountWon: amountById[player.id] ?? 0
            ))
        }
        lastHandSummary = LastHandSummary(
            playerSummaries: summaries,
            totalPot: handWinners.reduce(0) { $0 + $1.amount },
            communityCards: gm.communityCards
        )
        hasCompletedFirstHand = true
        refreshHandDetailsButton()

        // Highlight winning cards on the table for the main (largest) pot
        // winner — this is the hand the user is currently being shown.
        if let main = handWinners.max(by: { $0.amount < $1.amount }),
           let mainEval = evaluations[main.player.id] {
            tableView.highlightWinningCards(mainEval.cards, winnerPlayerId: main.player.id)
            tableView.showWinner(main.player)
            tableView.animatePotTo(playerId: main.player.id)
        }

        // Build banner entries. Multiple winners (side pots) → one entry per
        // winner inside a single banner.
        let multi = handWinners.count > 1
        let entries: [RoundResultBanner.Entry] = handWinners.map { info in
            let nameLead = info.player.isHuman ? "You" : info.player.name
            let amount = "$\(ChipFormatter.string(info.amount))"
            let title: String
            if multi {
                title = info.player.isHuman
                    ? "You win side pot \(amount)"
                    : "\(nameLead) wins side pot \(amount)"
            } else {
                title = info.player.isHuman
                    ? "You win \(amount)"
                    : "\(nameLead) wins \(amount)"
            }
            return RoundResultBanner.Entry(
                title: title,
                subtitle: info.handDescription,
                isHuman: info.player.isHuman
            )
        }

        // Play the existing sound effect for the human's outcome.
        playResultSound(humanWon: winnerIds.contains(gm.humanPlayer?.id ?? -1))

        isShowingRoundResult = true
        let displayDuration: TimeInterval = multi ? 3.5 : 2.8
        tableView.showRoundResultBanner(entries: entries, duration: displayDuration) { [weak self] in
            self?.finishRoundResultMoment()
        }
    }

    private func finishRoundResultMoment() {
        isShowingRoundResult = false
        handWinners = []
        tableView.clearWinningHighlights()

        if isSessionOver() {
            presentSessionResult(outcome: sessionOutcome())
        } else {
            startNewHand()
        }
    }

    // MARK: - Session end
    func isSessionOver() -> Bool {
        guard let gm = gameManager, let human = gm.humanPlayer else { return false }
        if human.chips <= 0 { return true }
        let withChips = gm.players.filter { $0.chips > 0 }.count
        return withChips < 2
    }

    func sessionOutcome() -> SessionResultViewController.Outcome {
        guard let human = gameManager?.humanPlayer else { return .cashout }
        if human.chips <= 0 { return .loss }
        let delta = human.chips - initialBuyIn
        return delta >= 0 ? .win : .loss
    }

    func presentSessionResult(outcome: SessionResultViewController.Outcome) {
        guard let gm = gameManager, let human = gm.humanPlayer else { return }
        let config = SessionResultViewController.Config(
            outcome: outcome,
            netDelta: human.chips - initialBuyIn,
            finalChips: human.chips,
            handsPlayed: human.handsPlayed,
            handsWon: human.handsWon,
            biggestPot: human.biggestPot
        )
        let vc = SessionResultViewController(config: config)
        vc.onPlayAgain = { [weak self] in
            guard let self else { return }
            // Settle the just-finished session so coin balance reflects the
            // outcome, then start a fresh game with a new buy-in.
            self.settleCoinsIfNeeded()
            self.hasSettledCoins = false
            self.hasCompletedFirstHand = false
            self.lastHandSummary = nil
            self.refreshHandDetailsButton()
            self.tableView.clearTable()
            self.setupGame()
        }
        vc.onExit = { [weak self] in
            self?.settleCoinsIfNeeded()
            self?.dismiss(animated: true)
        }
        present(vc, animated: true)
    }

    // MARK: - Sound
    private func playResultSound(humanWon: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if humanWon {
                self.winSoundManager.setupPlayer(soundName: "grand_win", soundType: .mp3)
                self.winSoundManager.play()
            } else {
                self.loseSoundManager.setupPlayer(soundName: "loose_sound", soundType: .mp3)
                self.loseSoundManager.play()
            }
        }
    }

    // MARK: - Coins settlement (Poker $ ↔︎ Tokyo Coins 1:1)
    func settleCoinsIfNeeded() {
        guard !hasSettledCoins,
              let human = gameManager?.humanPlayer else { return }

        let delta = human.chips - initialBuyIn
        hasSettledCoins = true

        if delta > 0 {
            CoinsManager.shared.addCoins(amount: Int64(delta)) { _ in }
        } else if delta < 0 {
            CoinsManager.shared.deductCoins(amount: Int64(-delta)) { _ in }
        }
    }
}
