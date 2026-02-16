import UIKit
import SwiftUI

class HomeViewController: BaseViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    //MARK: Outlets
    @IBOutlet weak var calmScoreGauge: UIView!
    @IBOutlet weak var btnNoTrade: UIButton!
//    @IBOutlet weak var viewHR: UIView!
//    @IBOutlet weak var lblHR: UILabel!
//    @IBOutlet weak var lblHRTimestamp: UILabel!

    @IBOutlet weak var lblDeviceName: UILabel!
    @IBOutlet weak var imgDevice: UIImageView!

    // MARK: - Emotion Tag Outlets
    @IBOutlet weak var lblPositive: UILabel!
    @IBOutlet weak var lblNegative: UILabel!
    @IBOutlet weak var lblNeutral: UILabel!
    @IBOutlet weak var lblCognitive: UILabel!

    @IBOutlet weak var viewPositive: UIView!
    @IBOutlet weak var viewNegative: UIView!
    @IBOutlet weak var viewNeutral: UIView!
    @IBOutlet weak var viewCognitive: UIView!

    @IBOutlet weak var positiveCollectionView: UICollectionView!
    @IBOutlet weak var negativeCollectionView: UICollectionView!
    @IBOutlet weak var neutralCollectionView: UICollectionView!
    @IBOutlet weak var cognitiveCollectionView: UICollectionView!

    @IBOutlet weak var collectionViewContainerHeight: NSLayoutConstraint!
    
    @IBOutlet weak var btnSetSession: UIButton!

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
            case .positive: return UIColor(Color(hex: 0x00C96B)) // #245E2B
            case .negative: return UIColor(Color(hex: 0xFF4D3D)) // #B52D0B
            case .neutral:  return UIColor(red: 0.96, green: 0.69, blue: 0.30, alpha: 1.00) // #F4B04C
            case .cognitive:return UIColor(red: 0.70, green: 0.89, blue: 0.99, alpha: 1.00) // #B3E3FC
            }
        }
    }

    private var selectedCategory: EmotionCategory = .positive
    private var allCollectionViews: [UICollectionView] = []
    private var calmScoreTileController: UIHostingController<CalmScoreBarTile>?
    
    private let lastSessionSetupDateKey = "ct.lastSessionSetupDate"
    private let profileService = ProfileService()

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSwiftUIGauge()
        setupViewModelBindings()
        setupCollectionViews()

        viewModel.determineButtonState()

        showCategory(.positive)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.fetchEmotionTags()
        enforceDailySessionSetupIfNeeded()
        refreshUserProfileIfNeeded()
    }
     
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startLiveUpdates()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopLiveUpdates()
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        let vc = UIHostingController(rootView: CalmScoreDiagnosticsView())
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }

    // MARK: - Setup

    private func setupSwiftUIGauge() {
        let initialProps = CalmScoreTileProps(
            score: 0,
            lastUpdate: Date(),
            deviceSource: .appleHK,
            isStreaming: false,
            trend: TrendData(hrvMs: 0, hrvIsUp: false, hrBpm: 0, hrIsDown: false, sleepHours: 0, sleepIsUp: false),
            batteryPercent: nil // 👈
        )

        let onConnectTap: () -> Void = { [weak self] in
            guard let self = self else { return }
            let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                .instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
            self.navigationController?.pushViewController(vc, animated: true)
        }

        let onTileTap: () -> Void = { [weak self] in
            guard let self = self else { return }
            let details = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                .instantiateViewController(withIdentifier: "CalmScoreDetailsViewController") as! CalmScoreDetailsViewController
            self.navigationController?.pushViewController(details, transitionType: .reveal)
        }

        let swiftUIView = CalmScoreBarTile(
            props: initialProps,
            onConnectTap: onConnectTap,
            onTileTap: onTileTap
        )

        let hostingController = UIHostingController(rootView: swiftUIView)
        self.calmScoreTileController = hostingController

        addChild(hostingController)
        calmScoreGauge.addSubview(hostingController.view)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: calmScoreGauge.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: calmScoreGauge.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: calmScoreGauge.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: calmScoreGauge.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }


    private func setupViewModelBindings() {
        viewModel.onEmotionDeselected = { [weak self] category, index in
            let indexPath = IndexPath(item: index, section: 0)
            self?.allCollectionViews[category.rawValue].reloadItems(at: [indexPath])
        }

        viewModel.onPropsUpdate = { [weak self] newProps in
            DispatchQueue.main.async {
                guard let self = self, let hc = self.calmScoreTileController else { return }

                let onConnectTap: () -> Void = { [weak self] in
                    guard let self = self else { return }
                    let vc = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil)
                        .instantiateViewController(withIdentifier: "PolarConnectionViewController") as! PolarConnectionViewController
                    self.navigationController?.pushViewController(vc, animated: true)
                }

                let onTileTap: () -> Void = { [weak self] in
                    guard let self = self else { return }
                    let details = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil)
                        .instantiateViewController(withIdentifier: "CalmScoreDetailsViewController") as! CalmScoreDetailsViewController
                    self.navigationController?.pushViewController(details, transitionType: .reveal)
                }

                hc.rootView = CalmScoreBarTile(
                    props: newProps,
                    onConnectTap: onConnectTap,
                    onTileTap: onTileTap
                )
            }
        }
        
        viewModel.onEmotionDataLoaded = { [weak self] in
            guard let self else { return }

            // Reload all (data)
            self.allCollectionViews.forEach { $0.reloadData() }

            // Force layout only for visible category
            let activeCV = self.allCollectionViews[self.selectedCategory.rawValue]
            activeCV.isHidden = false
            activeCV.layoutIfNeeded()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateContainerHeight(for: self.selectedCategory)
            }
        }

        // 👇 NEW: HR block visibility + labels
//        viewModel.onHRVisibility = { [weak self] visible in
//            DispatchQueue.main.async {
//                self?.viewHR.isHidden = !visible
//            }
//        }

//        viewModel.onHRValue = { [weak self] hrText, tsText in
//            DispatchQueue.main.async {
//                self?.lblHR.text = hrText
//                self?.lblHRTimestamp.text = tsText
//            }
//        }
    }
    
    private func refreshUserProfileIfNeeded() {
        guard let token = SessionManager.shared.accessToken else { return }

        profileService.refreshProfile(accessToken: token) { _, _ in }
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

            let layout = LeftAlignedCollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.minimumInteritemSpacing = 10
            layout.minimumLineSpacing = 10
            layout.sectionInset = .zero

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

        allLabels.forEach { $0?.textColor = unselectedLabelColor }
        allCategoryViews.forEach {
            $0?.backgroundColor = unselectedViewColor
            $0?.layer.borderWidth = 0
        }

        let selectedView: UIView = allCategoryViews[category.rawValue]!
        let selectedLabel: UILabel = allLabels[category.rawValue]!

        selectedView.backgroundColor = category.selectedColor
        selectedView.layer.borderWidth = 2
        selectedView.layer.borderColor = category.selectedColor.cgColor
        selectedLabel.textColor = selectedLabelColor

        for (index, cv) in allCollectionViews.enumerated() {
            cv.isHidden = (index != category.rawValue)
        }

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
    
    private func enforceDailySessionSetupIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = UserDefaults.standard.object(forKey: lastSessionSetupDateKey) as? Date {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay == today {
                return // already set today
            }
        }

        // Force user to set session
        navigateToStartSession(showsBackButton: true)
    }
    
    private func navigateToStartSession(showsBackButton: Bool) {
        let vm = StartSessionViewModel()
        let vc = UIStoryboard(name: Constants.Storyboard.Home, bundle: nil).instantiateViewController(withIdentifier: "StartSessionViewController") as! StartSessionViewController
        vc.viewModel = vm
        vc.showsBackButton = showsBackButton
        navigationController?.pushViewController(vc)
    }


    // MARK: - Actions
    @IBAction func didTapPositiveCategory(_ sender: Any) { showCategory(.positive) }
    @IBAction func didTapNegativeCategory(_ sender: Any) { showCategory(.negative) }
    @IBAction func didTapNeutralCategory(_ sender: Any) { showCategory(.neutral) }
    @IBAction func didTapCognitiveCategory(_ sender: Any) { showCategory(.cognitive) }

    @IBAction func didTapCalmScoreGauge(_ sender: UIButton) {
        let calmDetailVC = UIStoryboard(name: Constants.Storyboard.Dashboard, bundle: nil).instantiateViewController(withIdentifier: "CalmScoreDetailsViewController") as! CalmScoreDetailsViewController
        self.navigationController?.pushViewController(calmDetailVC,transitionType: .reveal)
    }

    @IBAction func didTapWatchIcon(_ sender: Any) {
        let deviceManagerVC = UIStoryboard(name: Constants.Storyboard.Devices, bundle: nil).instantiateViewController(withIdentifier: "DeviceManagementViewController") as! DeviceManagementViewController
        self.navigationController?.pushViewController(deviceManagerVC)
    }
    
    @IBAction func didTapProfileIcon(_ sender: Any) {
        self.navigationController?.pushViewController(UIStoryboard(name: Constants.Storyboard.ProfileHost, bundle: nil).instantiateViewController(withIdentifier: "ProfileTabsHostViewController") as! ProfileTabsHostViewController,transitionType: .fade)
    }
    
    @IBAction func didTapCalendarIcon(_ sender: Any) {
        let calendarVC = UIStoryboard(name: Constants.Storyboard.Home, bundle: nil).instantiateViewController(withIdentifier: "CalendarViewController") as! CalendarViewController
        self.navigationController?.pushViewController(calendarVC)
    }
    
    @IBAction func didTapSetSession(_ sender: UIButton) {
        navigateToStartSession(showsBackButton: true)
    }
    
    @IBAction func didTapAddNote(_ sender: UIButton) {

        let sessionId = UserDefaults.standard.string(forKey: "ct.activeSessionId") ?? ""

        let vm = AddNoteViewModel(sessionId: sessionId)
        let view = AddNoteBottomSheetView(viewModel: vm)

        let vc = UIHostingController(rootView: view)
        vc.view.backgroundColor = .clear
        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 24
        }

        present(vc, animated: true)
    }
    
    @IBAction func didTapNoTrade(_ sender: UIButton) {

        // TEMP: until session manager exists
        let sessionId = UserDefaults.standard.string(forKey: "ct.activeSessionId") ?? ""

        let vm = NoTradeViewModel(sessionId: sessionId)
        let view = NoTradeBottomSheetView(viewModel: vm)

        let vc = UIHostingController(rootView: view)
        vc.view.backgroundColor = .clear
        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = false
            sheet.preferredCornerRadius = 24
        }

        present(vc, animated: true)
    }


    // MARK: - UICollectionViewDataSource & Delegate

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let category = EmotionCategory(rawValue: collectionView.tag) else { return 0 }
        switch category {
        case .positive: return viewModel.positiveEmotions.count
        case .negative: return viewModel.negativeEmotions.count
        case .neutral:  return viewModel.neutralEmotions.count
        case .cognitive:return viewModel.cognitiveEmotions.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmotionTagCell", for: indexPath) as! EmotionTagCell
        cell.btnSelect.removeTarget(nil, action: nil, for: .allEvents)

        cell.btnSelect.tag = indexPath.item
        cell.btnSelect.accessibilityHint = String(collectionView.tag)
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
        guard let hint = sender.accessibilityHint, let catIndex = Int(hint),
              let category = EmotionCategory(rawValue: catIndex) else { return }

        let idx = sender.tag
        viewModel.toggleEmotionSelection(at: idx, for: category)

        let activeCollectionView = allCollectionViews[category.rawValue]
        let ip = IndexPath(item: idx, section: 0)

        activeCollectionView.performBatchUpdates({
            activeCollectionView.reloadItems(at: [ip])
        }, completion: { _ in
            activeCollectionView.layoutIfNeeded()
            self.updateContainerHeight(for: category)
        })
    }
}
