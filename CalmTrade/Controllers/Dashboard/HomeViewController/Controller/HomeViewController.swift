import UIKit

class HomeViewController: BaseViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    
    //MARK: Outlets
    @IBOutlet weak var calmScoreGauge: CalmScoreGaugeView!
    @IBOutlet weak var lblCalmScore: UILabel!
    @IBOutlet weak var viewCalmScore: UIView!
    
    @IBOutlet weak var btnNoTrade: UIButton!
    @IBOutlet weak var btnMinfulnessBreathe: UIButton!
    @IBOutlet weak var btnStartHRTrack: UIButton!
    
    @IBOutlet weak var lblDeviceName: UILabel!
    @IBOutlet weak var viewDevice: UIView!
    @IBOutlet weak var imgDevice: UIImageView!
    
    // MARK: - Emotion Tag Outlets
    @IBOutlet weak var lblPositive: UILabel!
    @IBOutlet weak var lblNegative: UILabel!
    @IBOutlet weak var lblNeutral: UILabel!
    @IBOutlet weak var lblCognitive: UILabel!
    
    // **FIX**: Ensure these are connected to the main container views for each category tab.
    @IBOutlet weak var viewPositive: UIView!
    @IBOutlet weak var viewNegative: UIView!
    @IBOutlet weak var viewNeutral: UIView!
    @IBOutlet weak var viewCognitive: UIView!
    
    @IBOutlet weak var positiveCollectionView: UICollectionView!
    @IBOutlet weak var negativeCollectionView: UICollectionView!
    @IBOutlet weak var neutralCollectionView: UICollectionView!
    @IBOutlet weak var cognitiveCollectionView: UICollectionView!
    
    @IBOutlet weak var collectionViewContainerHeight: NSLayoutConstraint!
    
    //MARK: - Properties
    
    lazy var viewModel: HomeViewModel = {
        let obj = HomeViewModel()
        self.baseVwModel = obj
        return obj
    }()
    
    enum EmotionCategory: Int {
        case positive = 0, negative, neutral, cognitive
        
        var selectedColor: UIColor {
            switch self {
            case .positive: return UIColor(red: 0.14, green: 0.37, blue: 0.17, alpha: 1.00) // #245E2B
            case .negative: return UIColor(red: 0.71, green: 0.18, blue: 0.04, alpha: 1.00) // #B52D0B
            case .neutral:  return UIColor(red: 0.96, green: 0.69, blue: 0.30, alpha: 1.00) // #F4B04C
            case .cognitive:return UIColor(red: 0.70, green: 0.89, blue: 0.99, alpha: 1.00) // #B3E3FC
            }
        }
    }
    
    private var selectedCategory: EmotionCategory = .positive
    private var allCollectionViews: [UICollectionView] = []
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        calmScoreGauge.onValueChange = { [weak self] (value, color) in
            self?.lblCalmScore.text = "\(value)"
            self?.lblCalmScore.textColor = color
            self?.viewCalmScore.borderColor = color
        }
        calmScoreGauge.needleValue = 20
        
        setupViewModelBindings()
        viewModel.determineButtonState()
        setupCollectionViews()
        
        showCategory(.positive)
        
        viewModel.startLiveUpdates()
    }
    
    // MARK: - Setup
    
    private func setupViewModelBindings() {
        viewModel.onEmotionDeselected = { [weak self] category, index in
            let indexPath = IndexPath(item: index, section: 0)
            
            // This is called by the ViewModel's timer to deselect a cell
            let collectionViewToUpdate = self?.allCollectionViews[category.rawValue]
            collectionViewToUpdate?.reloadItems(at: [indexPath])
        }
        
        viewModel.onCalmScoreUpdate = { [weak self] score, color in
            self?.lblCalmScore.text = "\(score)"
            self?.lblCalmScore.textColor = color
            self?.viewCalmScore.borderColor = color
            self?.calmScoreGauge.needleValue = CGFloat(score)
        }
    }
    
    private func setupCollectionViews() {
        allCollectionViews = [positiveCollectionView, negativeCollectionView, neutralCollectionView, cognitiveCollectionView]
        let nib = UINib(nibName: "EmotionTagCell", bundle: nil)
        
        for (index, cv) in allCollectionViews.enumerated() {
            cv.dataSource = self
            cv.delegate = self
            cv.isScrollEnabled = false
            cv.tag = index
            cv.register(nib, forCellWithReuseIdentifier: "EmotionTagCell")
            
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.minimumInteritemSpacing = 10
            layout.minimumLineSpacing = 10
            cv.collectionViewLayout = layout
        }
    }
    
    // MARK: - UI Update Logic
    private func showCategory(_ category: EmotionCategory) {
        selectedCategory = category
        let selectedLabelColor: UIColor = .white
        let unselectedLabelColor: UIColor = .gray
        let unselectedViewColor: UIColor = .clear
        
        let allLabels = [lblPositive, lblNegative, lblNeutral, lblCognitive]
        let allCategoryViews = [viewPositive, viewNegative, viewNeutral, viewCognitive]
        
        // Reset all tabs to their unselected state
        allLabels.forEach { $0?.textColor = unselectedLabelColor }
        allCategoryViews.forEach {
            $0?.backgroundColor = unselectedViewColor
            $0?.layer.borderWidth = 0
        }
        
        // Apply selected styles to the correct tab
        let selectedView: UIView = allCategoryViews[category.rawValue]!
        let selectedLabel: UILabel = allLabels[category.rawValue]!
        
        selectedView.backgroundColor = category.selectedColor
        selectedView.layer.borderWidth = 2
        selectedView.layer.borderColor = category.selectedColor.cgColor
        selectedLabel.textColor = selectedLabelColor
        
        // Show the correct collection view and hide the others
        for (index, cv) in allCollectionViews.enumerated() {
            cv.isHidden = (index != category.rawValue)
        }
        
//        let activeCollectionView = allCollectionViews[category.rawValue]
//        activeCollectionView.performBatchUpdates({
//            activeCollectionView.reloadData()
//        }, completion: { _ in
//            activeCollectionView.layoutIfNeeded()
//            self.updateContainerHeight(for: category)
//        })
        
        // Update the container height after the data is reloaded.
        view.layoutIfNeeded()
        DispatchQueue.main.async {
            self.updateContainerHeight(for: category)
        }
    }
    
    private func updateContainerHeight(for category: EmotionCategory) {
        let activeCollectionView = allCollectionViews[category.rawValue]
        let contentHeight = activeCollectionView.collectionViewLayout.collectionViewContentSize.height
        collectionViewContainerHeight.constant = contentHeight
    }
    
    // MARK: - Actions
    @IBAction func didTapPositiveCategory(_ sender: Any) { showCategory(.positive) }
    @IBAction func didTapNegativeCategory(_ sender: Any) { showCategory(.negative) }
    @IBAction func didTapNeutralCategory(_ sender: Any) { showCategory(.neutral) }
    @IBAction func didTapCognitiveCategory(_ sender: Any) { showCategory(.cognitive) }
    
    // MARK: - UICollectionViewDataSource & Delegate
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let category = EmotionCategory(rawValue: collectionView.tag) else { return 0 }
        switch category {
        case .positive: return viewModel.positiveEmotions.count
        case .negative: return viewModel.negativeEmotions.count
        case .neutral: return viewModel.neutralEmotions.count
        case .cognitive: return viewModel.cognitiveEmotions.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmotionTagCell", for: indexPath) as! EmotionTagCell
        cell.btnSelect.removeTarget(nil, action: nil, for: .allEvents)
        
        cell.btnSelect.tag = indexPath.item
        cell.btnSelect.accessibilityHint = String(collectionView.tag) // which category
        cell.btnSelect.addTarget(self, action: #selector(handleCellSelection(_:)), for: .touchUpInside)
        
        guard let category = EmotionCategory(rawValue: collectionView.tag) else { return cell }
        
        let emotion: EmotionTag
        switch category {
        case .positive: emotion = viewModel.positiveEmotions[indexPath.item]
        case .negative: emotion = viewModel.negativeEmotions[indexPath.item]
        case .neutral:  emotion = viewModel.neutralEmotions[indexPath.item]
        case .cognitive:emotion = viewModel.cognitiveEmotions[indexPath.item]
        }
        
        cell.configure(with: emotion.title, color: category.selectedColor)
        cell.updateSelection(isSelected: emotion.isSelected)
        
        return cell
    }
    
    @objc func handleCellSelection(_ sender: UIButton) {
        // determine which category this button belongs to:
        guard let hint = sender.accessibilityHint, let catIndex = Int(hint),
              let category = EmotionCategory(rawValue: catIndex) else {
            return
        }
        let idx = sender.tag
        viewModel.toggleEmotionSelection(at: idx, for: category)

        let activeCollectionView = allCollectionViews[category.rawValue]
        let ip = IndexPath(item: idx, section: 0)

        // reload the single item; performBatchUpdates ensures collection has time to layout
        activeCollectionView.performBatchUpdates({
            activeCollectionView.reloadItems(at: [ip])
        }, completion: { _ in
            // force layout pass so cell layoutSubviews runs and animation starts correctly
            activeCollectionView.layoutIfNeeded()
            self.updateContainerHeight(for: category) // recalc height if needed
        })
    }

}
