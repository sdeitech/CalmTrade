//
//  CalendarViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/11/25.
//

import UIKit
import KRProgressHUD

final class CalendarViewController: UIViewController {

    @IBOutlet weak var monthLabel: UILabel!
    @IBOutlet weak var pnlLabel: UILabel!
    @IBOutlet weak var calmLabel: UILabel!
    @IBOutlet weak var tradesLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!

    private let vm = CalendarViewModel()
    private var selectedDate: Date = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        bindViewModel()

        let comp = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        if let m = comp.month, let y = comp.year {
            monthLabel.text = DateFormatter().monthSymbols[m - 1] + " \(y)"
            vm.load(month: m, year: y)
        }
    }

    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    private func bindViewModel() {

        vm.onLoading = { loading in
            loading ? KRProgressHUD.show() : KRProgressHUD.dismiss()
        }

        vm.onData = { [weak self] data in
            guard let self else { return }

            self.monthLabel.text = data.month
            self.pnlLabel.text = "\(data.summary.monthlyPnL)"
            self.calmLabel.text = String(format: "%.2f", data.summary.avgCalmScore)
            self.tradesLabel.text = "\(data.summary.totalTrades)"

            self.collectionView.reloadData()
        }

        vm.onError = { [weak self] message in
            let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }

    // MARK: - Calendar Picker
    @IBAction func btnCalendarTapped(_ sender: UIButton) {
        let pickerVC = UIViewController()
        pickerVC.preferredContentSize = CGSize(width: 320, height: 250)

        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = .current
        picker.date = selectedDate

        picker.addTarget(self, action: #selector(monthChanged(_:)), for: .valueChanged)

        pickerVC.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor),
            picker.topAnchor.constraint(equalTo: pickerVC.view.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pickerVC.view.bottomAnchor)
        ])

        pickerVC.modalPresentationStyle = .popover
        if let popover = pickerVC.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
            popover.permittedArrowDirections = .up
            popover.delegate = self
        }

        present(pickerVC, animated: true)
    }

    @objc private func monthChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date

        let comp = Calendar.current.dateComponents([.year, .month], from: sender.date)
        guard let month = comp.month, let year = comp.year else { return }

        let name = DateFormatter().monthSymbols[month - 1]
        monthLabel.text = "\(name) \(year)"

        vm.load(month: month, year: year)
    }
}

extension CalendarViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
}

// MARK: - CollectionView
extension CalendarViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        vm.numberOfWeeks()
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        6  // Mon–Fri + Total
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "DayCell",
            for: indexPath
        ) as! DayCell

        let week = vm.week(at: indexPath.section)
        let item = vm.weekItems(for: week)[indexPath.item]

        cell.configure(item: item)
        return cell
    }

    // 6-column layout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let width = collectionView.frame.width / 6
        return CGSize(width: width, height: 95)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat { 0 }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 0 }
}
