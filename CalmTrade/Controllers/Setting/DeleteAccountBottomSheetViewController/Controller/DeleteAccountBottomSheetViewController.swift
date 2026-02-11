//
//  DeleteAccountBottomSheetViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 03/02/26.
//


import UIKit

final class DeleteAccountBottomSheetViewController: UIViewController {

    var onConfirm: (() -> Void)?

    private let containerView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        containerView.backgroundColor = UIColor(hex: "2D2D2D")
        containerView.layer.cornerRadius = 20
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Icon
        let icon = UIImageView(image: UIImage(systemName: "trash.fill"))
        icon.tintColor = UIColor(hex: "FF006E")
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 40).isActive = true

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Delete Account?"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white

        // Message
        let messageLabel = UILabel()
        messageLabel.text = "Are you sure you want to delete your account? This action cannot be undone."
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        // Buttons
        let deleteButton = UIButton(type: .system)
        deleteButton.setTitle("Delete Account", for: .normal)
        deleteButton.backgroundColor = UIColor(hex: "FF006E")
        deleteButton.layer.cornerRadius = 10
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = UIColor(hex: "3A3A3A")
        cancelButton.layer.cornerRadius = 10
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [deleteButton, cancelButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            icon,
            titleLabel,
            messageLabel,
            buttonStack
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func confirmTapped() {
        dismiss(animated: true) {
            self.onConfirm?()
        }
    }
}
