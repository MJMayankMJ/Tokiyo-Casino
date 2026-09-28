import UIKit

/// Home owns layout and type; all color roles come from the 5-3-2 table.
enum HomeDesign {
    static let pageInset: CGFloat = 24
    static let sectionGap: CGFloat = 28
    static let cardGap: CGFloat = 16
    static let cardRadius: CGFloat = 24
    static let cardInset: CGFloat = 24
    static let maxWidth: CGFloat = 820
    static let wideBreakpoint: CGFloat = 700

    static func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular,
                      style: UIFont.TextStyle, color: UIColor = TDPTheme.ink) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight))
        label.adjustsFontForContentSizeCategory = true
        label.textColor = color
        label.numberOfLines = 0
        return label
    }
}

private extension UILabel {
    // Kept local to this file; the intro's tracking uses its own attributed copy.
    func track(_ amount: CGFloat) {
        attributedText = NSAttributedString(string: text ?? "", attributes: [.kern: amount])
    }
}

final class HomeGameButton: UIControl {
    let game: HomeGameItem
    private let cardPreview: HomeCardPreview
    private let portrait = UIImageView()
    private let artWash = UIView()
    private let fade = CAGradientLayer()
    private let bottomFade = CAGradientLayer()
    private let copy = UIStackView()
    private var minHeight: NSLayoutConstraint!
    private var copyWidth: NSLayoutConstraint!
    private var accessibleCopyWidth: NSLayoutConstraint!
    private var preferredHeight: NSLayoutConstraint!
    var isWideLayout = false {
        didSet {
            guard oldValue != isWideLayout else { return }
            minHeight.constant = isWideLayout ? 270 : 208
            preferredHeight.constant = minHeight.constant
            setNeedsLayout()
        }
    }

    init(game: HomeGameItem) {
        self.game = game
        cardPreview = HomeCardPreview(kind: game.preview)
        let title = game.title
        let subtitle = game.subtitle
        let detail = game.detail
        let symbol = game.symbol
        let imageName = game.imageName
        let identifier = game.id
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = HomeDesign.cardRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(title), \(subtitle)"
        accessibilityHint = "Choose how to play"
        accessibilityIdentifier = identifier
        minHeight = heightAnchor.constraint(greaterThanOrEqualToConstant: 208)
        minHeight.isActive = true
        preferredHeight = heightAnchor.constraint(equalToConstant: 208)
        preferredHeight.priority = .defaultLow
        preferredHeight.isActive = true

        artWash.backgroundColor = TDPTheme.raisedAlt
        artWash.isUserInteractionEnabled = false
        addSubview(artWash)
        portrait.image = UIImage(named: imageName)
        portrait.contentMode = .scaleAspectFit
        portrait.isAccessibilityElement = false
        portrait.isUserInteractionEnabled = false
        addSubview(portrait)
        layer.addSublayer(fade)
        layer.addSublayer(bottomFade)
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.locations = [0, 0.40, 0.64, 1]
        bottomFade.startPoint = CGPoint(x: 0.5, y: 0)
        bottomFade.endPoint = CGPoint(x: 0.5, y: 1)
        bottomFade.locations = [0, 1]

        // Cards and their effects are above both the character and its fade.
        addSubview(cardPreview)

        copy.axis = .vertical
        copy.alignment = .leading
        copy.spacing = 5
        copy.isUserInteractionEnabled = false
        copy.translatesAutoresizingMaskIntoConstraints = false
        addSubview(copy)
        let category = UIStackView()
        category.alignment = .center
        category.spacing = 6
        let suit = UIImageView(image: UIImage(systemName: symbol))
        suit.tintColor = TDPTheme.accent
        suit.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([suit.widthAnchor.constraint(equalToConstant: 12), suit.heightAnchor.constraint(equalToConstant: 14)])
        let mode = HomeDesign.label("CARD TABLE", size: 9, weight: .semibold, style: .caption2, color: TDPTheme.accent)
        mode.track(1.2)
        category.addArrangedSubview(suit)
        category.addArrangedSubview(mode)
        copy.addArrangedSubview(category)
        copy.setCustomSpacing(10, after: category)
        let name = HomeDesign.label(title, size: 32, weight: .semibold, style: .title1)
        copy.addArrangedSubview(name)
        copy.addArrangedSubview(HomeDesign.label(subtitle, size: 12, weight: .medium, style: .caption1, color: TDPTheme.inkSoft))
        let description = HomeDesign.label(detail, size: 12, style: .caption1, color: TDPTheme.inkSoft)
        copy.addArrangedSubview(description)
        copy.setCustomSpacing(15, after: description)

        let play = UIStackView()
        play.alignment = .center
        play.spacing = 14
        play.isLayoutMarginsRelativeArrangement = true
        play.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 13)
        play.backgroundColor = TDPTheme.primary
        play.layer.cornerRadius = 18
        play.addArrangedSubview(HomeDesign.label("Play", size: 13, weight: .semibold, style: .subheadline, color: TDPTheme.primaryInk))
        let arrow = UIImageView(image: UIImage(systemName: "arrow.up.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        arrow.tintColor = TDPTheme.primaryInk
        play.addArrangedSubview(arrow)
        copy.addArrangedSubview(play)
        copyWidth = copy.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.53, constant: -HomeDesign.cardInset)
        accessibleCopyWidth = copy.widthAnchor.constraint(equalTo: widthAnchor, constant: -HomeDesign.cardInset * 2)
        NSLayoutConstraint.activate([
            copy.leadingAnchor.constraint(equalTo: leadingAnchor, constant: HomeDesign.cardInset),
            copy.topAnchor.constraint(equalTo: topAnchor, constant: HomeDesign.cardInset),
            copy.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -HomeDesign.cardInset),
            copyWidth
        ])
        // One accessible button, including its decorative Play affordance.
        accessibilityElements = []
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self]) {
            (button: HomeGameButton, _: UITraitCollection) in
            button.updateColors()
            button.updateAccessibleLayout()
            button.setNeedsLayout()
        }
        updateColors()
        updateAccessibleLayout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let artWidth = bounds.width * 0.55
        let artHeight = artWidth * 1.5
        portrait.frame = CGRect(x: bounds.width - artWidth - 4, y: 12, width: artWidth, height: artHeight)
        artWash.frame = bounds
        cardPreview.frame = CGRect(x: bounds.width * 0.51, y: 0, width: bounds.width * 0.49, height: bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = bounds
        bottomFade.frame = CGRect(x: 0, y: bounds.height - 50, width: bounds.width, height: 50)
        CATransaction.commit()
    }

    private func updateAccessibleLayout() {
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        portrait.isHidden = accessible
        cardPreview.isHidden = accessible
        artWash.isHidden = accessible
        fade.isHidden = accessible
        bottomFade.isHidden = accessible
        copyWidth.isActive = !accessible
        accessibleCopyWidth.isActive = accessible
    }

    private func updateColors() {
        let surface = TDPTheme.raised.resolvedColor(with: traitCollection)
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
        fade.colors = [surface.cgColor, surface.cgColor, surface.withAlphaComponent(0).cgColor, surface.withAlphaComponent(0).cgColor]
        bottomFade.colors = [surface.withAlphaComponent(0).cgColor, surface.withAlphaComponent(0.65).cgColor]
    }

    func playPreview(completion: @escaping () -> Void) {
        cardPreview.play(completion: completion)
    }

    func resetPreview() {
        cardPreview.reset()
    }

    override var isHighlighted: Bool {
        didSet {
            let changes = {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
                self.alpha = self.isHighlighted ? 0.82 : 1
            }
            if UIAccessibility.isReduceMotionEnabled { alpha = isHighlighted ? 0.82 : 1 }
            else { UIView.animate(withDuration: 0.14, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction], animations: changes) }
        }
    }
}
