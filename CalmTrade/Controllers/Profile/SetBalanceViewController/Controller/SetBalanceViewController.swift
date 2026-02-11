//
//  SetBalanceViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 29/10/25.
//

import UIKit

final class SetBalanceViewController: BaseViewController, UITextFieldDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var lblTitle: UILabel!

    @IBOutlet private weak var accountNameLabel: UILabel!
    @IBOutlet private weak var currentBalanceLabel: UILabel!   // read-only

    // Starting Balance (editable)
    @IBOutlet private weak var viewStarting: UIView!
    @IBOutlet private weak var lblStarting: UILabel!
    @IBOutlet private weak var startingBalanceTextField: UITextField!

    // OPTIONAL: Edit Current Balance (editable override). If unused, remove these 3 outlets.
    @IBOutlet private weak var viewEditCurrent: UIView!
    @IBOutlet private weak var lblEditCurrent: UILabel!
    @IBOutlet private weak var currentBalanceTextField: UITextField!

    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var viewInfo: UIView!

    // MARK: - Colors (same as Login)
    private let focusedColor = UIColor(named: "selectedTextfieldColor")
    private let normalColor  = UIColor(named: "unselectedTextFieldColor")

    // Inject your VM before presenting
    lazy var viewModel: SetBalanceViewModel = {
        let obj = SetBalanceViewModel()
        self.baseVwModel = obj
        return obj
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // TextField delegates + keyboard
        startingBalanceTextField.delegate = self
        startingBalanceTextField.keyboardType = .decimalPad

        currentBalanceTextField.keyboardType = .decimalPad
        currentBalanceTextField.delegate = self

        // Initial unfocused state (like Login)
        updateUI(for: viewStarting, label: lblStarting, isFocused: false)
        if let v = viewEditCurrent, let l = lblEditCurrent {
            updateUI(for: v, label: l, isFocused: false)
        }

        wireVM()
        viewModel.load()
    }

    private func wireVM() {
        viewModel.onLoading = { [weak self] loading in
            self?.saveButton.isEnabled = !loading
            self?.saveButton.alpha = loading ? 0.6 : 1.0
        }
        viewModel.onUI = { [weak self] ui in
            guard let self = self else { return }
            self.accountNameLabel.text = ui.accountName
            self.currentBalanceLabel.text = ui.calculatedCurrentBalanceText   // "—" for now
            self.startingBalanceTextField.text = ui.startingBalanceText.isEmpty ? "" : "$" + ui.startingBalanceText
            self.currentBalanceTextField.text = ui.brokerCurrentBalanceText.isEmpty ? "" : "$" + ui.brokerCurrentBalanceText
        }
        viewModel.onToast = { [weak self] msg in self?.toast(msg) }
        viewModel.onError = { [weak self] msg in self?.toast(msg) }
    }

    // MARK: - Actions
    @IBAction private func didTapSave(_ sender: UIButton) {
        let name = accountNameLabel.text ?? "—"
        viewModel.saveStartingBalance(from: startingBalanceTextField.text ?? "$",
                                      accountName: name,
                                      currency: "USD",
                                      timezone: TimeZone.current.identifier,
                                      broker: "Manual", brokerCurrentBalance: currentBalanceTextField.text ?? "$")
    }

    @IBAction private func didTapBack(_ sender: UIButton) {
        navigationController?.popViewController()
    }

    @IBAction private func didTapInfo(_ sender: UIButton) { viewInfo.isHidden = false }
    @IBAction private func didTapOkInfo(_ sender: UIButton) { viewInfo.isHidden = true }
    @IBAction private func didTapBrokerCurrentBalanceInfo(_ sender: UIButton) {
        let title = "About Broker Current Balance"
        let message = """
        This value is synced from your broker and updates automatically. It’s shown for your reference and reconciliation only—CalmTrade does not use this number in any calculations.
        
        Your CalmTrade balance is calculated from your starting balance plus imported trades, minus fees, commissions, and other adjustments
        """

        // Create popover-style alert
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        // Required for iPad / popover
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
            popover.permittedArrowDirections = [.up, .down]
        }

        alert.addAction(UIAlertAction(title: "Got it", style: .default))
        present(alert, animated: true)
    }
    


    // MARK: - UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === startingBalanceTextField {
            updateUI(for: viewStarting, label: lblStarting, isFocused: true)
        } else if textField === currentBalanceTextField {
            if let v = viewEditCurrent, let l = lblEditCurrent { updateUI(for: v, label: l, isFocused: true) }
        }

        // “field starts with $” rule
        if (textField.text ?? "").isEmpty {
            textField.text = "$"
            placeCursorAfterDollar(textField)
        }
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === startingBalanceTextField {
            updateUI(for: viewStarting, label: lblStarting, isFocused: false)
        } else if textField === currentBalanceTextField {
            if let v = viewEditCurrent, let l = lblEditCurrent { updateUI(for: v, label: l, isFocused: false) }
        }
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let t = textField.text, let r = Range(range, in: t) else { return true }

        // Prevent deleting the first "$"
        if r.lowerBound == t.startIndex, r.upperBound > r.lowerBound, t.hasPrefix("$") {
            return false
        }

        // If result would become empty → keep "$"
        let newText = t.replacingCharacters(in: r, with: string)
        if newText.isEmpty {
            textField.text = "$"
            placeCursorAfterDollar(textField)
            return false
        }

        // If user types before "$", push cursor after "$"
        if newText.first != "$" {
            textField.text = "$" + newText
            placeCursorAfterDollar(textField)
            return false
        }

        return true
    }

    // MARK: - Helpers
    private func updateUI(for view: UIView?, label: UILabel?, isFocused: Bool) {
        let color = isFocused ? focusedColor : normalColor
        UIView.animate(withDuration: 0.25) {
            view?.borderColor = color
            label?.textColor = color
        }
    }

    private func placeCursorAfterDollar(_ tf: UITextField) {
        guard let txt = tf.text else { return }
        if let pos = tf.position(from: tf.beginningOfDocument, offset: min(1, txt.count)) {
            tf.selectedTextRange = tf.textRange(from: pos, to: pos)
        }
    }

    private func toast(_ message: String) {
        let ac = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(ac, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak ac] in ac?.dismiss(animated: true) }
    }
    
    private func showTooltip(from anchor: UIView) {
        let tooltipVC = UIViewController()
        tooltipVC.modalPresentationStyle = .popover
        tooltipVC.preferredContentSize = CGSize(width: 280, height: 150)

        let label = UILabel()
        label.numberOfLines = 0
        label.text = """
        This value is for your reference only. CalmTrade does not sync with your broker or use this number in any calculations.

        Your CalmTrade balance is calculated from your starting balance plus imported trades, minus fees, commissions, and other adjustments.
        """
        label.font = .systemFont(ofSize: 14)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.15, alpha: 0.9)
        label.layer.cornerRadius = 10
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        tooltipVC.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: tooltipVC.view.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: tooltipVC.view.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: tooltipVC.view.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: tooltipVC.view.bottomAnchor, constant: -8)
        ])

        if let popover = tooltipVC.popoverPresentationController {
            popover.sourceView = anchor
            popover.sourceRect = anchor.bounds
            popover.permittedArrowDirections = [.up, .down]
        }

        present(tooltipVC, animated: true)
    }
}
