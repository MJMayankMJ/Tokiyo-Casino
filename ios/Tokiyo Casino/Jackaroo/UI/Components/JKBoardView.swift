//
//  JKBoardView.swift
//  Tokiyo Casino — Jackaroo
//
//  Dark circular Jackaroo board rendered with UIKit/Core Graphics.
//  This is a clean-room visual recreation of the Kerdany-style board:
//  100 track holes, four colored sides, inward safe lanes, 2x2 homes,
//  glossy marbles, legal-target rings, and a central card area.
//

import UIKit

final class JKBoardView: UIView {

    enum HitTarget: Equatable {
        case track(CellID)
        case safe(SeatID, Int)
        case home(SeatID, Int)
        case center
    }

    // MARK: - Config

    let graph: JKBoardGraph

    var onTrackCellTapped: ((CellID) -> Void)?
    var onSafeCellTapped: ((SeatID, Int) -> Void)?
    var onCenterTapped: (() -> Void)?

    // MARK: - Visual children

    private let targetRingLayer = CALayer()
    private var marbleViews: [MarbleID: JKMarbleView] = [:]

    private let centerCardBack = UIView()
    private let centerFireCard = UIView()
    private let centerFireLabel = UILabel()

    // MARK: - State

    private var lastLayout: JKBoardLayout?
    private var lastState: JKGameState?
    private var highlightedTrackCells = Set<CellID>()
    private var highlightedSafeCells: [SeatID: Set<Int>] = [:]
    private var activeMarbleID: MarbleID?
    private var selectedMarbleID: MarbleID?

    // MARK: - Init

    init(graph: JKBoardGraph) {
        self.graph = graph
        super.init(frame: .zero)
        commonInit()
    }

    required init?(coder: NSCoder) {
        self.graph = JKBoardGraph()
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false

        layer.addSublayer(targetRingLayer)

        buildMarbleViews()
        buildCenter()

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        applyTheme()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
        setNeedsDisplay()
        updateTargetRings()
    }

    // MARK: - Building

    private func buildMarbleViews() {
        for seat in 0..<4 {
            for slot in 0..<4 {
                let id = seat * 4 + slot
                let marble = JKMarbleView(seat: seat)
                addSubview(marble)
                marbleViews[id] = marble
            }
        }
    }

    private func buildCenter() {
        centerCardBack.backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
        centerCardBack.layer.borderWidth = 1.5
        centerCardBack.layer.shadowColor = UIColor.black.cgColor
        centerCardBack.layer.shadowOpacity = 0.35
        centerCardBack.layer.shadowOffset = CGSize(width: 0, height: 2)
        centerCardBack.layer.shadowRadius = 5
        addSubview(centerCardBack)

        centerFireCard.backgroundColor = UIColor(red: 0.95, green: 0.91, blue: 0.82, alpha: 1)
        centerFireCard.layer.borderWidth = 1
        centerFireCard.layer.shadowColor = UIColor.black.cgColor
        centerFireCard.layer.shadowOpacity = 0.25
        centerFireCard.layer.shadowOffset = CGSize(width: 0, height: 2)
        centerFireCard.layer.shadowRadius = 5
        centerFireCard.isHidden = true
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
                                                   multiplier: 0.82),
        ])
    }

    private func applyTheme() {
        let gold = BoardColor.gold.resolvedColor(with: traitCollection)
        centerCardBack.layer.borderColor = gold.withAlphaComponent(0.70).cgColor
        centerFireCard.layer.borderColor = UIColor.black.withAlphaComponent(0.18).cgColor
    }

    private var usesPokerFeltSurface: Bool {
        traitCollection.userInterfaceStyle != .dark
    }

    private func resolved(_ color: UIColor) -> UIColor {
        color.resolvedColor(with: traitCollection)
    }

    private func boardGradientColors() -> [UIColor] {
        if usesPokerFeltSurface {
            return [
                resolved(PokerTheme.felt),
                resolved(PokerTheme.pageBg),
                resolved(PokerTheme.feltEdge)
            ]
        }
        return [
            resolved(BoardColor.inkCore),
            resolved(BoardColor.inkEdge)
        ]
    }

    private func boardGradientLocations() -> [CGFloat] {
        usesPokerFeltSurface ? [0.0, 0.58, 1.0] : [0.0, 1.0]
    }

    private func boardOuterStrokeColor() -> UIColor {
        usesPokerFeltSurface
            ? resolved(PokerTheme.feltEdge)
            : resolved(BoardColor.outerStroke)
    }

    private func boardInnerStrokeColor() -> UIColor {
        usesPokerFeltSurface
            ? resolved(PokerTheme.borderStrong)
            : resolved(BoardColor.gold).withAlphaComponent(10.0 / 255.0)
    }

    private func trackShadowStrokeColor() -> UIColor {
        usesPokerFeltSurface
            ? resolved(PokerTheme.feltEdge).withAlphaComponent(0.96)
            : resolved(BoardColor.trackShadow)
    }

    private func trackGrooveStrokeColor() -> UIColor {
        usesPokerFeltSurface
            ? resolved(PokerTheme.pageBg).withAlphaComponent(0.72)
            : resolved(BoardColor.trackGroove)
    }

    private func centerOrnamentFillColor() -> UIColor {
        usesPokerFeltSurface
            ? resolved(PokerTheme.feltEdge).withAlphaComponent(0.34)
            : resolved(BoardColor.inkEdge)
    }

    private func holeShadowColor() -> UIColor {
        UIColor.black.withAlphaComponent(usesPokerFeltSurface ? 0.26 : 0.56)
    }

    private func holeHaloColor() -> UIColor {
        usesPokerFeltSurface
            ? UIColor.black.withAlphaComponent(0.11)
            : UIColor.white.withAlphaComponent(0.08)
    }

    private func holeHighlightColor() -> UIColor {
        UIColor.white.withAlphaComponent(usesPokerFeltSurface ? 0.30 : 0.12)
    }

    private func visibleSeatStroke(_ seat: SeatID) -> UIColor {
        usesPokerFeltSurface ? seatStroke(seat) : seatFill(seat)
    }

    private func regularHoleFillAlpha() -> CGFloat {
        usesPokerFeltSurface ? 0.23 : 0.20
    }

    private func regularHoleStrokeAlpha() -> CGFloat {
        usesPokerFeltSurface ? 0.86 : 0.78
    }

    private func safeGuideAlpha() -> CGFloat {
        usesPokerFeltSurface ? 0.42 : 0.50
    }

    private func homeBoxStrokeAlpha() -> CGFloat {
        usesPokerFeltSurface ? 0.60 : 0.44
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let layout = JKBoardLayout(frame: bounds,
                                   cellsPerQuadrant: graph.cellsPerQuadrant)
        lastLayout = layout
        targetRingLayer.frame = bounds

        layoutCenterCards(using: layout)
        if let state = lastState {
            snapMarbles(from: state)
        }
        updateTargetRings()
        setNeedsDisplay()
    }

    private func layoutCenterCards(using layout: JKBoardLayout) {
        let cr = layout.centerRect
        let gap = max(3, cr.width * 0.05)
        let hasFireCard = !centerFireCard.isHidden
        let cardW: CGFloat
        let cardH: CGFloat

        if hasFireCard {
            cardW = (cr.width - gap) / 2
            cardH = min(cr.height * 1.04, cardW / 0.70)
            centerCardBack.frame = CGRect(
                x: cr.midX - cardW - gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW,
                height: cardH
            )
            centerFireCard.frame = CGRect(
                x: cr.midX + gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW,
                height: cardH
            )
        } else {
            cardW = min(cr.width * 0.66, cr.height * 0.74)
            cardH = min(cr.height * 1.04, cardW / 0.70)
            centerCardBack.frame = CGRect(
                x: cr.midX - cardW / 2,
                y: cr.midY - cardH / 2,
                width: cardW,
                height: cardH
            )
            centerFireCard.frame = CGRect(
                x: cr.midX + gap / 2,
                y: cr.midY - cardH / 2,
                width: cardW,
                height: cardH
            )
        }

        let cornerRadius = max(4, min(cardW, cardH) * 0.10)
        centerCardBack.layer.cornerRadius = cornerRadius
        centerFireCard.layer.cornerRadius = cornerRadius

        drawCardBackPattern()
    }

    private func drawCardBackPattern() {
        centerCardBack.layer.sublayers?
            .filter { $0.name == "deckPattern" }
            .forEach { $0.removeFromSuperlayer() }

        let bounds = centerCardBack.bounds
        guard bounds.width > 2, bounds.height > 2 else { return }
        let pattern = CAShapeLayer()
        pattern.name = "deckPattern"
        pattern.frame = bounds
        pattern.fillColor = UIColor.clear.cgColor
        pattern.strokeColor = BoardColor.gold.withAlphaComponent(0.45).cgColor
        pattern.lineWidth = max(0.6, bounds.width * 0.025)

        let inset = bounds.width * 0.20
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset),
                                cornerRadius: bounds.width * 0.08)
        let inner = UIBezierPath(ovalIn: bounds.insetBy(dx: bounds.width * 0.33,
                                                        dy: bounds.height * 0.36))
        path.append(inner)
        pattern.path = path.cgPath
        centerCardBack.layer.addSublayer(pattern)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let layout = lastLayout ?? buildLayoutForNow() else { return }

        drawBoardBackground(layout, in: ctx)
        drawQuadrantWedges(layout, in: ctx)
        drawTrackBand(layout, in: ctx)
        drawSafeGuides(layout, in: ctx)
        drawHomeBoxes(layout, in: ctx)
        drawTrackCells(layout, in: ctx)
        drawSafeCells(layout, in: ctx)
        drawCenterOrnament(layout, in: ctx)
    }

    private func drawBoardBackground(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        let outerRect = circleRect(center: layout.center, radius: layout.boardRadius)
        ctx.saveGState()
        UIBezierPath(ovalIn: outerRect).addClip()
        let colors = boardGradientColors().map(\.cgColor) as CFArray
        let locations = boardGradientLocations()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors,
                                     locations: locations) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: layout.center,
                startRadius: 0,
                endCenter: layout.center,
                endRadius: layout.boardRadius,
                options: [.drawsAfterEndLocation]
            )
        }
        ctx.restoreGState()

        let outer = UIBezierPath(ovalIn: outerRect)
        outer.lineWidth = 1.5 * scale
        boardOuterStrokeColor().setStroke()
        outer.stroke()

        let inner = UIBezierPath(ovalIn: circleRect(center: layout.center,
                                                    radius: 383 * scale))
        inner.lineWidth = 0.8 * scale
        boardInnerStrokeColor().setStroke()
        inner.stroke()
    }

    private func drawQuadrantWedges(_ layout: JKBoardLayout, in ctx: CGContext) {
        let wedgeRadius = layout.trackRadius + layout.cellRadius + 20 * layout.svgScale

        for seat in 0..<4 {
            let startAngle = (CGFloat(seat) * 25 / 100) * 2 * CGFloat.pi - CGFloat.pi / 2
            let endAngle = (CGFloat(seat + 1) * 25 / 100) * 2 * CGFloat.pi - CGFloat.pi / 2
            let path = UIBezierPath()
            path.move(to: layout.center)
            path.addArc(withCenter: layout.center,
                        radius: wedgeRadius,
                        startAngle: startAngle,
                        endAngle: endAngle,
                        clockwise: true)
            path.close()
            seatFill(seat).withAlphaComponent(10.0 / 255.0).setFill()
            path.fill()
        }
    }

    private func drawTrackBand(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        let bandRect = CGRect(
            x: layout.center.x - layout.trackRadius,
            y: layout.center.y - layout.trackRadius,
            width: layout.trackRadius * 2,
            height: layout.trackRadius * 2
        )
        let shadow = UIBezierPath(ovalIn: bandRect)
        shadow.lineWidth = 38 * scale
        trackShadowStrokeColor().setStroke()
        shadow.stroke()

        let groove = UIBezierPath(ovalIn: bandRect)
        groove.lineWidth = 30 * scale
        trackGrooveStrokeColor().setStroke()
        groove.stroke()
    }

    private func drawSafeGuides(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        for seat in 0..<4 {
            let safePath = UIBezierPath()
            if let first = layout.safeCentres[seat].first {
                safePath.move(to: first)
            }
            for point in layout.safeCentres[seat].dropFirst() {
                safePath.addLine(to: point)
            }
            safePath.lineWidth = 2 * scale
            safePath.lineCapStyle = .round
            visibleSeatStroke(seat).withAlphaComponent(safeGuideAlpha()).setStroke()
            safePath.stroke()

            guard let gate = graph.safeGateCell[seat],
                  let gatePoint = layout.point(forTrack: gate),
                  let first = layout.safeCentres[seat].first else { continue }
            let entry = UIBezierPath()
            entry.move(to: gatePoint)
            entry.addLine(to: first)
            entry.lineWidth = 1 * scale
            entry.lineCapStyle = .round
            let dash = [4 * scale, 3 * scale]
            dash.withUnsafeBufferPointer {
                entry.setLineDash($0.baseAddress, count: dash.count, phase: 0)
            }
            visibleSeatStroke(seat).withAlphaComponent(safeGuideAlpha() * 0.72).setStroke()
            entry.stroke()
        }
    }

    private func drawHomeBoxes(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        for seat in 0..<4 {
            let rect = layout.homeRects[seat]
            let box = UIBezierPath(roundedRect: rect,
                                   cornerRadius: 10 * scale)
            seatFill(seat).withAlphaComponent(usesPokerFeltSurface ? 0.12 : 0.08).setFill()
            box.fill()
            visibleSeatStroke(seat).withAlphaComponent(homeBoxStrokeAlpha()).setStroke()
            box.lineWidth = 1.2 * scale
            let dash = [5 * scale, 3 * scale]
            dash.withUnsafeBufferPointer {
                box.setLineDash($0.baseAddress, count: dash.count, phase: 0)
            }
            box.stroke()

            drawHomeLabel(seat: seat, at: layout.homeLabelPoints[seat], scale: scale)
        }
    }

    private func drawTrackCells(_ layout: JKBoardLayout, in ctx: CGContext) {
        for (cellID, center) in layout.trackCentres.enumerated() {
            let kind = graph.trackCells[cellID]
            let section = min(3, max(0, cellID / max(1, graph.cellsPerQuadrant)))
            switch kind {
            case .base(let owner):
                drawHole(
                    at: center,
                    radius: layout.cellRadius + 4 * layout.svgScale,
                    fill: seatFill(owner).withAlphaComponent(usesPokerFeltSurface ? 0.30 : 0.34),
                    stroke: visibleSeatStroke(owner),
                    lineWidth: 2.3 * layout.svgScale,
                    in: ctx
                )
                drawCenteredText(seatLetter(owner),
                                 at: center,
                                 fontSize: 7 * layout.svgScale,
                                 weight: .bold,
                                 color: visibleSeatStroke(owner).withAlphaComponent(0.90))
            case .safeGate(let owner):
                drawHole(
                    at: center,
                    radius: layout.cellRadius + 2 * layout.svgScale,
                    fill: seatFill(owner).withAlphaComponent(usesPokerFeltSurface ? 0.22 : 0.24),
                    stroke: visibleSeatStroke(owner).withAlphaComponent(0.95),
                    lineWidth: 1.9 * layout.svgScale,
                    in: ctx
                )
                drawCenteredText(">",
                                 at: center,
                                 fontSize: 7 * layout.svgScale,
                                 weight: .regular,
                                 color: visibleSeatStroke(owner).withAlphaComponent(0.88))
            case .track, .safe, .home:
                drawHole(
                    at: center,
                    radius: layout.cellRadius,
                    fill: seatFill(section).withAlphaComponent(regularHoleFillAlpha()),
                    stroke: visibleSeatStroke(section).withAlphaComponent(regularHoleStrokeAlpha()),
                    lineWidth: 1.25 * layout.svgScale,
                    in: ctx
                )
            }
        }
    }

    private func drawSafeCells(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        for seat in 0..<4 {
            for (lane, center) in layout.safeCentres[seat].enumerated() {
                let isDeepest = lane == layout.safeCentres[seat].count - 1
                if isDeepest {
                    drawInnerDot(at: center,
                                 radius: layout.cellRadius + 7 * scale,
                                 color: seatFill(seat).withAlphaComponent(usesPokerFeltSurface ? 0.14 : 0.10),
                                 in: ctx)
                }
                drawHole(
                    at: center,
                    radius: layout.cellRadius + 3 * scale,
                    fill: seatFill(seat).withAlphaComponent(isDeepest ? 0.34 : 0.24),
                    stroke: visibleSeatStroke(seat).withAlphaComponent(0.96),
                    lineWidth: (isDeepest ? 2.25 : 1.85) * scale,
                    in: ctx
                )
                if !isDeepest && lane > 0 {
                    drawInnerDot(at: center,
                                 radius: 2 * scale,
                                 color: visibleSeatStroke(seat).withAlphaComponent(0.78),
                                 in: ctx)
                }
            }
        }

        for seat in 0..<4 {
            for (slot, center) in layout.homeCentres[seat].enumerated() {
                let occupied = hasMarbleInHome(seat: seat, slot: slot)
                drawHole(
                    at: center,
                    radius: 10 * scale,
                    fill: seatFill(seat).withAlphaComponent(occupied ? 0.24 : 0.12),
                    stroke: visibleSeatStroke(seat).withAlphaComponent(occupied ? 0.86 : 0.52),
                    lineWidth: 1.75 * scale,
                    in: ctx
                )
            }
        }
    }

    private func drawCenterOrnament(_ layout: JKBoardLayout, in ctx: CGContext) {
        let scale = layout.svgScale
        let radius = 58 * scale
        let outer = CGRect(x: layout.center.x - radius,
                           y: layout.center.y - radius,
                           width: radius * 2,
                           height: radius * 2)
        let ornament = UIBezierPath(ovalIn: outer)
        centerOrnamentFillColor().setFill()
        ornament.fill()
        BoardColor.gold.withAlphaComponent(37.0 / 255.0).setStroke()
        ornament.lineWidth = 1.5 * scale
        ornament.stroke()

        let inner = UIBezierPath(ovalIn: circleRect(center: layout.center,
                                                    radius: 51 * scale))
        inner.lineWidth = 1 * scale
        BoardColor.gold.withAlphaComponent(20.0 / 255.0).setStroke()
        inner.stroke()

        drawCenteredText("JACKAROO",
                         at: CGPoint(x: layout.center.x, y: layout.center.y - 7 * scale),
                         fontSize: 11 * scale,
                         weight: .bold,
                         color: BoardColor.gold)
        drawCenteredText("D S C H",
                         at: CGPoint(x: layout.center.x, y: layout.center.y + 10 * scale),
                         fontSize: 9 * scale,
                         weight: .regular,
                         color: BoardColor.gold.withAlphaComponent(85.0 / 255.0))
    }

    private func drawHole(at center: CGPoint,
                          radius: CGFloat,
                          fill: UIColor,
                          stroke: UIColor,
                          lineWidth: CGFloat,
                          in ctx: CGContext) {
        let rect = CGRect(x: center.x - radius,
                          y: center.y - radius,
                          width: radius * 2,
                          height: radius * 2)
        let haloInset = max(0.7, radius * 0.16)
        holeHaloColor().setFill()
        UIBezierPath(ovalIn: rect.insetBy(dx: -haloInset, dy: -haloInset)).fill()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: radius * 0.20),
                      blur: radius * 0.45,
                      color: holeShadowColor().cgColor)
        fill.setFill()
        UIBezierPath(ovalIn: rect).fill()
        ctx.restoreGState()

        let ring = UIBezierPath(ovalIn: rect.insetBy(dx: lineWidth / 2,
                                                     dy: lineWidth / 2))
        ring.lineWidth = lineWidth
        stroke.setStroke()
        ring.stroke()

        let highlightInset = max(lineWidth * 1.2, radius * 0.28)
        let highlight = UIBezierPath(ovalIn: rect.insetBy(dx: highlightInset,
                                                          dy: highlightInset))
        highlight.lineWidth = max(0.45, lineWidth * 0.55)
        holeHighlightColor().setStroke()
        highlight.stroke()
    }

    private func drawInnerDot(at center: CGPoint,
                              radius: CGFloat,
                              color: UIColor,
                              in ctx: CGContext) {
        color.setFill()
        UIBezierPath(ovalIn: CGRect(x: center.x - radius,
                                    y: center.y - radius,
                                    width: radius * 2,
                                    height: radius * 2)).fill()
    }

    private func drawHomeLabel(seat: SeatID, at point: CGPoint, scale: CGFloat) {
        drawCenteredText(seatName(seat),
                         at: point,
                         fontSize: 10 * scale,
                         weight: .bold,
                         color: seatFill(seat).withAlphaComponent(0.80))
    }

    private func drawCenteredText(_ text: String,
                                  at point: CGPoint,
                                  fontSize: CGFloat,
                                  weight: UIFont.Weight,
                                  color: UIColor) {
        guard fontSize > 0 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                return paragraph
            }()
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: point.x - size.width / 2,
                          y: point.y - size.height / 2,
                          width: size.width,
                          height: size.height)
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func hasMarbleInHome(seat: SeatID, slot: Int) -> Bool {
        lastState?.marbles.contains {
            $0.owner == seat && $0.position == .home(slot: slot)
        } ?? true
    }

    private func circleRect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius,
               y: center.y - radius,
               width: radius * 2,
               height: radius * 2)
    }

    // MARK: - Marble layout

    /// Snap every marble to its state position. Pass `excluding` to leave
    /// one marble untouched (used while it is mid-animation).
    func snapMarbles(from state: JKGameState, excluding excludedID: MarbleID? = nil) {
        lastState = state
        guard let layout = lastLayout ?? buildLayoutForNow() else { return }
        let marbleSize = layout.marbleSize
        for marble in state.marbles {
            if marble.id == excludedID { continue }
            guard let view = marbleViews[marble.id],
                  let center = layout.point(for: marble.position, owner: marble.owner) else { continue }
            view.bounds = CGRect(x: 0, y: 0, width: marbleSize, height: marbleSize)
            view.center = center
            view.isActive = marble.id == activeMarbleID
            view.isSelected = marble.id == selectedMarbleID
            bringSubviewToFront(view)
        }
    }

    /// Stop any in-flight marble movement (e.g. when backgrounding). Engine
    /// state is unaffected; the caller should `snapMarbles` to reconcile.
    func cancelMarbleAnimations() {
        for (_, view) in marbleViews { view.layer.removeAllAnimations() }
    }

    /// Walk a marble through a path of track cells, then to a final
    /// position, which may be a Safe cell or stay on the track.
    func animateMove(marble id: MarbleID,
                     from: JKPosition,
                     to: JKPosition,
                     via cells: [CellID],
                     owner: SeatID,
                     stepDuration: TimeInterval = 0.12,
                     completion: (() -> Void)? = nil) {
        guard let view = marbleViews[id],
              let layout = lastLayout ?? buildLayoutForNow() else {
            completion?()
            return
        }

        var stops: [CGPoint] = []
        for cell in cells {
            if let point = layout.point(forTrack: cell) {
                stops.append(point)
            }
        }
        if let finalPoint = layout.point(for: to, owner: owner) {
            stops.append(finalPoint)
        }
        guard !stops.isEmpty else {
            completion?()
            return
        }

        bringSubviewToFront(view)
        let finalPoint = stops.last
        animateThrough(view: view, stops: stops,
                       stepDuration: stepDuration) { [weak self] in
            if let finalPoint {
                self?.flashLastMove(at: finalPoint, radius: layout.cellRadius + 7 * layout.svgScale)
            }
            completion?()
        }
    }

    private func animateThrough(view: UIView,
                                stops: [CGPoint],
                                stepDuration: TimeInterval,
                                completion: (() -> Void)?) {
        guard let first = stops.first else {
            completion?()
            return
        }
        UIView.animate(withDuration: stepDuration,
                       delay: 0,
                       options: .curveEaseInOut) {
            view.center = first
        } completion: { _ in
            let rest = Array(stops.dropFirst())
            if rest.isEmpty {
                completion?()
            } else {
                self.animateThrough(view: view,
                                    stops: rest,
                                    stepDuration: stepDuration,
                                    completion: completion)
            }
        }
    }

    private func buildLayoutForNow() -> JKBoardLayout? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        return JKBoardLayout(frame: bounds, cellsPerQuadrant: graph.cellsPerQuadrant)
    }

    // MARK: - Highlights

    func setActiveMarble(_ id: MarbleID?) {
        activeMarbleID = id
        for (mid, view) in marbleViews {
            view.isActive = mid == id
        }
    }

    func setSelectedMarble(_ id: MarbleID?) {
        selectedMarbleID = id
        for (mid, view) in marbleViews {
            view.isSelected = mid == id
        }
    }

    func highlightLegalTargets(trackCells: Set<CellID>,
                               safeCells: [SeatID: Set<Int>]) {
        highlightedTrackCells = trackCells
        highlightedSafeCells = safeCells
        updateTargetRings()
    }

    func clearHighlights() {
        highlightLegalTargets(trackCells: [], safeCells: [:])
    }

    private func updateTargetRings() {
        targetRingLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let layout = lastLayout ?? buildLayoutForNow() else { return }

        for cell in highlightedTrackCells.sorted() {
            guard let point = layout.point(forTrack: cell) else { continue }
            let color = targetColor(forTrackCell: cell)
            targetRingLayer.addSublayer(makeTargetRing(at: point,
                                                       radius: layout.cellRadius + 5 * layout.svgScale,
                                                       color: color))
        }

        for seat in highlightedSafeCells.keys.sorted() {
            let lanes = highlightedSafeCells[seat] ?? []
            for lane in lanes.sorted() {
                guard seat >= 0,
                      seat < layout.safeCentres.count,
                      lane >= 0,
                      lane < layout.safeCentres[seat].count else { continue }
                targetRingLayer.addSublayer(makeTargetRing(at: layout.safeCentres[seat][lane],
                                                           radius: layout.cellRadius + 5 * layout.svgScale,
                                                           color: seatFill(seat)))
            }
        }
    }

    private func makeTargetRing(at center: CGPoint,
                                radius: CGFloat,
                                color: UIColor) -> CAShapeLayer {
        let lineWidth = max(2, radius * 0.18)
        let rect = CGRect(x: center.x - radius,
                          y: center.y - radius,
                          width: radius * 2,
                          height: radius * 2)
        let ring = CAShapeLayer()
        ring.frame = rect
        ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: lineWidth / 2,
                                                             dy: lineWidth / 2)).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = BoardColor.gold.resolvedColor(with: traitCollection).cgColor
        ring.lineWidth = lineWidth
        ring.shadowColor = color.resolvedColor(with: traitCollection).cgColor
        ring.shadowOpacity = 0.85
        ring.shadowRadius = radius * 0.45
        ring.shadowOffset = .zero

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.45
        opacity.toValue = 1.0
        opacity.duration = 0.85
        opacity.autoreverses = true
        opacity.repeatCount = .infinity

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.96
        scale.toValue = 1.08
        scale.duration = 0.85
        scale.autoreverses = true
        scale.repeatCount = .infinity

        ring.add(opacity, forKey: "targetOpacity")
        ring.add(scale, forKey: "targetScale")
        return ring
    }

    private func flashLastMove(at center: CGPoint, radius: CGFloat) {
        let ring = makeTargetRing(at: center, radius: radius,
                                  color: BoardColor.gold)
        targetRingLayer.addSublayer(ring)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.55
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak ring] in
            ring?.removeFromSuperlayer()
        }
        ring.removeAllAnimations()
        ring.add(fade, forKey: "lastMoveFade")
        CATransaction.commit()
    }

    // MARK: - Centre fire pile

    func setFirePileTop(_ card: JKCard?) {
        if let card {
            let red = card.suit == .hearts || card.suit == .diamonds
            centerFireLabel.textColor = red
                ? UIColor(red: 0.70, green: 0.14, blue: 0.18, alpha: 1)
                : UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)
            centerFireLabel.text = card.debugDescription
            centerFireCard.isHidden = false
        } else {
            centerFireCard.isHidden = true
            centerFireLabel.text = nil
        }
        setNeedsLayout()
    }

    // MARK: - Tap handling

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        switch hitTarget(at: gr.location(in: self)) {
        case .center:
            onCenterTapped?()
        case .track(let cell):
            onTrackCellTapped?(cell)
        case .safe(let seat, let lane):
            onSafeCellTapped?(seat, lane)
        case .home, .none:
            break
        }
    }

    func hitTarget(at point: CGPoint) -> HitTarget? {
        guard let layout = lastLayout ?? buildLayoutForNow() else { return nil }

        if centerCardBack.frame.contains(point)
            || (!centerFireCard.isHidden && centerFireCard.frame.contains(point)) {
            return .center
        }

        let threshold = max(layout.cellRadius + 12 * layout.svgScale,
                            layout.boardRect.width * 0.022)
        let thresholdSquared = threshold * threshold

        if let home = nearestHome(to: point,
                                  thresholdSquared: thresholdSquared,
                                  layout: layout) {
            return home
        }
        if let safe = nearestSafe(to: point,
                                  thresholdSquared: thresholdSquared,
                                  layout: layout) {
            return safe
        }
        return nearestTrack(to: point,
                            thresholdSquared: thresholdSquared,
                            layout: layout)
    }

    private func nearestTrack(to point: CGPoint,
                              thresholdSquared: CGFloat,
                              layout: JKBoardLayout) -> HitTarget? {
        var best: (cell: CellID, distance: CGFloat)?
        for (cell, center) in layout.trackCentres.enumerated() {
            let d = JKBoardLayout.squaredDistance(point, center)
            guard d <= thresholdSquared else { continue }
            if best == nil || d < best!.distance {
                best = (cell, d)
            }
        }
        if let best {
            return .track(best.cell)
        }
        return nil
    }

    private func nearestSafe(to point: CGPoint,
                             thresholdSquared: CGFloat,
                             layout: JKBoardLayout) -> HitTarget? {
        var best: (seat: SeatID, lane: Int, distance: CGFloat)?
        for seat in 0..<layout.safeCentres.count {
            for (lane, center) in layout.safeCentres[seat].enumerated() {
                let d = JKBoardLayout.squaredDistance(point, center)
                guard d <= thresholdSquared else { continue }
                if best == nil || d < best!.distance {
                    best = (seat, lane, d)
                }
            }
        }
        if let best {
            return .safe(best.seat, best.lane)
        }
        return nil
    }

    private func nearestHome(to point: CGPoint,
                             thresholdSquared: CGFloat,
                             layout: JKBoardLayout) -> HitTarget? {
        var best: (seat: SeatID, slot: Int, distance: CGFloat)?
        for seat in 0..<layout.homeCentres.count {
            for (slot, center) in layout.homeCentres[seat].enumerated() {
                let d = JKBoardLayout.squaredDistance(point, center)
                guard d <= thresholdSquared else { continue }
                if best == nil || d < best!.distance {
                    best = (seat, slot, d)
                }
            }
        }
        if let best {
            return .home(best.seat, best.slot)
        }
        return nil
    }

    // MARK: - Colors

    private func seatFill(_ seat: SeatID) -> UIColor {
        JKMarbleView.SeatPalette.seat(seat).body.resolvedColor(with: traitCollection)
    }

    private func seatStroke(_ seat: SeatID) -> UIColor {
        JKMarbleView.SeatPalette.seat(seat).outline.resolvedColor(with: traitCollection)
    }

    private func targetColor(forTrackCell cell: CellID) -> UIColor {
        guard cell >= 0, cell < graph.trackCells.count else { return BoardColor.gold }
        switch graph.trackCells[cell] {
        case .base(let owner), .safeGate(let owner):
            return seatFill(owner)
        case .track, .safe, .home:
            return BoardColor.gold
        }
    }

    private func seatName(_ seat: SeatID) -> String {
        switch seat {
        case 0: return "GREEN"
        case 1: return "RED"
        case 2: return "YELLOW"
        case 3: return "BLUE"
        default: return "PLAYER"
        }
    }

    private func seatLetter(_ seat: SeatID) -> String {
        switch seat {
        case 0: return "G"
        case 1: return "R"
        case 2: return "Y"
        case 3: return "B"
        default: return "P"
        }
    }

    private enum BoardColor {
        static let inkCore = UIColor(red: 0.05, green: 0.09, blue: 0.15, alpha: 1)
        static let inkEdge = UIColor(red: 0.010, green: 0.018, blue: 0.036, alpha: 1)
        static let gold = UIColor(red: 0.86, green: 0.66, blue: 0.32, alpha: 1)
        static let outerStroke = UIColor(red: 0.10, green: 0.18, blue: 0.29, alpha: 1)
        static let trackShadow = UIColor(red: 0.02, green: 0.06, blue: 0.12, alpha: 1)
        static let trackGroove = UIColor(red: 0.05, green: 0.11, blue: 0.20, alpha: 1)
    }
}
