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
    private var gridColumns: CGFloat { 2 }
    private var sectionInsets: UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) } // because you already constrained the collectionView with 16 margins
    private var interItemSpacing: CGFloat { 16 }
    private var lineSpacing: CGFloat { 16 }


    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupCollection()
        setupSegment()
        
        viewModel.loadData { [weak self] in
            self?.collectionView.reloadData()
        }
    }
    
    private func setupCollection() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        
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
    }

    @IBAction func segmentedChanged(_ sender: UISegmentedControl) {
        viewModel.mode = sender.selectedSegmentIndex == 0 ? .daily : .weekly
        collectionView.reloadData()
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
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
            
            if indexPath.item == 0 {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: SleepScoreCollectionCell.identifier,
                    for: indexPath
                ) as! SleepScoreCollectionCell
                
                if let model = viewModel.model(at: 0) {
                    cell.configure(model: model)
                }
                return cell
            }
            
            else {
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: SleepScoreBreakdownCell.identifier,
                    for: indexPath
                ) as! SleepScoreBreakdownCell
                if let model = viewModel.model(at: 0) {
                    cell.configure(model: model)
                }
                return cell
            }
            
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
            let cellWidth = (width - 12) / 2
            if indexPath.item == 0 {
                return CGSize(width: cellWidth, height: 220)
            } else {
                return CGSize(width: cellWidth, height: 200)
            }
            
        case .weekly:
            
            let cellWidth = (width - 12) / 2
            return CGSize(width: cellWidth, height: cellWidth + 40)
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
}

