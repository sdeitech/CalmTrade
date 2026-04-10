//
//  SessionAnalyticsViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import UIKit

final class SessionAnalyticsViewController: UIViewController {

    // MARK: - IBOutlets

    // P/L
    @IBOutlet weak var plLabel: UILabel!
    @IBOutlet weak var netPlLabel: UILabel!

    // Win Rate
    @IBOutlet weak var winRateLabel: UILabel!
    @IBOutlet weak var winLossLabel: UILabel!

    // Drawdown
    @IBOutlet weak var drawdownLabel: UILabel!
    @IBOutlet weak var drawdownNetPlLabel: UILabel!

    // CalmScore
    @IBOutlet weak var calmScoreLabel: UILabel!
    @IBOutlet weak var calmStateLabel: UILabel!
    @IBOutlet weak var sleepLabel: UILabel!
    
    // No Trade
    @IBOutlet weak var noTradeCntLabel: UILabel!
    
    // Emotion Counter
    @IBOutlet weak var positiveCntLabel: UILabel!
    @IBOutlet weak var negativeCntLabel: UILabel!
    @IBOutlet weak var neutralCntLabel: UILabel!
    @IBOutlet weak var cognitiveCntLabel: UILabel!
    @IBOutlet weak var tagsLoggedLabel: UILabel!
    @IBOutlet weak var mainEmotionLabel: UILabel!

    // MARK: - VM
    let viewModel = SessionAnalyticsViewModel()

    var selectedDate: String!   // yyyy-MM-dd

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        viewModel.fetch(date: selectedDate)
    }

    // MARK: - Binding
    private func bindViewModel() {
        viewModel.onLoading = { isLoading in
            // show/hide loader if needed
        }

        viewModel.onError = { [weak self] message in
            self?.showAlert(message: message)
        }

        viewModel.onUpdate = { [weak self] in
            self?.render()
        }
    }

    // MARK: - Render UI
    private func render() {
        guard let data = viewModel.data else { return }
        
        // --- P/L ---
        plLabel.text = data.pl.label
        plLabel.textColor = data.pl.valueR >= 0 ? .systemGreen : .systemRed
        netPlLabel.text = data.pl.subLabel
        
        // --- Win Rate ---
        winRateLabel.text = data.winRate.label
        winLossLabel.text = data.winRate.subLabel
        
        // --- Drawdown ---
        drawdownLabel.text = data.drawdown.label
        drawdownLabel.textColor = data.drawdown.maxDrawdownR < 0 ? .systemRed : .systemGreen
        drawdownNetPlLabel.text = data.drawdown.subLabel
        
        // --- CalmScore ---
        if let score = data.calmScore.value {
            calmScoreLabel.text = "\(score)"
            calmStateLabel.text = data.calmScore.stressLevel ?? "—"
        } else {
            calmScoreLabel.text = "--"
            calmStateLabel.text = "No Data"
        }
        
        if let sleep = data.calmScore.sleepHours {
            sleepLabel.text = "Sleep \(sleep)h"
            sleepLabel.isHidden = false
        } else {
            sleepLabel.isHidden = true
        }
        
        // --- No Trade ---
        noTradeCntLabel.text = "\(data.noTrades.count ?? 0)"
        
        // --- Emotion Counter ---
        switch data.emotionCounter.primaryCategory {
        case "positive": mainEmotionLabel.textColor = .init(hex: "245E2B")
        case "negative": mainEmotionLabel.textColor = .init(hex: "B52D0B")
        case "neutral": mainEmotionLabel.textColor  = .init("F4B04C")
        case "cognitive": mainEmotionLabel.textColor  = .init("B3E3FC")
        case .none:
            mainEmotionLabel.textColor = .white
        case .some(_):
            mainEmotionLabel.textColor = .white
        }
        mainEmotionLabel.text = "\(data.emotionCounter.primaryEmotion ?? "—") \(data.emotionCounter.primaryCount ?? 0)"
        tagsLoggedLabel.text = "\(data.emotionCounter.totalTags ?? 0) Tags Logged"
        
        positiveCntLabel.text = data.emotionCounter.positive?.description
        negativeCntLabel.text = data.emotionCounter.negative?.description
        neutralCntLabel.text = data.emotionCounter.neutral?.description
        cognitiveCntLabel.text = data.emotionCounter.cognitive?.description
    }
}
