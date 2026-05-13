//
//  BettingControllerView.swift
//  Tokiyo Casino
//
//  Redesigned to match the Claude Design action panel: a clean three-button
//  row (Fold • Check/Call • Raise) with an optional raise slider that
//  expands above it. Colors and shapes mirror the LIGHT/MIDNIGHT palette.
//

import Foundation
import UIKit

final class BettingControlsView: UIView {

    // MARK: - Buttons (3-button row from design)
    private let foldButton  = ActionButton(kind: .fold)
    private let checkCallButton = ActionButton(kind: .check)
    private let raiseButton = ActionButton(kind: .raise)

    // Raise slider panel (expandable)
    private let raisePanel = UIView()
    private let raiseHeader = UILabel()
    private let raiseAmountLabel = UILabel()
    private let raiseSubLabel = UILabel()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let track = UIView()
    private let fill = UIView()
    private let thumb = UIView()
    private var trackPanGesture: UIPanGestureRecognizer?
    private var quickStack = UIStackView()

    // Sound managers (unchanged behavior)
    private var raiseSoundManager = SoundManager()
    private var allInSoundManager = SoundManager()
    private var checkSoundManager = SoundManager()

    // Public
    var onAction: ((PlayerAction) -> Void)?

    // State
    private var minRaise: Int = 0
    private var maxRaise: Int = 0
    private var callAmount: Int = 0
    private var raiseValue: Int = 0
    private var pot: Int = 0
    private var canRaise: Bool = false
    private var raisePanelExpanded: Bool = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupSounds()
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupSounds() {
        raiseSoundManager.setupPlayer(soundName: "raise_sound", soundType: .mp3)
        allInSoundManager.setupPlayer(soundName: "AllIn_sound", soundType: .mp3)
        checkSoundManager.setupPlayer(soundName: "spin_button_tap", soundType: .mp3)
    }

    private func setupView() {
        // Raise panel
        raisePanel.backgroundColor = PokerTheme.surface
        raisePanel.layer.cornerRadius = 16
        raisePanel.layer.borderWidth = 1
        raisePanel.layer.borderColor = PokerTheme.border.cgColor
        PokerTheme.applyShadowMd(raisePanel.layer)
        raisePanel.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.isHidden = true
        addSubview(raisePanel)

        raiseHeader.text = "RAISE TO"
        raiseHeader.font = .systemFont(ofSize: 9, weight: .semibold)
        raiseHeader.textColor = PokerTheme.muted
        raiseHeader.textAlignment = .center
        raiseHeader.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(raiseHeader)

        raiseAmountLabel.text = "$0"
        raiseAmountLabel.font = .systemFont(ofSize: 24, weight: .heavy)
        raiseAmountLabel.textColor = PokerTheme.ink
        raiseAmountLabel.textAlignment = .center
        raiseAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(raiseAmountLabel)

        raiseSubLabel.text = ""
        raiseSubLabel.font = .systemFont(ofSize: 10, weight: .medium)
        raiseSubLabel.textColor = PokerTheme.muted
        raiseSubLabel.textAlignment = .center
        raiseSubLabel.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(raiseSubLabel)

        styleStepperButton(minusButton, glyph: "−")
        minusButton.addTarget(self, action: #selector(stepDown), for: .touchUpInside)
        raisePanel.addSubview(minusButton)

        styleStepperButton(plusButton, glyph: "+")
        plusButton.addTarget(self, action: #selector(stepUp), for: .touchUpInside)
        raisePanel.addSubview(plusButton)

        // Track / fill / thumb
        track.backgroundColor = PokerTheme.surfaceAlt
        track.layer.cornerRadius = 3
        track.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(track)

        fill.backgroundColor = PokerTheme.forest
        fill.layer.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        thumb.backgroundColor = .white
        thumb.layer.borderWidth = 2
        thumb.layer.borderColor = PokerTheme.forest.cgColor
        thumb.layer.cornerRadius = 10
        thumb.layer.shadowColor = UIColor.black.cgColor
        thumb.layer.shadowOpacity = 0.2
        thumb.layer.shadowOffset = CGSize(width: 0, height: 2)
        thumb.layer.shadowRadius = 4
        thumb.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(thumb)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(trackPanned(_:)))
        track.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(trackTapped(_:)))
        track.addGestureRecognizer(tap)
        trackPanGesture = pan

        // Quick bets row
        quickStack.axis = .horizontal
        quickStack.distribution = .fillEqually
        quickStack.spacing = 6
        quickStack.translatesAutoresizingMaskIntoConstraints = false
        raisePanel.addSubview(quickStack)

        // Outer vertical stack: raisePanel above action row. When raisePanel
        // is hidden, the stack collapses, so bettingControls shrinks to just
        // the action-row height. The table view above gets the freed space.
        let actionRow = UIStackView(arrangedSubviews: [foldButton, checkCallButton, raiseButton])
        actionRow.axis = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fillEqually
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // Remove raisePanel from `self` and re-add via the stack
        raisePanel.removeFromSuperview()

        let outerStack = UIStackView(arrangedSubviews: [raisePanel, actionRow])
        outerStack.axis = .vertical
        outerStack.spacing = 10
        outerStack.alignment = .fill
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(outerStack)

        foldButton.onTap = { [weak self] in self?.foldTapped() }
        checkCallButton.onTap = { [weak self] in self?.checkCallTapped() }
        raiseButton.onTap = { [weak self] in self?.raiseTapped() }

        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: topAnchor),
            outerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            outerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            outerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])

        // Inside-panel layout — defaultHigh priority so a collapsed panel
        // doesn't fight the actionRow.bottom anchor.
        let inside: [NSLayoutConstraint] = [
            raiseHeader.topAnchor.constraint(equalTo: raisePanel.topAnchor, constant: 10),
            raiseHeader.centerXAnchor.constraint(equalTo: raisePanel.centerXAnchor),

            raiseAmountLabel.topAnchor.constraint(equalTo: raiseHeader.bottomAnchor, constant: 2),
            raiseAmountLabel.centerXAnchor.constraint(equalTo: raisePanel.centerXAnchor),

            raiseSubLabel.topAnchor.constraint(equalTo: raiseAmountLabel.bottomAnchor, constant: 0),
            raiseSubLabel.centerXAnchor.constraint(equalTo: raisePanel.centerXAnchor),

            minusButton.leadingAnchor.constraint(equalTo: raisePanel.leadingAnchor, constant: 14),
            minusButton.centerYAnchor.constraint(equalTo: raiseAmountLabel.centerYAnchor),
            minusButton.widthAnchor.constraint(equalToConstant: 36),
            minusButton.heightAnchor.constraint(equalToConstant: 36),

            plusButton.trailingAnchor.constraint(equalTo: raisePanel.trailingAnchor, constant: -14),
            plusButton.centerYAnchor.constraint(equalTo: raiseAmountLabel.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 36),
            plusButton.heightAnchor.constraint(equalToConstant: 36),

            track.leadingAnchor.constraint(equalTo: raisePanel.leadingAnchor, constant: 14),
            track.trailingAnchor.constraint(equalTo: raisePanel.trailingAnchor, constant: -14),
            track.topAnchor.constraint(equalTo: raiseSubLabel.bottomAnchor, constant: 10),
            track.heightAnchor.constraint(equalToConstant: 6),

            quickStack.leadingAnchor.constraint(equalTo: raisePanel.leadingAnchor, constant: 14),
            quickStack.trailingAnchor.constraint(equalTo: raisePanel.trailingAnchor, constant: -14),
            quickStack.topAnchor.constraint(equalTo: track.bottomAnchor, constant: 16),
            quickStack.heightAnchor.constraint(equalToConstant: 32),
            quickStack.bottomAnchor.constraint(equalTo: raisePanel.bottomAnchor, constant: -12),

            thumb.widthAnchor.constraint(equalToConstant: 20),
            thumb.heightAnchor.constraint(equalToConstant: 20),
            thumb.centerYAnchor.constraint(equalTo: track.centerYAnchor),
        ]
        inside.forEach { $0.priority = .defaultHigh }
        NSLayoutConstraint.activate(inside)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        positionThumb()
    }

    private func styleStepperButton(_ button: UIButton, glyph: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = PokerTheme.surfaceAlt
        button.setTitle(glyph, for: .normal)
        button.setTitleColor(PokerTheme.ink, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 19, weight: .bold)
        button.layer.cornerRadius = 11
    }

    // MARK: - Public surface

    /// Called by GameViewController when it's the human's turn.
    func updateForActions(_ actions: [PlayerAction], callAmount: Int, minRaise: Int, maxRaise: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        self.callAmount = callAmount
        self.minRaise = minRaise
        self.maxRaise = maxRaise
        self.raiseValue = max(minRaise, min(maxRaise, raiseValue == 0 ? minRaise : raiseValue))

        let canFold = actions.contains { if case .fold = $0 { return true } else { return false } }
        let canCheck = actions.contains { if case .check = $0 { return true } else { return false } }
        let canCall = actions.contains { if case .call = $0 { return true } else { return false } }
        let canRaiseAction = actions.contains { if case .raise = $0 { return true } else { return false } }
        let canAllIn = actions.contains { if case .allIn = $0 { return true } else { return false } }
        self.canRaise = canRaiseAction || canAllIn

        // Fold
        foldButton.label = "Fold"
        foldButton.sublabel = nil
        foldButton.isEnabled = canFold

        // Check / Call
        if canCheck {
            checkCallButton.label = "Check"
            checkCallButton.sublabel = nil
            checkCallButton.isEnabled = true
        } else if canCall {
            checkCallButton.label = "Call"
            checkCallButton.sublabel = "$\(ChipFormatter.string(callAmount))"
            checkCallButton.isEnabled = true
        } else {
            checkCallButton.label = "Check"
            checkCallButton.sublabel = nil
            checkCallButton.isEnabled = false
        }

        // Raise
        raiseButton.label = "Raise"
        raiseButton.sublabel = canRaise ? "tap to set" : nil
        raiseButton.isEnabled = canRaise

        rebuildQuickBets()
        updateRaiseLabels()
        positionThumb()

        // Slide-in animation
        transform = CGAffineTransform(translationX: 0, y: 60)
        alpha = 0
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.transform = .identity
            self.alpha = 1
        }
    }

    func setPot(_ pot: Int) { self.pot = pot; rebuildQuickBets(); updateRaiseLabels() }

    // MARK: - Action handlers

    private func foldTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onAction?(.fold)
        hideWithAnimation()
    }

    private func checkCallTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if checkCallButton.label.lowercased() == "check" {
            checkSoundManager.play()
            onAction?(.check)
        } else {
            raiseSoundManager.play()
            onAction?(.call)
        }
        hideWithAnimation()
    }

    private func raiseTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !raisePanelExpanded {
            showRaisePanel()
        } else if raiseValue >= maxRaise && maxRaise > 0 {
            // All-in convenience: pushing slider to max
            allInSoundManager.play()
            onAction?(.allIn)
            hideWithAnimation()
        } else {
            raiseSoundManager.play()
            onAction?(.raise(raiseValue))
            hideWithAnimation()
        }
    }

    @objc private func stepDown() {
        setRaise(raiseValue - stepSize())
    }
    @objc private func stepUp() {
        setRaise(raiseValue + stepSize())
    }

    private func stepSize() -> Int {
        // Round to nearest "nice" step. Use the bigBlind-like minRaise as the step,
        // falling back to 25 if it's odd.
        let step = max(1, minRaise > 0 ? minRaise : 25)
        return step
    }

    @objc private func trackPanned(_ rec: UIPanGestureRecognizer) {
        let x = rec.location(in: track).x
        setRaiseFromTrack(x)
    }
    @objc private func trackTapped(_ rec: UITapGestureRecognizer) {
        let x = rec.location(in: track).x
        setRaiseFromTrack(x)
    }

    private func setRaiseFromTrack(_ x: CGFloat) {
        let w = max(1, track.bounds.width)
        let p = max(0, min(1, x / w))
        let raw = CGFloat(minRaise) + p * CGFloat(maxRaise - minRaise)
        let step = CGFloat(stepSize())
        let stepped = (raw / step).rounded() * step
        setRaise(Int(stepped))
    }

    private func setRaise(_ value: Int) {
        raiseValue = max(minRaise, min(maxRaise, value))
        raiseButton.sublabel = "$\(ChipFormatter.string(raiseValue))"
        updateRaiseLabels()
        positionThumb()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func updateRaiseLabels() {
        raiseAmountLabel.text = "$\(ChipFormatter.string(raiseValue))"
        if pot > 0 {
            let mult = Double(raiseValue) / Double(pot)
            raiseSubLabel.text = String(format: "%.2f× pot", mult)
        } else {
            raiseSubLabel.text = ""
        }
        if raisePanelExpanded {
            raiseButton.sublabel = "$\(ChipFormatter.string(raiseValue))"
        }
    }

    private func positionThumb() {
        guard maxRaise > minRaise else {
            thumb.center = CGPoint(x: track.frame.minX, y: track.frame.midY)
            fill.frame = .zero
            return
        }
        let pct = CGFloat(raiseValue - minRaise) / CGFloat(maxRaise - minRaise)
        let trackFrame = track.frame
        let x = trackFrame.minX + trackFrame.width * pct
        thumb.center = CGPoint(x: x, y: trackFrame.midY)
        fill.frame = CGRect(x: 0, y: 0, width: track.bounds.width * pct, height: track.bounds.height)
    }

    private func rebuildQuickBets() {
        quickStack.arrangedSubviews.forEach {
            quickStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let bets: [(label: String, value: Int, isAllIn: Bool)] = [
            ("Min", minRaise, false),
            ("½ Pot", round25(Double(pot) * 0.5), false),
            ("Pot", round25(Double(pot)), false),
            ("2× Pot", round25(Double(pot) * 2), false),
            ("All-In", maxRaise, true),
        ]
        for bet in bets {
            let button = QuickBetButton()
            button.title = bet.label
            button.isAllIn = bet.isAllIn
            button.onTap = { [weak self] in
                guard let self else { return }
                self.setRaise(min(self.maxRaise, max(self.minRaise, bet.value)))
            }
            quickStack.addArrangedSubview(button)
        }
    }

    private func round25(_ v: Double) -> Int {
        let stepped = (v / 25.0).rounded() * 25.0
        return max(0, Int(stepped))
    }

    private func showRaisePanel() {
        raisePanelExpanded = true
        raiseButton.sublabel = "$\(ChipFormatter.string(raiseValue))"
        raisePanel.isHidden = false
        raisePanel.alpha = 0
        raisePanel.transform = CGAffineTransform(translationX: 0, y: 10)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.4) {
            self.raisePanel.alpha = 1
            self.raisePanel.transform = .identity
        }
    }

    private func hideWithAnimation() {
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 30).scaledBy(x: 0.98, y: 0.98)
        }) { _ in
            self.isHidden = true
            self.transform = .identity
            self.resetRaisePanel()
        }
    }

    private func resetRaisePanel() {
        raisePanel.isHidden = true
        raisePanelExpanded = false
        raiseButton.sublabel = canRaise ? "tap to set" : nil
        raiseValue = max(minRaise, min(maxRaise, raiseValue))
    }
}

// MARK: - Action button

private final class ActionButton: UIView {

    enum Kind { case fold, check, raise }

    var onTap: (() -> Void)?
    var label: String = "" { didSet { titleLabel.text = label; titleLabel.text = labelDisplayString() } }
    var sublabel: String? {
        didSet {
            sublabelLabel.text = sublabel
            sublabelLabel.isHidden = (sublabel == nil)
        }
    }
    var isEnabled: Bool = true { didSet { applyStyle() } }

    private let titleLabel = UILabel()
    private let sublabelLabel = UILabel()
    private let kind: Kind

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        layer.cornerRadius = 16

        titleLabel.font = .systemFont(ofSize: 16, weight: .heavy)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        sublabelLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        sublabelLabel.textAlignment = .center
        sublabelLabel.translatesAutoresizingMaskIntoConstraints = false
        sublabelLabel.isHidden = true
        addSubview(sublabelLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -7),
            sublabelLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sublabelLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
        ])

        applyStyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Touch handling (no gesture recognizer conflicts)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard isEnabled else { return }
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard isEnabled else { return }
        // Keep pressed style as long as the touch is inside.
        if let touch = touches.first {
            let p = touch.location(in: self)
            let inside = bounds.contains(p)
            UIView.animate(withDuration: 0.08) {
                self.transform = inside
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.10) { self.transform = .identity }
        guard isEnabled, let touch = touches.first else { return }
        let p = touch.location(in: self)
        if bounds.contains(p) {
            onTap?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.10) { self.transform = .identity }
    }

    private func labelDisplayString() -> String {
        switch kind {
        case .fold:  return label.uppercased()
        case .check: return label
        case .raise: return label.uppercased()
        }
    }

    private func applyStyle() {
        let disabled = !isEnabled
        layer.borderWidth = (kind == .raise) ? 0 : 1.5

        let baseAlpha: CGFloat = disabled ? 0.5 : 1.0
        alpha = baseAlpha
        isUserInteractionEnabled = !disabled

        switch kind {
        case .fold:
            backgroundColor = PokerTheme.surface
            layer.borderColor = PokerTheme.coral.cgColor
            titleLabel.textColor = PokerTheme.coralDeep
            sublabelLabel.textColor = PokerTheme.coralDeep
        case .check:
            backgroundColor = PokerTheme.surface
            layer.borderColor = PokerTheme.borderStrong.cgColor
            titleLabel.textColor = PokerTheme.ink
            sublabelLabel.textColor = PokerTheme.muted
        case .raise:
            backgroundColor = PokerTheme.forest
            titleLabel.textColor = .white
            sublabelLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        }
        PokerTheme.applyShadowMd(layer)
    }

}

// MARK: - Quick-bet button

private final class QuickBetButton: UIView {
    var title: String = "" { didSet { label.text = title } }
    var isAllIn: Bool = false { didSet { applyStyle() } }
    var onTap: (() -> Void)?

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = PokerTheme.border.cgColor
        backgroundColor = PokerTheme.surfaceAlt

        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = PokerTheme.ink
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

    }
    required init?(coder: NSCoder) { fatalError() }

    private func applyStyle() {
        if isAllIn {
            layer.borderColor = PokerTheme.amber.cgColor
        } else {
            layer.borderColor = PokerTheme.border.cgColor
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.08) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.10) { self.transform = .identity }
        if let touch = touches.first, bounds.contains(touch.location(in: self)) {
            onTap?()
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.10) { self.transform = .identity }
    }
}
