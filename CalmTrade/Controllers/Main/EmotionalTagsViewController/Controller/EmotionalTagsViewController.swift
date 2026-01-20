//
//  EmotionalTagsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 28/08/25.
//

import UIKit

class EmotionalTagsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    // MARK: - Outlets
    
    @IBOutlet weak var positiveCollectionView: UICollectionView!
    @IBOutlet weak var negativeCollectionView: UICollectionView!
    @IBOutlet weak var neutralCollectionView: UICollectionView!
    @IBOutlet weak var cognitiveCollectionView: UICollectionView!
    
    @IBOutlet weak var positiveCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var negativeCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var neutralCollectionViewHeight: NSLayoutConstraint!
    @IBOutlet weak var cognitiveCollectionViewHeight: NSLayoutConstraint!
    
    // MARK: - Properties
    
    private let viewModel = EmotionalTagsViewModel()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView(positiveCollectionView)
        setupCollectionView(negativeCollectionView)
        setupCollectionView(neutralCollectionView)
        setupCollectionView(cognitiveCollectionView)

        bindViewModel()
        viewModel.fetchEmotionTags()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAllCollectionViewHeights()
    }

    // MARK: - Setup
    private func bindViewModel() {
        viewModel.onDataLoaded = { [weak self] in
            guard let self else { return }

            self.positiveCollectionView.reloadData()
            self.negativeCollectionView.reloadData()
            self.neutralCollectionView.reloadData()
            self.cognitiveCollectionView.reloadData()

            self.view.layoutIfNeeded()
            self.updateAllCollectionViewHeights()
        }
    }
    
    func setupCollectionView(_ collectionView: UICollectionView) {
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // **FIX**: Disable scrolling on the collection view since its height is dynamic.
        collectionView.isScrollEnabled = false
        
        let nib = UINib(nibName: "EmotionTagCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: EmotionTagCell.reuseIdentifier)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = 25
        layout.minimumLineSpacing = 20
        collectionView.collectionViewLayout = layout
    }
    
    //MARK: - Actions
    
    @IBAction func btnSubmitTapped(_ sender: Any) {
        let accountCreatedVC = UIStoryboard(name: Constants.Storyboard.Main, bundle: nil).instantiateViewController(withIdentifier: "AccountCreatedViewController") as! AccountCreatedViewController
        navigationController?.pushViewController(accountCreatedVC, transitionType: .fade)
    }
    
    // MARK: - Height Calculation
    
    func updateAllCollectionViewHeights() {
        updateCollectionViewHeight(positiveCollectionView, constraint: positiveCollectionViewHeight)
        updateCollectionViewHeight(negativeCollectionView, constraint: negativeCollectionViewHeight)
        updateCollectionViewHeight(neutralCollectionView, constraint: neutralCollectionViewHeight)
        updateCollectionViewHeight(cognitiveCollectionView, constraint: cognitiveCollectionViewHeight)
    }
    
    func updateCollectionViewHeight(_ collectionView: UICollectionView, constraint: NSLayoutConstraint) {
        constraint.constant = collectionView.collectionViewLayout.collectionViewContentSize.height
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == positiveCollectionView {
            return viewModel.positiveEmotions.count
        }
        if collectionView == negativeCollectionView {
            return viewModel.negativeEmotions.count
        }
        if collectionView == neutralCollectionView {
            return viewModel.neutralEmotions.count
        }
        if collectionView == cognitiveCollectionView {
            return viewModel.cognitiveEmotions.count
        }
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmotionTagCell.reuseIdentifier, for: indexPath) as! EmotionTagCell
        
        if collectionView == positiveCollectionView {
            let emotion = viewModel.positiveEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .init("#245E2B"))
            cell.updateSelection(isSelected: emotion.isSelected)
            cell.btnSelect.tag = indexPath.item
            cell.btnSelect.accessibilityHint = "positiveCollectionView"
        }
        
        if collectionView == negativeCollectionView {
            let emotion = viewModel.negativeEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .init("#B52D0B"))
            cell.updateSelection(isSelected: emotion.isSelected)
            cell.btnSelect.tag = indexPath.item
            cell.btnSelect.accessibilityHint = "negativeCollectionView"
        }
        
        if collectionView == neutralCollectionView {
            let emotion = viewModel.neutralEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .init("#F4B04C"))
            cell.updateSelection(isSelected: emotion.isSelected)
            cell.btnSelect.tag = indexPath.item
            cell.btnSelect.accessibilityHint = "neutralCollectionView"
        }
        
        if collectionView == cognitiveCollectionView {
            let emotion = viewModel.cognitiveEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .init("#B3E3FC"))
            cell.updateSelection(isSelected: emotion.isSelected)
            cell.btnSelect.tag = indexPath.item
            cell.btnSelect.accessibilityHint = "cognitiveCollectionView"
        }
        
        cell.btnSelect.addTarget(self, action: #selector(handleSelect), for: .touchUpInside)
        return cell
    }
    
    @objc func handleSelect(_ sender: UIButton) {

        let index = sender.tag

        switch sender.accessibilityHint {

        case "positiveCollectionView":
            viewModel.toggleSelection(category: .positive, index: index)
            positiveCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            updateCollectionViewHeight(positiveCollectionView, constraint: positiveCollectionViewHeight)

        case "negativeCollectionView":
            viewModel.toggleSelection(category: .negative, index: index)
            negativeCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            updateCollectionViewHeight(negativeCollectionView, constraint: negativeCollectionViewHeight)

        case "neutralCollectionView":
            viewModel.toggleSelection(category: .neutral, index: index)
            neutralCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            updateCollectionViewHeight(neutralCollectionView, constraint: neutralCollectionViewHeight)

        case "cognitiveCollectionView":
            viewModel.toggleSelection(category: .cognitive, index: index)
            cognitiveCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            updateCollectionViewHeight(cognitiveCollectionView, constraint: cognitiveCollectionViewHeight)

        default:
            break
        }
    }
}
