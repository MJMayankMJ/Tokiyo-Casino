//
//  TDPKhichaiUITests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  Drives the real `TDPGameViewController` through the khichai screen for
//  all three roles. The redaction tests prove the *payload* is clean; these
//  prove the screen built from it doesn't put a hidden card on display.
//

import XCTest
@testable import Tokiyo_Casino

// MARK: - Fake driver

/// Feeds the table a hand-built view. `TDPGameDriver` being a protocol is
/// what makes this possible without touching production code.
private final class FakeDriver: TDPGameDriver {
    var currentView: TDPClientView?
    var activeSeat: TDPSeat = 0
    var isSharedDevice = false
    var onViewChanged: ((TDPClientView) -> Void)?
    var onRejected: ((String) -> Void)?
    var onEnded: ((String) -> Void)?
    private(set) var sent: [TDPIntent] = []

    func send(_ intent: TDPIntent) { sent.append(intent) }
    func start() {}
    func stop() {}

    func push(_ view: TDPClientView) {
        currentView = view
        onViewChanged?(view)
    }
}

final class TDPKhichaiUITests: XCTestCase {

    // MARK: Fixtures

    private func hands() -> (creditor: [Card], debtor: [Card], observer: [Card]) {
        var rng = TDPRNG(seed: 31)
        let deck = TDPDeck.shuffled(TDPDeck.build(), rng: &rng)
        return (TDPDeck.sortHand(Array(deck[0..<10])),
                TDPDeck.sortHand(Array(deck[10..<20])),
                TDPDeck.sortHand(Array(deck[20..<30])))
    }

    private func makeView(mySeat: TDPSeat,
                          myHand: [Card],
                          khichai: TDPKhichaiView?,
                          prompt: TDPPrompt) -> TDPClientView {
        let seats = (0..<3).map { seat in
            TDPSeatView(seat: seat, name: "P\(seat)", kind: seat == mySeat ? "you" : "remote",
                        handCount: 10, tricksWon: 0, quota: 3, score: seat == 0 ? 2 : -1,
                        role: TDPRole.third.rawValue, isDealer: seat == 2,
                        isConnected: true, drawnCard: nil)
        }
        return TDPClientView(
            tableId: "t", phase: .khichai, roundNumber: 2, trickNumber: 0, targetRounds: 3,
            mySeat: mySeat, myHand: myHand, myLegalCardIDs: [], prompt: prompt,
            isMyTurn: false, myPrivateTrumpCard: nil,
            seats: seats, dealerSeat: 2, trump: .spades, trumpMethod: .choose,
            revealedTrumpCard: nil, currentTrick: [], leadSuit: nil,
            currentTurnSeat: nil, leaderSeat: nil, lastTrick: [], lastTrickWinnerSeat: nil,
            debts: [TDPDebt(from: 1, to: 0, amount: 1)],
            khichai: khichai, roundHistory: [], canEndSession: false, isHost: true,
            message: "Pulling."
        )
    }

    private func mount(_ driver: FakeDriver) -> TDPGameViewController {
        let controller = TDPGameViewController(driver: driver)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        controller.view.layoutIfNeeded()
        return controller
    }

    // MARK: Hierarchy helpers

    private func cardButtons(in root: UIView) -> [TDPCardButton] {
        var found: [TDPCardButton] = []
        for subview in root.subviews {
            if let button = subview as? TDPCardButton { found.append(button) }
            found.append(contentsOf: cardButtons(in: subview))
        }
        return found
    }

    private func labelTexts(in root: UIView) -> [String] {
        var found: [String] = []
        for subview in root.subviews {
            if let label = subview as? UILabel, let text = label.text { found.append(text) }
            found.append(contentsOf: labelTexts(in: subview))
        }
        return found
    }

    // MARK: Tests

    func testCreditorSeesAFaceDownFanBeforeDrawing() {
        let (creditor, _, _) = hands()
        let driver = FakeDriver()
        let controller = mount(driver)

        driver.push(makeView(
            mySeat: 0, myHand: creditor,
            khichai: TDPKhichaiView(creditorSeat: 0, debtorSeat: 1, fanCount: 10,
                                    iAmCreditor: true, iAmDebtor: false,
                                    drawnCard: nil, legalReturnIDs: nil),
            prompt: .khichaiDraw
        ))
        controller.view.layoutIfNeeded()

        // The strip shows the debtor's fan, not the creditor's own hand.
        let buttons = cardButtons(in: controller.view)
        XCTAssertEqual(buttons.count, 10, "Ten face-down cards to pick from")
        XCTAssertTrue(buttons.allSatisfy { $0.card == nil },
                      "No card identity may be attached to a fan position")

        // And none of the creditor's own cards are on screen either.
        XCTAssertTrue(labelTexts(in: controller.view).contains { $0.contains("Pull a card") })
    }

    func testCreditorPicksAFanPositionNotACard() {
        let (creditor, _, _) = hands()
        let driver = FakeDriver()
        let controller = mount(driver)
        driver.push(makeView(
            mySeat: 0, myHand: creditor,
            khichai: TDPKhichaiView(creditorSeat: 0, debtorSeat: 1, fanCount: 10,
                                    iAmCreditor: true, iAmDebtor: false,
                                    drawnCard: nil, legalReturnIDs: nil),
            prompt: .khichaiDraw
        ))
        controller.view.layoutIfNeeded()

        let buttons = cardButtons(in: controller.view)
        buttons[4].sendActions(for: .touchUpInside)

        XCTAssertEqual(driver.sent.count, 1)
        XCTAssertEqual(driver.sent.first?.kind, .khichaiDraw)
        XCTAssertEqual(driver.sent.first?.fanIndex, 4, "The intent carries a position")
        XCTAssertNil(driver.sent.first?.cardID, "…and never a card id")
    }

    func testCreditorAfterDrawingCanReturnAnyCardIncludingTheDrawnOne() {
        let (creditorBase, debtor, _) = hands()
        let drawn = debtor[0]
        let creditor = TDPDeck.sortHand(creditorBase + [drawn])   // holding 11
        let legal = TDPKhichai.legalReturns(hand: creditor, drawn: drawn)

        let driver = FakeDriver()
        let controller = mount(driver)
        driver.push(makeView(
            mySeat: 0, myHand: creditor,
            khichai: TDPKhichaiView(creditorSeat: 0, debtorSeat: 1, fanCount: 9,
                                    iAmCreditor: true, iAmDebtor: false,
                                    drawnCard: drawn, legalReturnIDs: legal.map(\.tdpID)),
            prompt: .khichaiReturn
        ))
        controller.view.layoutIfNeeded()

        let buttons = cardButtons(in: controller.view)
        XCTAssertEqual(buttons.count, 11, "The creditor sees their own 11 cards now")

        let enabled = buttons.filter { $0.isEnabled }.compactMap { $0.card?.tdpID }
        XCTAssertEqual(Set(enabled), Set(creditor.map(\.tdpID)), "Every card can go back")

        // The pulled card stays marked, so you can see which one you got…
        let pulled = try! XCTUnwrap(buttons.first { $0.card?.tdpID == drawn.tdpID })
        XCTAssertNotNil(pulled.ringColor, "The drawn card keeps its outline")
        XCTAssertTrue(buttons.filter { $0.card?.tdpID != drawn.tdpID }.allSatisfy { $0.ringColor == nil },
                      "…and it is the only one outlined")

        // …and it can be handed straight back: select, then confirm.
        pulled.sendActions(for: .touchUpInside)
        controller.view.layoutIfNeeded()
        let confirm = controller.view.recursiveButtons()
            .first { ($0.title(for: .normal) ?? "").hasPrefix("Confirm") }
        XCTAssertNotNil(confirm, "A confirm control appears once a card is chosen")
        confirm?.sendActions(for: .touchUpInside)

        let decision = driver.sent.last
        XCTAssertEqual(decision?.kind, .khichaiReturn)
        XCTAssertEqual(decision?.cardID, drawn.tdpID)
    }

    func testDebtorAndObserverNeverSeeTheDrawnCard() {
        let (_, debtor, observer) = hands()
        let drawn = debtor[0]
        // The host has already moved the drawn card out of the debtor's
        // hand by this point; the observer holds unrelated cards.
        let debtorRemaining = debtor.filter { $0.tdpID != drawn.tdpID }

        for (seat, label) in [(1, "debtor"), (2, "observer")] {
            let driver = FakeDriver()
            driver.activeSeat = seat
            let controller = mount(driver)
            // Exactly what the host would send them: seats and counts only.
            driver.push(makeView(
                mySeat: seat,
                myHand: seat == 1 ? debtorRemaining : observer,
                khichai: TDPKhichaiView(creditorSeat: 0, debtorSeat: 1, fanCount: 9,
                                        iAmCreditor: false, iAmDebtor: seat == 1,
                                        drawnCard: nil, legalReturnIDs: nil),
                prompt: .none
            ))
            controller.view.layoutIfNeeded()

            let onScreen = cardButtons(in: controller.view).compactMap { $0.card?.tdpID }
            XCTAssertFalse(onScreen.contains(drawn.tdpID),
                           "The \(label) must not see the pulled card")
            XCTAssertFalse(labelTexts(in: controller.view).contains { $0.contains(drawn.description) },
                           "…and it must not appear in any label either")
        }
    }
}

private extension UIView {
    func recursiveButtons() -> [UIButton] {
        var found: [UIButton] = []
        for subview in subviews {
            if let button = subview as? UIButton { found.append(button) }
            found.append(contentsOf: subview.recursiveButtons())
        }
        return found
    }
}
