//
//  ProfileViews.swift
//  Tokiyo Casino
//
//  The player's identity across every game: the avatar, the one-time
//  "what should we call you?" screen, and Profile (reached from Home) for
//  changing the name or adding a photo later.
//

import PhotosUI
import UIKit

// MARK: - Avatar

/// Round avatar: the profile photo when there is one, otherwise initials
/// on an amber wash. With `followsProfile` it keeps itself up to date.
final class ProfileAvatarView: UIControl {

    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private var observer: NSObjectProtocol?

    /// Tracks `PlayerProfile` — for the local player's own avatar.
    var followsProfile = false {
        didSet {
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard followsProfile else { return }
            observer = NotificationCenter.default.addObserver(
                forName: PlayerProfile.didChange, object: nil, queue: .main) { [weak self] _ in
                    self?.showProfile()
                }
            showProfile()
        }
    }

    init(diameter: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: diameter, height: diameter))
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        layer.cornerRadius = diameter / 2
        backgroundColor = MPTheme.hostWash

        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.font = .systemFont(ofSize: diameter * 0.38, weight: .semibold)
        initialsLabel.textColor = MPTheme.amberDeep
        initialsLabel.textAlignment = .center
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(initialsLabel)
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            initialsLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func configure(name: String, photo: UIImage?) {
        initialsLabel.text = PlayerProfile.initials(for: name)
        imageView.image = photo
        imageView.isHidden = photo == nil
        accessibilityLabel = name
    }

    private func showProfile() {
        configure(name: PlayerProfile.name, photo: PlayerProfile.photo)
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }
}

// MARK: - Name field

/// Big, borderless text with a single hairline underneath.
final class ProfileNameField: UITextField, UITextFieldDelegate {

    private let underline = UIView()

    init(size: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        font = .systemFont(ofSize: size, weight: .semibold)
        textColor = MPTheme.ink
        tintColor = MPTheme.amber
        attributedPlaceholder = NSAttributedString(string: "Your name",
                                                   attributes: [.foregroundColor: MPTheme.faint])
        autocapitalizationType = .words
        autocorrectionType = .no
        spellCheckingType = .no
        textContentType = .givenName
        returnKeyType = .done
        clearButtonMode = .whileEditing
        delegate = self

        underline.backgroundColor = MPTheme.borderStrong
        underline.isUserInteractionEnabled = false
        underline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(underline)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: size * 2),
            underline.leadingAnchor.constraint(equalTo: leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: trailingAnchor),
            underline.bottomAnchor.constraint(equalTo: bottomAnchor),
            underline.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var onReturn: (() -> Void)?

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        guard let swap = Range(range, in: current) else { return false }
        return current.replacingCharacters(in: swap, with: string).count <= PlayerProfile.maxNameLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn?()
        return false
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        underline.backgroundColor = became ? MPTheme.amber : MPTheme.borderStrong
        return became
    }

    override func resignFirstResponder() -> Bool {
        underline.backgroundColor = MPTheme.borderStrong
        return super.resignFirstResponder()
    }
}

// MARK: - First launch

/// Asked once, before any game: a name, or skip and play as a guest.
final class OnboardingViewController: UIViewController {

    var onFinish: (() -> Void)?

    private let backdrop = MPPageBackgroundView()
    private let field = ProfileNameField(size: 30)
    private let continueButton = MPPrimaryButton(title: "Continue")
    private let skipButton = UIButton(type: .system)
    private let guestName = PlayerProfile.guestName

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        isModalInPresentation = true

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        let logo = UIImageView(image: UIImage(named: "TokiyoCards"))
        logo.contentMode = .scaleAspectFit
        logo.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "What should we\ncall you?"
        title.numberOfLines = 0
        title.font = MPFont.display(34, weight: .medium)
        title.textColor = MPTheme.ink

        let caption = UILabel()
        caption.text = "Friends see this at the table. You can change it any time in Profile."
        caption.numberOfLines = 0
        caption.font = MPFont.ui(14)
        caption.textColor = MPTheme.muted

        field.text = PlayerProfile.suggestedName
        field.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        field.onReturn = { [weak self] in self?.didTapContinue() }

        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)
        skipButton.setTitle("Skip — play as \(guestName)", for: .normal)
        skipButton.titleLabel?.font = MPFont.ui(15, weight: .semibold)
        skipButton.tintColor = MPTheme.muted
        skipButton.addTarget(self, action: #selector(didTapSkip), for: .touchUpInside)

        let form = UIStackView(arrangedSubviews: [title, field, caption])
        form.axis = .vertical
        form.spacing = 14
        form.setCustomSpacing(28, after: title)
        form.translatesAutoresizingMaskIntoConstraints = false

        let actions = UIStackView(arrangedSubviews: [continueButton, skipButton])
        actions.axis = .vertical
        actions.spacing = 8
        actions.translatesAutoresizingMaskIntoConstraints = false

        [logo, form, actions].forEach { view.addSubview($0) }
        let safe = view.safeAreaLayoutGuide
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            logo.topAnchor.constraint(equalTo: safe.topAnchor, constant: 20),
            logo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logo.heightAnchor.constraint(equalToConstant: 64),
            logo.widthAnchor.constraint(equalToConstant: 140),

            form.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 48),
            form.leadingAnchor.constraint(equalTo: readable.leadingAnchor, constant: 8),
            form.trailingAnchor.constraint(equalTo: readable.trailingAnchor, constant: -8),

            actions.leadingAnchor.constraint(equalTo: form.leadingAnchor),
            actions.trailingAnchor.constraint(equalTo: form.trailingAnchor),
            actions.topAnchor.constraint(greaterThanOrEqualTo: form.bottomAnchor, constant: 24),
            // Rides above the keyboard while typing, sits at the bottom otherwise.
            actions.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12)
        ])
        nameChanged()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        field.becomeFirstResponder()
    }

    @objc private func nameChanged() {
        let typed = field.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        continueButton.isEnabled = !typed.isEmpty
    }

    @objc private func didTapContinue() {
        guard continueButton.isEnabled else { return }
        finish(name: field.text)
    }

    @objc private func didTapSkip() {
        finish(name: guestName)
    }

    private func finish(name: String?) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        PlayerProfile.completeOnboarding(name: name)
        view.endEditing(true)
        dismiss(animated: true) { [onFinish] in onFinish?() }
    }
}

// MARK: - Profile

/// Photo and name. Opened from Home; the photo stays on this phone.
final class ProfileViewController: UIViewController, PHPickerViewControllerDelegate {

    private let avatar = ProfileAvatarView(diameter: 120)
    private let photoButton = UIButton(type: .system)
    private let field = ProfileNameField(size: 24)

    /// Wraps itself in a navigation controller, as a sheet.
    static func sheet() -> UIViewController {
        let nav = UINavigationController(rootViewController: ProfileViewController())
        nav.navigationBar.tintColor = MPTheme.tint
        nav.modalPresentationStyle = .pageSheet
        nav.sheetPresentationController?.prefersGrabberVisible = true
        return nav
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        title = "Profile"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.close()
        })

        avatar.followsProfile = true
        let camera = UIImageView(image: UIImage(systemName: "camera.fill",
                                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        camera.tintColor = MPTheme.primaryActionText
        camera.contentMode = .center
        camera.backgroundColor = MPTheme.amber
        camera.layer.cornerRadius = 17
        camera.layer.borderWidth = 3
        camera.translatesAutoresizingMaskIntoConstraints = false

        // The avatar and its badge open the same menu as the text button.
        let avatarHit = UIButton(type: .custom)
        avatarHit.translatesAutoresizingMaskIntoConstraints = false
        avatarHit.showsMenuAsPrimaryAction = true
        avatarHit.accessibilityLabel = "Profile photo"

        photoButton.translatesAutoresizingMaskIntoConstraints = false
        photoButton.titleLabel?.font = MPFont.ui(15, weight: .semibold)
        photoButton.tintColor = MPTheme.tint
        photoButton.showsMenuAsPrimaryAction = true

        let eyebrow = MPSectionEyebrowLabel(text: "Name")
        field.text = PlayerProfile.name
        field.onReturn = { [weak self] in self?.view.endEditing(true) }
        field.addTarget(self, action: #selector(saveName), for: .editingDidEnd)

        let note = UILabel()
        note.text = "Shown to other players at the table. Your photo stays on this phone."
        note.numberOfLines = 0
        note.font = MPFont.ui(13)
        note.textColor = MPTheme.muted

        let nameBlock = UIStackView(arrangedSubviews: [eyebrow, field, note])
        nameBlock.axis = .vertical
        nameBlock.spacing = 6
        nameBlock.setCustomSpacing(12, after: field)
        nameBlock.translatesAutoresizingMaskIntoConstraints = false

        // Cards: one row per game, each opening its own deck picker.
        let cardsEyebrow = MPSectionEyebrowLabel(text: "Cards")
        let cardsNote = UILabel()
        cardsNote.text = "Each game keeps its own deck."
        cardsNote.font = MPFont.ui(13)
        cardsNote.textColor = MPTheme.muted
        let cardsBlock = UIStackView(arrangedSubviews: [cardsEyebrow, gameRows(), cardsNote])
        cardsBlock.axis = .vertical
        cardsBlock.spacing = 10
        cardsBlock.translatesAutoresizingMaskIntoConstraints = false

        // Everything scrolls, so the sheet works at any height.
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        [avatar, camera, avatarHit, photoButton, nameBlock, cardsBlock].forEach { content.addSubview($0) }
        let readable = content.readableContentGuide
        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            avatar.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            camera.widthAnchor.constraint(equalToConstant: 34),
            camera.heightAnchor.constraint(equalToConstant: 34),
            camera.trailingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 2),
            camera.bottomAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 2),
            avatarHit.topAnchor.constraint(equalTo: avatar.topAnchor),
            avatarHit.bottomAnchor.constraint(equalTo: camera.bottomAnchor),
            avatarHit.leadingAnchor.constraint(equalTo: avatar.leadingAnchor),
            avatarHit.trailingAnchor.constraint(equalTo: camera.trailingAnchor),

            photoButton.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 12),
            photoButton.centerXAnchor.constraint(equalTo: content.centerXAnchor),

            nameBlock.topAnchor.constraint(equalTo: photoButton.bottomAnchor, constant: 32),
            nameBlock.leadingAnchor.constraint(equalTo: readable.leadingAnchor, constant: 8),
            nameBlock.trailingAnchor.constraint(equalTo: readable.trailingAnchor, constant: -8),

            cardsBlock.topAnchor.constraint(equalTo: nameBlock.bottomAnchor, constant: 36),
            cardsBlock.leadingAnchor.constraint(equalTo: nameBlock.leadingAnchor),
            cardsBlock.trailingAnchor.constraint(equalTo: nameBlock.trailingAnchor),
            cardsBlock.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -32)
        ])

        refreshPhotoMenu(targets: [avatarHit, photoButton])
        NotificationCenter.default.addObserver(forName: PlayerProfile.didChange, object: nil, queue: .main) { [weak self, weak avatarHit] _ in
            guard let self, let avatarHit else { return }
            self.refreshPhotoMenu(targets: [avatarHit, self.photoButton])
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: ProfileViewController, _: UITraitCollection) in
            camera.layer.borderColor = MPTheme.pageBg.resolvedColor(with: controller.traitCollection).cgColor
        }
        camera.layer.borderColor = MPTheme.pageBg.resolvedColor(with: traitCollection).cgColor
    }

    private func gameRows() -> UIView {
        let box = UIStackView()
        box.axis = .vertical
        box.backgroundColor = MPTheme.glassWeak
        box.layer.cornerRadius = 16
        box.layer.cornerCurve = .continuous
        box.clipsToBounds = true
        for (index, game) in CardGame.allCases.enumerated() {
            if index > 0 {
                let rule = UIView()
                rule.backgroundColor = MPTheme.glassDivider
                rule.heightAnchor.constraint(equalToConstant: 1).isActive = true
                box.addArrangedSubview(rule)
            }
            let row = ProfileCardRow(game: game)
            row.addAction(UIAction { [weak self] _ in
                self?.navigationController?.pushViewController(CardDesignPickerViewController(game: game), animated: true)
            }, for: .touchUpInside)
            box.addArrangedSubview(row)
        }
        return box
    }

    private func refreshPhotoMenu(targets: [UIButton]) {
        let hasPhoto = PlayerProfile.photo != nil
        var actions: [UIMenuElement] = [
            UIAction(title: hasPhoto ? "Choose a new photo" : "Choose photo",
                     image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in self?.pickPhoto() }
        ]
        if hasPhoto {
            actions.append(UIAction(title: "Remove photo", image: UIImage(systemName: "trash"),
                                    attributes: .destructive) { _ in PlayerProfile.setPhoto(nil) })
        }
        let menu = UIMenu(children: actions)
        targets.forEach { $0.menu = menu }
        photoButton.setTitle(hasPhoto ? "Change photo" : "Add a photo", for: .normal)
    }

    private func pickPhoto() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async { PlayerProfile.setPhoto(image) }
        }
    }

    @objc private func saveName() {
        if !PlayerProfile.setName(field.text ?? "") {
            field.text = PlayerProfile.name        // blank: keep the old name
        } else {
            field.text = PlayerProfile.name
        }
    }

    private func close() {
        view.endEditing(true)
        dismiss(animated: true)
    }
}

// MARK: - Cards

/// "Poker   [back] Classic ›" — one game's deck, in Profile.
private final class ProfileCardRow: UIControl {

    private let game: CardGame
    private let thumb: CardBackView
    private let value = UILabel()

    init(game: CardGame) {
        self.game = game
        thumb = CardBackView(design: PlayerProfile.cardDesign(for: game)) { $0 * 0.16 }
        super.init(frame: .zero)
        thumb.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = game.title
        title.font = MPFont.ui(16, weight: .semibold)
        title.textColor = MPTheme.ink
        value.font = MPFont.ui(15)
        value.textColor = MPTheme.muted
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = MPTheme.faint
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [title, UIView(), thumb, value, chevron])
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            thumb.widthAnchor.constraint(equalToConstant: 20),
            thumb.heightAnchor.constraint(equalToConstant: 28),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
        accessibilityTraits = .button
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: PlayerProfile.didChange, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func refresh() {
        let design = PlayerProfile.cardDesign(for: game)
        thumb.design = design
        value.text = design.title
        accessibilityLabel = "\(game.title) cards: \(design.title)"
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? MPTheme.glassDivider : .clear }
    }
}

/// One game's deck choice, shown with that game's own cards.
final class CardDesignPickerViewController: UIViewController {

    private let game: CardGame
    private var tiles: [CardDesignTile] = []

    init(game: CardGame) {
        self.game = game
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        title = "\(game.title) cards"

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for design in CardDesign.allCases {
            let tile = CardDesignTile(game: game, design: design)
            tile.addAction(UIAction { [weak self] _ in self?.choose(design) }, for: .touchUpInside)
            stack.addArrangedSubview(tile)
            tiles.append(tile)
        }
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: readable.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: readable.trailingAnchor, constant: -8)
        ])
        refresh()
    }

    private func choose(_ design: CardDesign) {
        UISelectionFeedbackGenerator().selectionChanged()
        PlayerProfile.setCardDesign(design, for: game)
        refresh()
    }

    private func refresh() {
        let current = PlayerProfile.cardDesign(for: game)
        tiles.forEach { $0.isSelected = $0.design == current }
    }
}

/// A design, previewed with a back and a face from the game itself.
final class CardDesignTile: UIControl {

    let design: CardDesign
    private let check = UIImageView()

    init(game: CardGame, design: CardDesign) {
        self.design = design
        super.init(frame: .zero)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5

        let preview = CardPreviewFan(cards: Self.previewCards(game: game, design: design))
        let title = UILabel()
        title.text = design.title
        title.font = MPFont.ui(17, weight: .semibold)
        title.textColor = MPTheme.ink
        let detail = UILabel()
        detail.text = design == game.defaultDesign ? "\(design.detail) · \(game.title)'s original" : design.detail
        detail.font = MPFont.ui(13)
        detail.textColor = MPTheme.muted
        detail.numberOfLines = 0
        let words = UIStackView(arrangedSubviews: [title, detail])
        words.axis = .vertical
        words.spacing = 3
        check.contentMode = .scaleAspectFit
        check.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [preview, words, check])
        row.spacing = 16
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            check.widthAnchor.constraint(equalToConstant: 24),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        accessibilityTraits = .button
        accessibilityLabel = "\(design.title). \(design.detail)"
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (tile: CardDesignTile, _: UITraitCollection) in
            tile.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isSelected: Bool { didSet { applyTheme() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }

    private func applyTheme() {
        backgroundColor = isSelected ? MPTheme.hostWash : MPTheme.glassWeak
        layer.borderColor = (isSelected ? MPTheme.amber : MPTheme.border).resolvedColor(with: traitCollection).cgColor
        check.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        check.tintColor = isSelected ? MPTheme.amber : MPTheme.faint
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    /// A back and a king of hearts, drawn by the game's own card view.
    static func previewCards(game: CardGame, design: CardDesign) -> [UIView] {
        let king = Card(suit: .hearts, rank: .king)
        switch game {
        case .poker:
            let back = CardView()
            back.design = design
            back.setCard(Card(suit: .spades, rank: .ace), faceUp: false)
            let face = CardView()
            face.design = design
            face.style = .hero
            face.setCard(king)
            return [back, face]
        case .teenDoPaanch:
            return [TDPCardButton(card: nil, faceDown: true, design: design),
                    TDPCardButton(card: king, design: design)]
        }
    }
}

/// Two cards leaning on each other.
private final class CardPreviewFan: UIView {

    private let cards: [UIView]

    init(cards: [UIView]) {
        self.cards = cards
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        cards.forEach { addSubview($0) }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 104),
            heightAnchor.constraint(equalToConstant: 92)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = CGSize(width: 54, height: 54 * 100 / 70)
        for (i, card) in cards.enumerated() {
            let offset = CGFloat(i) - CGFloat(cards.count - 1) / 2
            card.transform = .identity
            card.bounds = CGRect(origin: .zero, size: size)
            card.center = CGPoint(x: bounds.midX + offset * 26, y: bounds.midY + abs(offset) * 2)
            card.transform = CGAffineTransform(rotationAngle: offset * 12 * .pi / 180)
        }
    }
}
