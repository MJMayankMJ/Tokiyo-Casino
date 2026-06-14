//
//  JKHandoffOverlay.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  Full-screen "pass the device" privacy curtain shown between human
//  turns in hot-seat play. It blocks the board until the seated player
//  taps "Show my hand", so the previous player's hand stays private.
//

import UIKit

final class JKHandoffOverlay: UIView {

    /// Called when the seated player taps "Show my hand".
    var onReveal: (() -> Void)?

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let dim = UIView()
    private let avatar: AvatarView
    private let eyebrow = UILabel()
    private let nameLabel = UILabel()
    private let revealButton = MPPrimaryButton(title: "Show my hand")
    private let hintLabel = UILabel()
    private let stack = UIStackView()

    init() {
        self.avatar = AvatarView(name: "P", hue: 40, size: 96)
        super.init(frame: .zero)

        dim.backgroundColor = MPTheme.pageBg.withAlphaComponent(0.55)
        for v in [blur, dim] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        eyebrow.attributedText = NSAttributedString(string: "PASS THE DEVICE", attributes: [
            .kern: 2.0, .font: MPFont.ui(11, weight: .bold), .foregroundColor: MPTheme.muted,
        ])
        eyebrow.textAlignment = .center

        nameLabel.font = MPFont.display(30, weight: .medium)
        nameLabel.textColor = MPTheme.ink
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.7

        hintLabel.text = "Make sure only you can see the screen."
        hintLabel.font = MPFont.ui(13, weight: .medium)
        hintLabel.textColor = MPTheme.muted
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0

        avatar.translatesAutoresizingMaskIntoConstraints = false

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(avatar)
        stack.setCustomSpacing(22, after: avatar)
        stack.addArrangedSubview(eyebrow)
        stack.addArrangedSubview(nameLabel)
        stack.setCustomSpacing(24, after: nameLabel)
        stack.addArrangedSubview(revealButton)
        stack.setCustomSpacing(14, after: revealButton)
        stack.addArrangedSubview(hintLabel)
        addSubview(stack)

        revealButton.addTarget(self, action: #selector(revealTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            dim.topAnchor.constraint(equalTo: topAnchor),
            dim.leadingAnchor.constraint(equalTo: leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: bottomAnchor),

            avatar.widthAnchor.constraint(equalToConstant: 96),
            avatar.heightAnchor.constraint(equalToConstant: 96),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            revealButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])

        isAccessibilityElement = false
        accessibilityViewIsModal = true
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Configure the curtain for `name` (seat hue keeps avatars distinct).
    func configure(name: String, seat: SeatID) {
        nameLabel.text = "Pass to \(name)"
        // Rebuild the avatar with this player's initials + a seat-stable hue.
        let hues: [CGFloat] = [12, 150, 38, 200]
        let newAvatar = AvatarView(name: name, hue: hues[seat % 4], size: 96)
        newAvatar.translatesAutoresizingMaskIntoConstraints = false
        newAvatar.widthAnchor.constraint(equalToConstant: 96).isActive = true
        newAvatar.heightAnchor.constraint(equalToConstant: 96).isActive = true
        if let idx = stack.arrangedSubviews.firstIndex(of: avatarRef) {
            stack.removeArrangedSubview(avatarRef)
            avatarRef.removeFromSuperview()
            stack.insertArrangedSubview(newAvatar, at: idx)
            stack.setCustomSpacing(22, after: newAvatar)
            avatarRef = newAvatar
        }
        revealButton.accessibilityLabel = "Show \(name)'s hand"
        accessibilityLabel = "Pass the device to \(name). Tap show my hand when ready."
    }

    private lazy var avatarRef: UIView = avatar

    @objc private func revealTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onReveal?()
    }
}
