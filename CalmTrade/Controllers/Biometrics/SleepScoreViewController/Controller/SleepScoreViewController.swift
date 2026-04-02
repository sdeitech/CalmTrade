//
//  SleepScoreViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var collectionView: UICollectionView!

    private let viewModel = SleepScoreViewModel()
    private var lastCollectionViewSize: CGSize = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupCollection()
        setupSegment()
        
        viewModel.loadData { [weak self] in
            self?.refreshCollectionLayout(animated: false)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let currentSize = collectionView.bounds.size
        guard currentSize != .zero, currentSize != lastCollectionViewSize else { return }
        lastCollectionViewSize = currentSize
        refreshCollectionLayout(animated: false)
    }
    
    private func setupCollection() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.estimatedItemSize = .zero
        }
        
        collectionView.register(
            SleepScoreCollectionCell.self,
            forCellWithReuseIdentifier: SleepScoreCollectionCell.identifier
        )
        collectionView.register(
            SleepScoreBreakdownCell.self,
            forCellWithReuseIdentifier: SleepScoreBreakdownCell.identifier
        )
    }
    
    private func setupSegment() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Daily", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Weekly", at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor("1C1C1F")
        segmentedControl.selectedSegmentTintColor = UIColor("2494FF")
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .normal)
        segmentedControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .bold)
        ], for: .selected)
        segmentedControl.layer.cornerRadius = 12
        segmentedControl.clipsToBounds = true
    }

    @IBAction func segmentedChanged(_ sender: UISegmentedControl) {
        viewModel.mode = sender.selectedSegmentIndex == 0 ? .daily : .weekly
        refreshCollectionLayout(animated: false)
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
    
    private func refreshCollectionLayout(animated: Bool) {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        
        let updates = {
            self.collectionView.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }
}

extension SleepScoreViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.numberOfItems()
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch viewModel.mode {
            
        case .daily:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: SleepScoreBreakdownCell.identifier,
                for: indexPath
            ) as! SleepScoreBreakdownCell
            if let model = viewModel.model(at: 0) {
                cell.configure(model: model)
            }
            return cell
            
        case .weekly:
            
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: SleepScoreCollectionCell.identifier,
                for: indexPath
            ) as! SleepScoreCollectionCell
            
            if let model = viewModel.model(at: indexPath.item) {
                cell.configure(model: model)
            }
            return cell
        }
    }
}

extension SleepScoreViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let width = collectionView.bounds.width

        switch viewModel.mode {
            
        case .daily:
            return CGSize(width: width, height: 718)
            
        case .weekly:
            
            let cellWidth = (width - 12) / 2
            return CGSize(width: cellWidth, height: 214)
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 12
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard viewModel.mode == .weekly,
              let model = viewModel.model(at: indexPath.item) else { return }
        
        let detailViewController = SleepScoreDetailViewController(model: model)
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}
