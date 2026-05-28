//
//  ComingSoonViewController.swift
//  Tokiyo Casino
//
//  Production-safe placeholder for games that are still in development.
//

import UIKit

final class ComingSoonViewController: UIViewController {

    private let screenTitle: String
    private let screenSubtitle: String

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let titleBlock: MPTitleView
    private let messageLabel = UILabel()
    private let doneButton = MPPrimaryButton(title: "Back Home")

    init(title: String, subtitle: String) {
        self.screenTitle = title
        self.screenSubtitle = subtitle
        self.titleBlock = MPTitleView(
            eyebrow: "Coming Soon",
            title: title,
            subtitle: subtitle
        )
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    private func setupUI() {
        view.backgroundColor = MPTheme.pageBg

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleBlock)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "\(screenTitle) is not available in this build yet. \(screenSubtitle)"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = MPFont.ui(16, weight: .semibold)
        messageLabel.textColor = MPTheme.ink
        view.addSubview(messageLabel)

        doneButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(doneButton)
        doneButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            titleBlock.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 96),
            titleBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            messageLabel.topAnchor.constraint(equalTo: titleBlock.bottomAnchor, constant: 28),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let navigationController, navigationController.viewControllers.first !== self {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
