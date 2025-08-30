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
    
    @IBOutlet weak var viewPositiveBottom: UIView!
    @IBOutlet weak var viewNegativeBottom: UIView!
    @IBOutlet weak var viewNeutralBottom: UIView!
    @IBOutlet weak var viewCognitiveBottom: UIView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeight: NSLayoutConstraint! // **NEW**: Single height constraint for the collection view
    
    //MARK: - Properties
    
    lazy var viewModel: HomeViewModel = {
        let obj = HomeViewModel()
        self.baseVwModel = obj
        return obj
    }()
    
    // MARK: - Emotion Tag Properties
    let unselectedColor = UIColor.lightGray
    
    enum EmotionCategory {
        case positive, negative, neutral, cognitive
        
        var selectedColor: UIColor {
            switch self {
            case .positive: return .systemGreen
            case .negative: return .systemRed
            case .neutral: return .systemOrange
            case .cognitive: return .systemBlue
            }
        }
    }
    
    private var selectedCategory: EmotionCategory = .positive

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
        
        updateCategorySelection()
        setupCollectionView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update height after the initial layout pass
        updateCollectionViewHeight()
    }
    
    // MARK: - Setup
    
    private func setupViewModelBindings() {
        viewModel.onStateUpdate = { [weak self] state in
            self?.updateUI(for: state)
        }
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isScrollEnabled = false
        let nib = UINib(nibName: "EmotionTagCell", bundle: nil)
        collectionView.register(nib, forCellWithReuseIdentifier: "EmotionTagCell")
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        collectionView.collectionViewLayout = layout
    }
    
    // MARK: - UI Update Logic
    
    private func updateUI(for state: HomeViewModel.ButtonState) {
        // ... (Your existing button logic) ...
    }
    
    private func updateCollectionViewHeight() {
        collectionViewHeight.constant = collectionView.collectionViewLayout.collectionViewContentSize.height
    }
    
    private func updateCategorySelection() {
        // ... (Your existing category selection UI logic) ...
        collectionView.reloadData()
        // Update height after a short delay to allow the collection view to reload.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateCollectionViewHeight()
        }
    }

    // MARK: - Actions
    
    @IBAction func didTapPositiveCategory(_ sender: Any) {
        selectedCategory = .positive
        updateCategorySelection()
    }
    
    @IBAction func didTapNegativeCategory(_ sender: Any) {
        selectedCategory = .negative
        updateCategorySelection()
    }
    
    @IBAction func didTapNeutralCategory(_ sender: Any) {
        selectedCategory = .neutral
        updateCategorySelection()
    }
    
    @IBAction func didTapCognitiveCategory(_ sender: Any) {
        selectedCategory = .cognitive
        updateCategorySelection()
    }
    
    // MARK: - UICollectionViewDataSource & Delegate
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch selectedCategory {
        case .positive: return viewModel.positiveEmotions.count
        case .negative: return viewModel.negativeEmotions.count
        case .neutral: return viewModel.neutralEmotions.count
        case .cognitive: return viewModel.cognitiveEmotions.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmotionTagCell", for: indexPath) as! EmotionTagCell
        
        // **NEW**: Add target to the button inside the cell
        cell.btnSelect.tag = indexPath.item
        cell.btnSelect.addTarget(self, action: #selector(handleCellSelection), for: .touchUpInside)
        
        switch selectedCategory {
        case .positive:
            let emotion = viewModel.positiveEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .systemGreen)
            cell.updateSelection(isSelected: emotion.isSelected)
        case .negative:
            let emotion = viewModel.negativeEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .systemRed)
            cell.updateSelection(isSelected: emotion.isSelected)
        case .neutral:
            let emotion = viewModel.neutralEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .systemOrange)
            cell.updateSelection(isSelected: emotion.isSelected)
        case .cognitive:
            let emotion = viewModel.cognitiveEmotions[indexPath.item]
            cell.configure(with: emotion.title, color: .systemBlue)
            cell.updateSelection(isSelected: emotion.isSelected)
        }
        
        return cell
    }
    
    // **NEW**: Target action method to handle cell button taps
    @objc func handleCellSelection(_ sender: UIButton) {
        let index = sender.tag
        viewModel.toggleEmotionSelection(at: index, for: selectedCategory)
        collectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
    }
}

