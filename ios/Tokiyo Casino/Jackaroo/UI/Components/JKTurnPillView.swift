//
//  JKTurnPillView.swift
//  Tokiyo Casino — Jackaroo
//
//  Glass pill above the centre medallion that shows whose turn it is
//  and a one-line status hint. Same silhouette as poker's PotPillView.
//

import UIKit

final class JKTurnPillView: UIView {

    private let nameLabel = UILabel()
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = MPTheme.glass
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = MPTheme.border.cgColor

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4

        nameLabel.font = MPFont.display(15, weight: .medium)
        nameLabel.textColor = MPTheme.ink
        statusLabel.font = MPFont.ui(11, weight: .semibold)
        statusLabel.textColor = MPTheme.muted

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 10),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 36),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func set(name: String, status: String) {
        nameLabel.text = name
        statusLabel.text = status
    }
}
