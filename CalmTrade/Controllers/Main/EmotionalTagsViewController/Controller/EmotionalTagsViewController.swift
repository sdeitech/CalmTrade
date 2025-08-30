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
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAllCollectionViewHeights()
    }

    // MARK: - Setup
    
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
        if sender.accessibilityHint == "positiveCollectionView" {
            let selectedEmotion = viewModel.positiveEmotions[sender.tag]
            viewModel.toggleSelection(for: selectedEmotion, in: positiveCollectionView)
            
            positiveCollectionView.reloadItems(at: [IndexPath(item: sender.tag, section: 0)])
            positiveCollectionView.layoutIfNeeded()

            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateCollectionViewHeight(self.positiveCollectionView, constraint: self.positiveCollectionViewHeight)
            }
        }
        
        if sender.accessibilityHint == "negativeCollectionView" {
            let selectedEmotion = viewModel.negativeEmotions[sender.tag]
            viewModel.toggleSelection(for: selectedEmotion, in: negativeCollectionView)
            
            negativeCollectionView.reloadItems(at: [IndexPath(item: sender.tag, section: 0)])
            negativeCollectionView.layoutIfNeeded()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateCollectionViewHeight(self.negativeCollectionView, constraint: self.negativeCollectionViewHeight)
            }
        }
        
        if sender.accessibilityHint == "neutralCollectionView" {
            let selectedEmotion = viewModel.neutralEmotions[sender.tag]
            viewModel.toggleSelection(for: selectedEmotion, in: neutralCollectionView)
            
            neutralCollectionView.reloadItems(at: [IndexPath(item: sender.tag, section: 0)])
            neutralCollectionView.layoutIfNeeded()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateCollectionViewHeight(self.neutralCollectionView, constraint: self.neutralCollectionViewHeight)
            }
        }
        
        if sender.accessibilityHint == "cognitiveCollectionView" {
            let selectedEmotion = viewModel.cognitiveEmotions[sender.tag]
            viewModel.toggleSelection(for: selectedEmotion, in: cognitiveCollectionView)
            
            cognitiveCollectionView.reloadItems(at: [IndexPath(item: sender.tag, section: 0)])
            cognitiveCollectionView.layoutIfNeeded()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateCollectionViewHeight(self.cognitiveCollectionView, constraint: self.cognitiveCollectionViewHeight)
            }
        }
    }
}
