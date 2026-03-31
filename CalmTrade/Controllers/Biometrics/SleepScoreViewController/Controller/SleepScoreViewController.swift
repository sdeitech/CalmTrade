//
//  SleepScoreViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var dailyScrollView: UIScrollView!
    @IBOutlet weak var mainScoreContainerView: UIView!
    @IBOutlet weak var collectionView: UICollectionView!

    private let viewModel = SleepScoreViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        
        setupCollection()
        setupSegment()
        
        viewModel.loadData()
        configureDailyView()
        updateVisibleContent()
    }
    
    private func setupCollection() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(
            SleepScoreCollectionCell.self,
            forCellWithReuseIdentifier: SleepScoreCollectionCell.identifier
        )
    }
    
    private func setupSegment() {
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: "Daily", at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: "Weekly", at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = 0
    }
    
    private func configureDailyView() {
        dailyScrollView.backgroundColor = .clear
        mainScoreContainerView.backgroundColor = .clear
        
        guard let model = viewModel.dailyModel else { return }
        
        SleepScoreViewModel.makeSleepScoreRing(
            in: mainScoreContainerView,
            score: model.score,
            centerFontSize: 44
        )
    }
    
    private func updateVisibleContent() {
        let isDailySelected = segmentedControl.selectedSegmentIndex == 0
        
        dailyScrollView.isHidden = !isDailySelected
        collectionView.isHidden = isDailySelected
        
        if isDailySelected {
            configureDailyView()
        } else {
            collectionView.reloadData()
        }
    }

    @IBAction func segmentedChanged(_ sender: UISegmentedControl) {
        viewModel.mode = sender.selectedSegmentIndex == 0 ? .daily : .weekly
        updateVisibleContent()
    }
    
    @IBAction func btnBackTapped(_ sender: Any) {
        navigationController?.popViewController()
    }
}

extension SleepScoreViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard viewModel.mode == .weekly else { return 0 }
        return viewModel.weeklyModels.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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

extension SleepScoreViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = max(collectionView.bounds.width, 24)
        let cellWidth = max((availableWidth - 12) / 2, 1)
        return CGSize(width: cellWidth, height: cellWidth + 40)
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
