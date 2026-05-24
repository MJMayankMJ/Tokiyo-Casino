//
//  JKBoardView.swift
//  Tokiyo Casino — Jackaroo
//
//  Octagonal felt board with an inset rhombus-style track, short
//  inward safe branches, and 2×2 Home clusters centered outside each
//  player's side. Marbles + the centre Card/Fire piles sit on top.
//
//  Geometry comes from `JKBoardLayout`. Engine state never changes
//  during layout — we just project positions through the layout.
//

import UIKit

final class JKBoardView: UIView {

    // MARK: - Config

    let graph: JKBoardGraph

    var onTrackCellTapped: ((CellID) -> Void)?
    var onSafeCellTapped: ((SeatID, Int) -> Void)?
    var onCenterTapped: (() -> Void)?

    // MARK: - Visual children

    private let feltLayer = CAShapeLayer()
    private let brassEdgeLayer = CAShapeLayer()
    private var trackCellViews: [JKTrackCellView] = []
    private var safeCellViews: [[JKTrackCellView]] = Array(repeating: [], count: 4)
    private var homeCellViews: [[JKTrackCellView]] = Array(repeating: [], count: 4)
    private var marbleViews: [MarbleID: JKMarbleView] = [:]

    private let centerCardBack = UIView()
    private let centerFireCard = UIView()
    private let centerFireLabel = UILabel()

    // MARK: - Init

    init(graph: JKBoardGraph) {
        self.graph = graph
        super.init(frame: .zero)
        backgroundColor = .clear
        clipsToBounds = false

        layer.addSublayer(feltLayer)
        layer.addSublayer(brassEdgeLayer)

        buildTrackCells()
        buildSafeCells()
        buildHomeCells()
        buildMarbleViews()
        buildCenter()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    // MARK: - Building

    private func buildTrackCells() {
        trackCellViews.removeAll()
        for cellID in 0..<graph.trackCells.count {
            let kind: JKTrackCellView.Kind
            switch graph.trackCells[cellID] {
            case .base(let owner):  kind = .base(owner: owner)
            case .safeGate, .track: kind = .track
            case .safe, .home:      kind = .track
            }
            let cell = JKTrackCellView(kind: kind)
            addSubview(cell)
            trackCellViews.append(cell)
        }
    }

    private func buildSafeCells() {
        for seat in 0..<4 {
            var row: [JKTrackCellView] = []
            for _ in 0..<4 {
                let cell = JKTrackCellView(kind: .safe(owner: seat))
                addSubview(cell)
                row.append(cell)
            }
            safeCellViews[seat] = row
        }
    }

    private func buildHomeCells() {
        for seat in 0..<4 {
            var row: [JKTrackCellView] = []
            for _ in 0..<4 {
                let cell = JKTrackCellView(kind: .home)
                addSubview(cell)
                row.append(cell)
            }
            homeCellViews[seat] = row
        }
    }

    private func buildMarbleViews() {
        for seat in 0..<4 {
            for slot in 0..<4 {
                let id = seat * 4 + slot
                let m = JKMarbleView(seat: seat)
                addSubview(m)
                marbleViews[id] = m
            }
        }
    }

    private func buildCenter() {
        centerCardBack.backgroundColor = MPTheme.cardBackBg
        centerCardBack.layer.cornerRadius = 8
        centerCardBack.layer.borderWidth = 2
        centerCardBack.layer.borderColor = MPTheme.cardBack.withAlphaComponent(0.7).cgColor
        addSubview(centerCardBack)

        centerFireCard.backgroundColor = .white
        centerFireCard.layer.cornerRadius = 8
        centerFireCard.layer.borderWidth = 1
        centerFireCard.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        centerFireCard.layer.shadowColor = UIColor.black.cgColor
        centerFireCard.layer.shadowOpacity = 0.15
        centerFireCard.layer.shadowOffset = CGSize(width: 0, height: 1)
        centerFireCard.layer.shadowRadius = 2
        addSubview(centerFireCard)

        centerFireLabel.textAlignment = .center
        centerFireLabel.adjustsFontSizeToFitWidth = true
        centerFireLabel.minimumScaleFactor = 0.3
        centerFireLabel.font = MPFont.display(40, weight: .bold)
        centerFireLabel.translatesAutoresizingMaskIntoConstraints = false
        centerFireCard.addSubview(centerFireLabel)
        NSLayoutConstraint.activate([
            centerFireLabel.centerXAnchor.constraint(equalTo: centerFireCard.centerXAnchor),
            centerFireLabel.centerYAnchor.constraint(equalTo: centerFireCard.centerYAnchor),
            centerFireLabel.widthAnchor.constraint(lessThanOrEqualTo: centerFireCard.widthAnchor,
                                                   multiplier: 0.85),
        ])
    }

    private func applyTheme() {
        feltLayer.fillColor = MPTheme.felt.resolvedColor(with: traitCollection).cgColor
        brassEdgeLayer.strokeColor = UIColor(red: 0.85, green: 0.66, blue: 0.30,
                                             alpha: 0.85).cgColor
        brassEdgeLayer.fillColor = UIColor.clear.cgColor
        brassEdgeLayer.lineWidth = 2
    }

    // MARK: - Layout

    private var lastLayout: JKBoardLayout?

    override func layoutSubviews() {
        super.layoutSubviews()

        let layout = JKBoardLayout(frame: bounds,
                                    cellsPerQuadrant: graph.cellsPerQuadrant)
        lastLayout = layout

        // Octagonal felt + brass outline.
        let path = UIBezierPath()
        for (i, v) in layout.octagonVertices.enumerated() {
            if i == 0 { path.move(to: v) } else { path.addLine(to: v) }
        }
        path.close()
        feltLayer.path = path.cgPath
        brassEdgeLayer.path = path.cgPath

        // Drop a subtle inner stroke shadow on the felt via the brass.
        feltLayer.shadowColor = UIColor.black.cgColor
        feltLayer.shadowOpacity = 0.06
        feltLayer.shadowRadius = 6
        feltLayer.shadowOffset = CGSize(width: 0, height: 2)

        // Cells.
        for cellID in 0..<trackCellViews.count {
            placeCell(trackCellViews[cellID],
                      at: layout.trackCentres[cellID],
                      size: layout.cellSize)
        }
        for seat in 0..<4 {
            for li in 0..<4 {
                placeCell(safeCellViews[seat][li],
                          at: layout.safeCentres[seat][li],
                          size: layout.cellSize)
            }
            for slot in 0..<4 {
                placeCell(homeCellViews[seat][slot],
                          at: layout.homeCentres[seat][slot],
                          size: layout.cellSize)
            }
        }

        // Centre pile — two cards side-by-side once a Fire pile exists.
        // Before the first discard, keep the deck large and centered so
        // the middle reads as the board's card area, not an offset stub.
        let cr = layout.centerRect
        let gap = cr.width * 0.04
        let hasFireCard = !centerFireCard.isHidden
        let cardW: CGFloat
        let cardH: CGFloat
        if hasFireCard {
            cardW = (cr.width - gap) / 2
            cardH = min(cr.height, cardW / 0.7)
            centerCardBack.frame = CGRect(
                x: cr.midX - cardW - gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW, height: cardH
            )
            centerFireCard.frame = CGRect(
                x: cr.midX + gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW, height: cardH
            )
        } else {
            cardW = min(cr.width * 0.64, cr.height * 0.70)
            cardH = min(cr.height, cardW / 0.7)
            centerCardBack.frame = CGRect(
                x: cr.midX - cardW / 2,
                y: cr.midY - cardH / 2,
                width: cardW, height: cardH
            )
            centerFireCard.frame = CGRect(
                x: cr.midX + gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW, height: cardH
            )
        }
        let cornerRadius = min(cardW, cardH) * 0.10
        centerCardBack.layer.cornerRadius = cornerRadius
        centerFireCard.layer.cornerRadius = cornerRadius
    }

    private func placeCell(_ view: UIView, at centre: CGPoint, size: CGFloat) {
        view.bounds = CGRect(x: 0, y: 0, width: size, height: size)
        view.center = centre
    }

    // MARK: - Marble layout

    func snapMarbles(from state: JKGameState) {
        guard let layout = lastLayout ?? buildLayoutForNow() else { return }
        let marbleSize = layout.cellSize * 1.45
        for m in state.marbles {
            guard let view = marbleViews[m.id] else { continue }
            guard let centre = layout.point(for: m.position, owner: m.owner) else { continue }
            view.bounds = CGRect(x: 0, y: 0, width: marbleSize, height: marbleSize)
            view.center = centre
            bringSubviewToFront(view)
        }
    }

    /// Walk a marble through a path of track cells, then to a final
    /// position (which may be a Safe cell or stay on the track).
    func animateMove(marble id: MarbleID,
                     from: JKPosition,
                     to: JKPosition,
                     via cells: [CellID],
                     owner: SeatID,
                     stepDuration: TimeInterval = 0.12,
                     completion: (() -> Void)? = nil) {
        guard let view = marbleViews[id],
              let layout = lastLayout ?? buildLayoutForNow() else {
            completion?(); return
        }
        var stops: [CGPoint] = []
        for cell in cells {
            if let p = layout.point(forTrack: cell) { stops.append(p) }
        }
        if let finalP = layout.point(for: to, owner: owner) {
            stops.append(finalP)
        }
        guard !stops.isEmpty else { completion?(); return }
        bringSubviewToFront(view)
        animateThrough(view: view, stops: stops,
                       stepDuration: stepDuration, completion: completion)
    }

    private func animateThrough(view: UIView,
                                stops: [CGPoint],
                                stepDuration: TimeInterval,
                                completion: (() -> Void)?) {
        guard let first = stops.first else { completion?(); return }
        UIView.animate(withDuration: stepDuration, delay: 0,
                       options: .curveEaseInOut, animations: {
            view.center = first
        }, completion: { _ in
            let rest = Array(stops.dropFirst())
            if rest.isEmpty { completion?() }
            else {
                self.animateThrough(view: view, stops: rest,
                                    stepDuration: stepDuration,
                                    completion: completion)
            }
        })
    }

    private func buildLayoutForNow() -> JKBoardLayout? {
        guard bounds.width > 0 else { return nil }
        return JKBoardLayout(frame: bounds, cellsPerQuadrant: graph.cellsPerQuadrant)
    }

    // MARK: - Highlights

    func setActiveMarble(_ id: MarbleID?) {
        for (mid, view) in marbleViews { view.isActive = (mid == id) }
    }

    func setSelectedMarble(_ id: MarbleID?) {
        for (mid, view) in marbleViews { view.isSelected = (mid == id) }
    }

    func highlightLegalTargets(trackCells: Set<CellID>,
                               safeCells: [SeatID: Set<Int>]) {
        for (idx, cell) in trackCellViews.enumerated() {
            cell.highlight = trackCells.contains(idx) ? .legalTarget : .none
        }
        for seat in 0..<4 {
            let safes = safeCells[seat] ?? []
            for (li, cell) in safeCellViews[seat].enumerated() {
                cell.highlight = safes.contains(li) ? .legalTarget : .none
            }
        }
    }

    func clearHighlights() {
        highlightLegalTargets(trackCells: [], safeCells: [:])
    }

    // MARK: - Centre fire-pile

    func setFirePileTop(_ card: JKCard?) {
        if let c = card {
            let red = (c.suit == .hearts || c.suit == .diamonds)
            centerFireLabel.textColor = red
                ? UIColor(red: 0.84, green: 0.24, blue: 0.27, alpha: 1)
                : UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
            centerFireLabel.text = c.debugDescription
            centerFireCard.isHidden = false
        } else {
            centerFireCard.isHidden = true
        }
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        let p = gr.location(in: self)
        if centerCardBack.frame.union(centerFireCard.frame).contains(p) {
            onCenterTapped?(); return
        }
        for (idx, cell) in trackCellViews.enumerated() {
            if cell.frame.insetBy(dx: -4, dy: -4).contains(p) {
                onTrackCellTapped?(idx); return
            }
        }
        for seat in 0..<4 {
            for (li, cell) in safeCellViews[seat].enumerated() {
                if cell.frame.insetBy(dx: -4, dy: -4).contains(p) {
                    onSafeCellTapped?(seat, li); return
                }
            }
        }
    }
}
