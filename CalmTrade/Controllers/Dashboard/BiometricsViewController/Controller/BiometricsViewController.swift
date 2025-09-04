//
//  BiometricsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 02/09/25.
//


import UIKit

class BiometricsViewController: UIViewController {

    // MARK: - Outlets
    
    // CalmScore Gauge
    @IBOutlet weak var calmScoreGauge: CalmScoreGaugeView!
    @IBOutlet weak var lblLastUpdate: UILabel!
    @IBOutlet weak var lblCalmScore: UILabel!
    
    // Heart Rate Card
    @IBOutlet weak var lblHeartRateAverage: UILabel!
    @IBOutlet weak var lblHeartRateLatest: UILabel!
    
    // HRV Card
    @IBOutlet weak var lblHrvAverage: UILabel!
    @IBOutlet weak var lblHrvLatest: UILabel!
    @IBOutlet weak var lblHrvTimestamp: UILabel!
    
    // Resting HR Card
    @IBOutlet weak var lblRestingHrAverage: UILabel!
    @IBOutlet weak var lblRestingHrLatest: UILabel!
    @IBOutlet weak var lblRestingHrTimestamp: UILabel!

    // Sleep Card
    @IBOutlet weak var lblSleepTotal: UILabel!
    @IBOutlet weak var lblSleepDate: UILabel!
    
    // Steps Card
    @IBOutlet weak var lblStepsAverage: UILabel! // Note: Weekly avg is not yet implemented
    @IBOutlet weak var lblStepsToday: UILabel!
    @IBOutlet weak var lblStepsDate: UILabel!
    
    // MARK: - Properties
    private let viewModel = BiometricsViewModel()

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
        
        // Set initial gauge value
        calmScoreGauge.needleValue = 80 // or a default starting value
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Fetch fresh data every time the screen appears
        viewModel.fetchAllBiometrics()
    }

    // MARK: - Setup
    
    private func setupBindings() {
        // This is where the magic happens. When the ViewModel's data changes, this block is called.
        viewModel.onDataUpdated = { [weak self] data in
            self?.updateUI(with: data)
        }
    }
    
    // MARK: - UI Update
    
    private func updateUI(with data: BiometricData) {
//        lblLastUpdate.text = data.lastUpdateTimestamp
        lblCalmScore.text = data.calmScore
        
        if let score = Int(data.calmScore) {
            calmScoreGauge.needleValue = CGFloat(score)
        }
        
        lblHeartRateAverage.text = data.heartRateAverage
        lblHeartRateLatest.text = data.heartRateLatest
        
        lblHrvAverage.text = data.hrvAverage
        lblHrvLatest.text = data.hrvLatest
        lblHrvTimestamp.text = data.hrvTimestamp
        
        lblRestingHrAverage.text = data.restingHeartRateAverage
        lblRestingHrLatest.text = data.restingHeartRateLatest
        lblRestingHrTimestamp.text = data.restingHeartRateTimestamp
        
        lblSleepTotal.text = data.sleepTotal
        lblSleepDate.text = data.sleepDate
        
        lblStepsAverage.text = data.stepsWeeklyAverage
        lblStepsToday.text = data.stepsToday
        lblStepsDate.text = data.stepsDate
    }
    
    //MARK: - Actions
    
    @IBAction func btnHRVTapped(_ sender: Any) {
        let hrvDetailVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "HRVDetailViewController") as! HRVDetailViewController
        self.navigationController?.pushViewController(hrvDetailVC,transitionType: .fade)
    }
    
    @IBAction func btnHRTapped(_ sender: Any) {
        let hrDetailVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "HeartRateDetailViewController") as! HeartRateDetailViewController
        self.navigationController?.pushViewController(hrDetailVC,transitionType: .fade)
    }
    
    @IBAction func btnRestingHRTapped(_ sender: Any) {
        let restinghrDetailVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "RestingHeartRateDetailViewController") as! RestingHeartRateDetailViewController
        self.navigationController?.pushViewController(restinghrDetailVC,transitionType: .fade)
    }
    
    @IBAction func btnStepsTapped(_ sender: Any) {
        let stepsDetailVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "StepsDetailViewController") as! StepsDetailViewController
        self.navigationController?.pushViewController(stepsDetailVC,transitionType: .fade)
    }
    
    @IBAction func btnSleepDataTapped(_ sender: Any) {
        let sleepDataDetailVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "SleepInsightViewController") as! SleepInsightViewController
        self.navigationController?.pushViewController(sleepDataDetailVC,transitionType: .fade)
    }
    
    @IBAction func btnAddDataTapped(_ sender: Any) {
        let addSleepDataVC = UIStoryboard(name: Constants.Storyboard.Biometrics, bundle: nil).instantiateViewController(withIdentifier: "AddSleepDataViewController") as! AddSleepDataViewController
        self.navigationController?.pushViewController(addSleepDataVC,transitionType: .fade)
    }
}
