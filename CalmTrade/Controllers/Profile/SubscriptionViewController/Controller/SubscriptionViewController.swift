//
//  SubscriptionViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//  Updated by ChatGPT on 15/12/25.
//

import UIKit
import Combine

final class SubscriptionViewController: UIViewController {

    // MARK: - MAIN SCROLL (Current subscription)
    @IBOutlet weak var mainScrollView: UIScrollView!

    @IBOutlet weak var currentPlanImageView: UIImageView!

    @IBOutlet weak var lblCurrentPlanExpiry: UILabel!

    @IBOutlet weak var currentFeaturesTableView: UITableView!
    @IBOutlet weak var currentFeaturesTableHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var btnUpgrade: UIButton!

    // MARK: - SUBSCRIPTION SCROLL (Plan selection)
    @IBOutlet weak var subscriptionScrollView: UIScrollView!      // Initially hidden

    @IBOutlet weak var tableView: UITableView!                     // plan comparison table
    @IBOutlet weak var tableHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var viewPro: UIView!
    @IBOutlet weak var viewElite: UIView!
    
    @IBOutlet weak var imgProRadio: UIImageView!
    @IBOutlet weak var imgEliteRadio: UIImageView!

    @IBOutlet weak var btnSubscribe: UIButton!

    // MARK: - ViewModel
    private let vm = SubscriptionViewModel()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Local Data for Plan Comparison
    private var basicPlan: SubscriptionPlan?
    private var proPlan: SubscriptionPlan?
    private var elitePlan: SubscriptionPlan?
    private var mergedFeatureList: [String] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        subscriptionScrollView.isHidden = true        // show MAIN screen by default
        mainScrollView.isHidden = true             // hide until plans load
        disableSubscribeButton()

        setupPlanSelectionTable()

        bindViewModel()

        vm.fetchCurrentSubscription()   // load current plan
        vm.fetchPlans()                 // load upgrade options
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCurrentPlanTableHeight()
        updatePlanSelectionTableHeight()
    }

    // MARK: - ViewModel Binding
    private func bindViewModel() {

        // CURRENT SUBSCRIPTION
        vm.$currentSubscription
            .receive(on: DispatchQueue.main)
            .sink { [weak self] subscription in
                guard let self = self, let sub = subscription else { return }
                self.updateCurrentPlanUI(sub)
            }
            .store(in: &cancellables)

        vm.$currentFeatures
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.currentFeaturesTableView.reloadData()
                self?.updateCurrentPlanTableHeight()
            }
            .store(in: &cancellables)

        // AVAILABLE PLANS
        vm.$plans
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plans in
                guard let self = self, !plans.isEmpty else { return }

                self.basicPlan = plans.first(where: { $0.name.lowercased() == "basic" })
                self.proPlan   = plans.first(where: { $0.name.lowercased() == "pro" })
                self.elitePlan = plans.first(where: { $0.name.lowercased() == "elite" })

                self.prepareMergedFeatureList()

                self.mainScrollView.isHidden = false
                self.tableView.reloadData()
                self.updatePlanSelectionTableHeight()
            }
            .store(in: &cancellables)

        // PLAN SELECTION
        vm.$selectedPlanId
            .sink { [weak self] _ in
                self?.updateRadioButtons()
                self?.updateSubscribeButtonState()
            }
            .store(in: &cancellables)
    }

    // MARK: - CURRENT PLAN UI
    private func setupCurrentPlanTable() {
        currentFeaturesTableView.isScrollEnabled = false
    }

    private func updateCurrentPlanUI(_ sub: SubscriptionRecord) {

        if sub.status == "trial", let trialEnd = sub.trialEndDate {
            lblCurrentPlanExpiry.text = "Trial ends on \(formatDate(trialEnd))"
        } else if let exp = sub.expiryDate {
            lblCurrentPlanExpiry.text = "Renews on \(formatDate(exp))"
        } else {
            lblCurrentPlanExpiry.text = ""
        }
        
        updateCurrentPlanBackground(sub.planDetails?.name ?? "")

        // Disable upgrade if user is already Elite
        let isElite = sub.planDetails?.name.lowercased() == "elite"
        btnUpgrade.isUserInteractionEnabled = !isElite
        btnUpgrade.alpha = isElite ? 0.4 : 1.0
    }
    
    private func updateCurrentPlanBackground(_ planName: String) {

        let lower = planName.lowercased()

        if lower == "basic" {
            currentPlanImageView.image = UIImage(named: "basic_bg")
        }
        else if lower == "pro" {
            currentPlanImageView.image = UIImage(named: "pro_bg")
        }
        else if lower == "elite" {
            currentPlanImageView.image = UIImage(named: "elite_bg")
        }
        else {
            currentPlanImageView.image = nil   // fallback
        }
    }

    private func updateCurrentPlanTableHeight() {
        currentFeaturesTableView.layoutIfNeeded()
        currentFeaturesTableHeightConstraint.constant = currentFeaturesTableView.contentSize.height
    }

    // MARK: - BUTTON
    @IBAction func tapUpgrade(_ sender: UIButton) {
        mainScrollView.isHidden = true
        subscriptionScrollView.isHidden = false
    }

    // MARK: - PLAN SELECTION UI
    private func setupPlanSelectionTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.isScrollEnabled = false
    }

    private func updatePlanSelectionTableHeight() {
        tableView.layoutIfNeeded()
        tableHeightConstraint.constant = tableView.contentSize.height
    }

    private func prepareMergedFeatureList() {
        var set = Set<String>()
        basicPlan?.features.forEach { set.insert($0.name) }
        proPlan?.features.forEach { set.insert($0.name) }
        elitePlan?.features.forEach { set.insert($0.name) }
        mergedFeatureList = Array(set).sorted()
    }

    // PLAN SELECTION ACTIONS
    @IBAction func tapPro(_ sender: UIButton) {
        vm.selectedPlanId = proPlan?.planId
    }
    @IBAction func tapElite(_ sender: UIButton) {
        vm.selectedPlanId = elitePlan?.planId
    }
    @IBAction func tapBasic(_ sender: UIButton) {
        vm.selectedPlanId = nil
        imgProRadio.image = UIImage(named: "radio_unselected")
        imgEliteRadio.image = UIImage(named: "radio_unselected")
        disableSubscribeButton()
    }

    private func updateRadioButtons() {
        let selected = vm.selectedPlanId
        imgProRadio.image = UIImage(named: selected == proPlan?.planId ? "radio_selected" : "radio_unselected")
        imgEliteRadio.image = UIImage(named: selected == elitePlan?.planId ? "radio_selected" : "radio_unselected")
    }

    private func disableSubscribeButton() {
        btnSubscribe.alpha = 0.4
        btnSubscribe.isUserInteractionEnabled = false
    }

    private func updateSubscribeButtonState() {
        guard vm.selectedPlanId != nil else {
            disableSubscribeButton(); return
        }
        btnSubscribe.alpha = 1
        btnSubscribe.isUserInteractionEnabled = true
    }

    // MARK: - SUBSCRIBE ACTION
    @IBAction func tapSubscribe(_ sender: UIButton) {
        vm.createCheckoutSession { [weak self] url in
            guard let self = self, let url = url else { return }

            let vc = SubscriptionWebViewController()
            vc.checkoutURL = url
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - TABLES
extension SubscriptionViewController: UITableViewDataSource, UITableViewDelegate {

    // 2 TABLES: Identify which table is calling these methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if tableView == currentFeaturesTableView {
            return vm.currentFeatures.count
        }
        return mergedFeatureList.count   // plan selection
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if tableView == currentFeaturesTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CurrentPlanFeatureCell", for: indexPath) as! CurrentPlanFeatureCell
            cell.configure(vm.currentFeatures[indexPath.row])
            return cell
        }

        // Plan selection table
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeatureCell", for: indexPath) as! FeatureCell
        cell.selectionStyle = .none

        let feature = mergedFeatureList[indexPath.row]
        let basicInc = basicPlan?.features.first(where: { $0.name == feature })?.included ?? false
        let proInc   = proPlan?.features.first(where: { $0.name == feature })?.included ?? false
        let eliteInc = elitePlan?.features.first(where: { $0.name == feature })?.included ?? false

        cell.configure(feature: feature, basic: basicInc, pro: proInc, elite: eliteInc)
        return cell
    }
}

// MARK: - UTILITIES
private extension SubscriptionViewController {
    func formatDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: iso) else { return "" }
        let out = DateFormatter()
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }
}
