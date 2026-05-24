//
//  JKTrackCellView.swift
//  Tokiyo Casino — Jackaroo
//
//  Circular cell — looks like a drilled hole in the felt. Same view
//  is reused for track cells, safe-lane cells, and home pockets, with
//  the `kind` distinguishing fill / ring colour.
//

import UIKit

final class JKTrackCellView: UIView {

    enum Kind {
        case track
        case base(owner: SeatID)
        case safe(owner: SeatID)
        case home
    }

    enum Highlight {
        case none
        case legalTarget
        case selected
    }

    let kind: Kind
    var highlight: Highlight = .none { didSet { applyAppearance() } }

    private let dotLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.addSublayer(dotLayer)
        layer.addSublayer(ringLayer)
        applyAppearance()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyAppearance()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        dotLayer.frame = bounds
        ringLayer.frame = bounds
        dotLayer.path = UIBezierPath(ovalIn: r).cgPath
        // Ring sits just outside the dot, so highlight states render
        // a brass halo without changing the dot's own colour.
        ringLayer.path = UIBezierPath(ovalIn: r.insetBy(dx: -0.5, dy: -0.5)).cgPath
        applyAppearance()
    }

    private func applyAppearance() {
        let amber = UIColor.dyn(light: 0xC99540, dark: 0xD9B26A)
        let resolved = traitCollection

        // Body fill — pale "hole" interior.
        let bodyFill: UIColor
        let ringStroke: UIColor
        var ringWidth: CGFloat = 0.75

        switch kind {
        case .track:
            bodyFill = MPTheme.glass
            ringStroke = MPTheme.feltEdge
        case .base(let owner):
            bodyFill = JKMarbleView.SeatPalette.seat(owner).body.withAlphaComponent(0.30)
            ringStroke = JKMarbleView.SeatPalette.seat(owner).outline
            ringWidth = 1.5
        case .safe(let owner):
            bodyFill = JKMarbleView.SeatPalette.seat(owner).body.withAlphaComponent(0.22)
            ringStroke = amber
            ringWidth = 1.2
        case .home:
            bodyFill = MPTheme.feltDepth
            ringStroke = MPTheme.borderStrong
            ringWidth = 1
        }

        dotLayer.fillColor = bodyFill.resolvedColor(with: resolved).cgColor

        switch highlight {
        case .none:
            ringLayer.strokeColor = ringStroke.resolvedColor(with: resolved).cgColor
            ringLayer.lineWidth = ringWidth
            ringLayer.shadowOpacity = 0
        case .legalTarget:
            ringLayer.strokeColor = amber.resolvedColor(with: resolved).cgColor
            ringLayer.lineWidth = 2
            ringLayer.shadowColor = amber.resolvedColor(with: resolved).cgColor
            ringLayer.shadowOpacity = 0.5
            ringLayer.shadowRadius = 3
            ringLayer.shadowOffset = .zero
        case .selected:
            ringLayer.strokeColor = amber.resolvedColor(with: resolved).cgColor
            ringLayer.lineWidth = 2.5
            ringLayer.shadowColor = amber.resolvedColor(with: resolved).cgColor
            ringLayer.shadowOpacity = 0.7
            ringLayer.shadowRadius = 4
            ringLayer.shadowOffset = .zero
        }
        ringLayer.fillColor = UIColor.clear.cgColor
    }
}
