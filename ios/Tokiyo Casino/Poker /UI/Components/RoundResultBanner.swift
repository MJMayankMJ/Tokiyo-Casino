//
//  RoundResultBanner.swift
//  Tokiyo Casino
//
//  Compact in-table banner shown at round end. One row per winner so a
//  single banner can describe a side-pot split without stacking modals.
//

import UIKit

final class RoundResultBanner: UIView {

    struct Entry {
        let title: String
        let subtitle: String?
        let isHuman: Bool
    }

    private let stack = UIStackView()

    init(entries: [Entry]) {
        super.init(frame: .zero)
        backgroundColor = PokerTheme.surface.withAlphaComponent(0.96)
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = PokerTheme.amber.withAlphaComponent(0.55).cgColor
        layer.shadowColor = PokerTheme.amber.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 18

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])

        for (index, entry) in entries.enumerated() {
            stack.addArrangedSubview(makeRow(entry: entry))
            if index < entries.count - 1 {
                let sep = UIView()
                sep.backgroundColor = PokerTheme.border
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(sep)
                sep.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.7).isActive = true
            }
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func makeRow(entry: Entry) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 1

        let title = UILabel()
        title.text = entry.title
        title.font = .systemFont(ofSize: 15, weight: .heavy)
        title.textColor = entry.isHuman ? PokerTheme.forestDeep : PokerTheme.ink
        title.textAlignment = .center
        title.numberOfLines = 1
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.8
        container.addArrangedSubview(title)

        if let subtitle = entry.subtitle, !subtitle.isEmpty {
            let sub = UILabel()
            sub.text = subtitle.uppercased()
            sub.font = .systemFont(ofSize: 10, weight: .bold)
            sub.textColor = PokerTheme.amber
            sub.textAlignment = .center
            container.addArrangedSubview(sub)
        }
        return container
    }

    func presentAnimated() {
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.6) {
            self.alpha = 1
            self.transform = .identity
        }
    }

    func dismissAnimated(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.28, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -8).scaledBy(x: 0.96, y: 0.96)
        }) { _ in
            self.removeFromSuperview()
            completion()
        }
    }
}
