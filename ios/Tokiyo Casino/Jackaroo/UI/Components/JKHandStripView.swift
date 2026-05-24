//
//  JKHandStripView.swift
//  Tokiyo Casino — Jackaroo
//
//  Bottom-of-screen hand strip. Hosts 1…5 face-up cards (the dealCycle
//  variants reach 5), reuses Poker's `CardView` atom for rendering,
//  and surfaces selection / burn affordances.
//

import UIKit

protocol JKHandStripDelegate: AnyObject {
    func handStrip(_ strip: JKHandStripView, didSelect card: JKCard, at index: Int)
    func handStripDidTapBurn(_ strip: JKHandStripView)
}

final class JKHandStripView: UIView {

    weak var delegate: JKHandStripDelegate?

    /// Cards currently in the active human seat's hand. Sub-views are
    /// rebuilt whenever this is set.
    private(set) var cards: [JKCard] = []

    /// Index into `cards` of the lifted card, or nil.
    private(set) var selectedIndex: Int?

    /// Show the "Burn hand" CTA in place of the cards.
    var showBurnAffordance: Bool = false {
        didSet { rebuildAffordance() }
    }

    /// Disable interaction while a move is resolving / an AI is thinking.
    var isInteractive: Bool = true

    // MARK: - Subviews

    private let bg = UIView()
    private var cardViews: [CardView] = []
    private let burnButton = MPPrimaryButton(title: "Burn hand")

    // MARK: - Init

    init() {
        super.init(frame: .zero)
        bg.backgroundColor = MPTheme.glass
        bg.layer.cornerRadius = 20
        bg.layer.borderWidth = 1
        bg.layer.borderColor = MPTheme.border.cgColor
        addSubview(bg)

        burnButton.translatesAutoresizingMaskIntoConstraints = false
        burnButton.isHidden = true
        burnButton.addTarget(self, action: #selector(burnTapped), for: .touchUpInside)
        addSubview(burnButton)
        NSLayoutConstraint.activate([
            burnButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            burnButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            burnButton.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.7),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Data binding

    func setHand(_ newCards: [JKCard]) {
        cards = newCards
        selectedIndex = nil
        rebuildCardViews()
        setNeedsLayout()
    }

    func clearSelection() {
        selectedIndex = nil
        for v in cardViews { v.transform = .identity }
    }

    // MARK: - Build / layout

    private func rebuildCardViews() {
        for v in cardViews { v.removeFromSuperview() }
        cardViews.removeAll()
        for card in cards {
            let v = CardView()
            v.setCard(card.asPokerCard, faceUp: true)
            v.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
            v.addGestureRecognizer(tap)
            bg.addSubview(v)
            cardViews.append(v)
        }
    }

    private func rebuildAffordance() {
        burnButton.isHidden = !showBurnAffordance
        bg.isHidden = showBurnAffordance
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bg.frame = bounds
        guard !cardViews.isEmpty else { return }

        let usableW = bounds.width - 24
        let cardH = bounds.height - 16
        let cardW = cardH * 0.70
        let totalCardsW = CGFloat(cardViews.count) * cardW
        let gap = (usableW - totalCardsW) / CGFloat(max(1, cardViews.count - 1))
        let stride = cardW + max(8, min(gap, 20))

        // Centre the row.
        let rowW = CGFloat(cardViews.count - 1) * stride + cardW
        var x = (bounds.width - rowW) / 2
        let y = (bounds.height - cardH) / 2

        for v in cardViews {
            v.frame = CGRect(x: x, y: y, width: cardW, height: cardH)
            x += stride
        }
    }

    // MARK: - Selection

    @objc private func cardTapped(_ gr: UITapGestureRecognizer) {
        guard isInteractive, let v = gr.view as? CardView,
              let idx = cardViews.firstIndex(of: v),
              idx < cards.count else { return }

        if selectedIndex == idx {
            // Toggle off.
            UIView.animate(withDuration: 0.15) { v.transform = .identity }
            selectedIndex = nil
            return
        }

        // Reset previous selection.
        if let prev = selectedIndex, prev < cardViews.count {
            UIView.animate(withDuration: 0.15) {
                self.cardViews[prev].transform = .identity
            }
        }
        // Lift this one.
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
            v.transform = CGAffineTransform(translationX: 0, y: -10)
                .scaledBy(x: 1.06, y: 1.06)
        }
        selectedIndex = idx
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.handStrip(self, didSelect: cards[idx], at: idx)
    }

    @objc private func burnTapped() {
        guard isInteractive else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.handStripDidTapBurn(self)
    }
}
