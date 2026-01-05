//
//  FTUSetupViewControllerDelegate.swift
//  CalmTrade
//
//  Created by Anas Parekh on 15/10/25.
//


// FTUSetupViewController.swift
import UIKit

protocol FTUSetupViewControllerDelegate: AnyObject {
    func ftuSetupViewControllerDidCancel(_ vc: FTUSetupViewController)
    func ftuSetupViewController(_ vc: FTUSetupViewController, didFinishWith form: FTUFormData)
}

final class FTUSetupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    weak var delegate: FTUSetupViewControllerDelegate?

    private var form = FTUFormData(gender: .male)
    private let table = UITableView(frame: .zero, style: .insetGrouped)

    // pickers
    private let genderPicker = UIPickerView()
    private let trainingPicker = UIPickerView()
    private let typicalPicker = UIPickerView()
    private let birthPicker = UIDatePicker()

    // backing text fields (for pickers-as-inputView)
    private let genderField = UITextField()
    private let trainingField = UITextField()
    private let typicalField = UITextField()
    private let birthField = UITextField()
    private let heightField = UITextField()
    private let weightField = UITextField()
    private let rhrField = UITextField()
    private let vo2Field = UITextField()
    private let maxHrField = UITextField()
    private let sleepField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Set up your device"
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.delegate?.ftuSetupViewControllerDidCancel(self)
        })

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Continue", style: .done, target: self, action: #selector(continueTapped))

        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        view.addSubview(table)
        table.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        configureInputs()
        preloadDisplayText()
    }

    private func configureInputs() {
        [heightField, weightField, rhrField, vo2Field, maxHrField, sleepField].forEach {
            $0.keyboardType = .numberPad
            $0.delegate = self
        }

        // pickers
        [genderPicker, trainingPicker, typicalPicker].forEach {
            $0.dataSource = self
            $0.delegate = self
        }

        birthPicker.datePickerMode = .date
        birthPicker.maximumDate = Date()
        birthPicker.preferredDatePickerStyle = .wheels
        birthPicker.addTarget(self, action: #selector(birthChanged), for: .valueChanged)

        // assign as inputViews
        genderField.inputView = genderPicker
        trainingField.inputView = trainingPicker
        typicalField.inputView = typicalPicker
        birthField.inputView = birthPicker

        // toolbars
        let tb = makeToolbar()
        [genderField, trainingField, typicalField, birthField,
         heightField, weightField, rhrField, vo2Field, maxHrField, sleepField].forEach {
            $0.inputAccessoryView = tb
        }
    }

    private func preloadDisplayText() {
        genderField.text = form.gender.rawValue
        trainingField.text = form.training.rawValue.capitalized
        typicalField.text = {
            switch form.typicalDay {
            case .mostlySitting: return "Mostly sitting"
            case .mixed: return "Mixed"
            case .mostlyMoving: return "Mostly moving"
            }
        }()
        birthChanged()
        heightField.text = "\(Int(form.heightCm))"
        weightField.text = "\(Int(form.weightKg))"
        rhrField.text    = "\(form.restingHR)"
        vo2Field.text    = "\(form.vo2Max)"
        maxHrField.text  = "" // leave empty; shows computed hint
        sleepField.text  = "\(form.sleepGoalMinutes)"
    }

    @objc private func birthChanged() {
        form.birthDate = birthPicker.date
        let df = DateFormatter(); df.dateStyle = .medium
        birthField.text = df.string(from: form.birthDate)
    }

    @objc private func continueTapped() {
        view.endEditing(true)

        // Locale-aware parsing helpers
        func f(_ t: String?) -> Float? {
            guard let s = t?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
            let nf = NumberFormatter()
            nf.locale = .current
            return nf.number(from: s)?.floatValue
        }
        func i(_ t: String?) -> Int? {
            guard let s = t?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
            let nf = NumberFormatter()
            nf.locale = .current
            return nf.number(from: s)?.intValue
        }

        // Pull latest from fields
        form.heightCm        = f(heightField.text) ?? form.heightCm
        form.weightKg        = f(weightField.text) ?? form.weightKg
        form.restingHR       = i(rhrField.text)    ?? form.restingHR
        form.vo2Max          = i(vo2Field.text)    ?? form.vo2Max
        form.maxHR           = i(maxHrField.text)  // keep nil if empty
        form.sleepGoalMinutes = i(sleepField.text) ?? form.sleepGoalMinutes

        // Validate (this will also normalize)
        if !form.validate() {
            let msg = form.validationErrors.first ?? "Please review your values."
            showInlineError(msg)
            return
        }

        // Proceed
        delegate?.ftuSetupViewController(self, didFinishWith: form)
    }

    private func makeToolbar() -> UIToolbar {
        let tb = UIToolbar()
        tb.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(endEditingNow))
        ]
        tb.sizeToFit()
        return tb
    }

    @objc private func endEditingNow() { view.endEditing(true) }

    private func showInlineError(_ message: String) {
        let ac = UIAlertController(title: "Check your info", message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
    }

    // MARK: - Table

    enum Row: Int, CaseIterable {
        case gender, birth, height, weight, restingHr, vo2, maxHr, training, typical, sleep
    }

    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "ftu.cell"
        let cell = tableView.dequeueReusableCell(withIdentifier: id) ?? UITableViewCell(style: .value1, reuseIdentifier: id)
        cell.selectionStyle = .none

        func attach(_ tf: UITextField) {
            tf.translatesAutoresizingMaskIntoConstraints = false
            tf.textAlignment = .right
            tf.placeholder = "—"
            if cell.contentView.subviews.contains(tf) == false {
                cell.contentView.addSubview(tf)
                NSLayoutConstraint.activate([
                    tf.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    tf.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                ])
            }
        }

        switch Row(rawValue: indexPath.row)! {
        case .gender:
            cell.textLabel?.text = "Gender"
            attach(genderField)
        case .birth:
            cell.textLabel?.text = "Birth date"
            attach(birthField)
        case .height:
            cell.textLabel?.text = "Height (cm)"
            attach(heightField)
        case .weight:
            cell.textLabel?.text = "Weight (kg)"
            attach(weightField)
        case .restingHr:
            cell.textLabel?.text = "Resting HR"
            attach(rhrField)
        case .vo2:
            cell.textLabel?.text = "VO₂max"
            attach(vo2Field)
        case .maxHr:
            cell.textLabel?.text = "Max HR"
            attach(maxHrField)
            cell.detailTextLabel?.text = "Auto: \(form.computedMaxHR)"
        case .training:
            cell.textLabel?.text = "Training background"
            attach(trainingField)
        case .typical:
            cell.textLabel?.text = "Typical day"
            attach(typicalField)
        case .sleep:
            cell.textLabel?.text = "Sleep goal (min)"
            attach(sleepField)
        }
        return cell
    }

    // MARK: - Pickers
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch pickerView {
        case genderPicker:   return FTUFormData.Gender.allCases.count
        case trainingPicker: return FTUFormData.TrainingBackground.allCases.count
        case typicalPicker:  return FTUFormData.TypicalDay.allCases.count
        default: return 0
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch pickerView {
        case genderPicker:   return FTUFormData.Gender.allCases[row].rawValue
        case trainingPicker: return FTUFormData.TrainingBackground.allCases[row].rawValue.capitalized
        case typicalPicker:
            switch FTUFormData.TypicalDay.allCases[row] {
            case .mostlySitting: return "Mostly sitting"
            case .mixed: return "Mixed"
            case .mostlyMoving: return "Mostly moving"
            }
        default: return nil
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerView {
        case genderPicker:
            form.gender = FTUFormData.Gender.allCases[row]
            genderField.text = form.gender.rawValue
        case trainingPicker:
            form.training = FTUFormData.TrainingBackground.allCases[row]
            trainingField.text = form.training.rawValue.capitalized
        case typicalPicker:
            form.typicalDay = FTUFormData.TypicalDay.allCases[row]
            switch form.typicalDay {
            case .mostlySitting: typicalField.text = "Mostly sitting"
            case .mixed: typicalField.text = "Mixed"
            case .mostlyMoving: typicalField.text = "Mostly moving"
            }
        default: break
        }
    }
}
