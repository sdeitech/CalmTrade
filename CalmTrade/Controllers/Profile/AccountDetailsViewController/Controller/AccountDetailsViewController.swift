//
//  AccountDetailsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//

import UIKit

final class AccountDetailsViewController: UIViewController {

    // MARK: - Outlets (connect from storyboard)
    @IBOutlet private weak var displayNameLabel: UILabel!
    @IBOutlet private weak var emailLabel: UILabel!
    @IBOutlet private weak var ageLabel: UILabel!
    @IBOutlet private weak var sexLabel: UILabel!
    @IBOutlet private weak var restingHRLabel: UILabel!
    @IBOutlet private weak var maxHRLabel: UILabel!

    @IBOutlet private weak var userIdLabel: UILabel!
    @IBOutlet private weak var createdOnLabel: UILabel!
    @IBOutlet private weak var lastSignInLabel: UILabel!

    @IBOutlet private weak var heightLabel: UILabel!
    @IBOutlet private weak var weightLabel: UILabel!

    private var viewModel: AccountDetailsViewModel!

    // Inject your token before presenting this VC
    public func configure(accessToken: String) {
        // VM convenience init uses Polar360MetricsCenter.shared internally
        self.viewModel = AccountDetailsViewModel(accessToken: accessToken)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        assert(viewModel != nil, "Call configure(accessToken:) before presenting AccountDetailsViewController")
        bind()
        viewModel.load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure HealthKit bootstrap is started (safe to call multiple times)
        Polar360MetricsCenter.shared.startHealthKitBootstrap()
    }

    private func bind() {
        viewModel.onLoading = { [weak self] loading in
            guard let self = self else { return }
            self.view.isUserInteractionEnabled = !loading
            // Optional: show/hide spinner if you have one
            self.navigationItem.hidesBackButton = loading  // avoid bouncy back taps while loading
        }
        viewModel.onUI = { [weak self] ui in
            self?.apply(ui)
        }
        viewModel.onError = { [weak self] msg in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private func apply(_ ui: AccountDetailsUI) {
        displayNameLabel.text = ui.displayName
        emailLabel.text       = ui.email

        ageLabel.text         = ui.ageText
        sexLabel.text         = ui.sexText
        restingHRLabel.text   = ui.rhrText
        maxHRLabel.text       = ui.maxHRText

        userIdLabel.text      = ui.userId
        createdOnLabel.text   = ui.createdOn
        lastSignInLabel.text  = ui.lastSignIn

        heightLabel.text      = ui.heightText
        weightLabel.text      = ui.weightText
    }
    
    // MARK: - Actions
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
