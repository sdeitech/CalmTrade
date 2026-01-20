//
//  TimelineCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/01/26.
//

import UIKit

final class TimelineCell: UITableViewCell {

    // MARK: - Outlets
    @IBOutlet weak var entryTypeView: UIView!
    @IBOutlet weak var lblEntryType: UILabel!

    @IBOutlet weak var lblTime: UILabel!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblNote: UILabel!
    @IBOutlet weak var btnAddNote: UIButton!
    @IBOutlet weak var lblMetrics: UILabel!
    @IBOutlet weak var lblEmotion: UILabel!

    // MARK: - Configure
    func configure(with item: TimelineItem) {

        // Reset reusable state (important)
//        lblNote.isHidden = true
//        btnAddNote.isHidden = true
//        lblMetrics.isHidden = true
//        lblEmotion.isHidden = true

        // Time
        lblTime.text = item.time ?? item.timeRange

        // Entry type + title
        switch item.type {

        case .Trades:
            lblEntryType.text = "Trade"
            var titleText: String?
            if let entryPrice = item.entryPrice {
                titleText = "\(item.symbol) @ \(entryPrice)"
            } else {
                titleText = item.symbol
            }
            lblTitle.text = titleText

            let isLoss = item.result?.contains("-") == true
            entryTypeView.backgroundColor = isLoss ? .systemRed : .systemGreen

        case .Emotion:
            lblEntryType.text = "Emotion"
            lblTitle.text = item.emotion
            entryTypeView.backgroundColor = UIColor.init(hex: item.colorCode ?? "245E2B")

        case .NoTrade:
            lblEntryType.text = "No Trade"
            lblTitle.text = item.symbol
            entryTypeView.backgroundColor = .systemBlue
        }

        // Note / Reason
        if let note = item.note ?? item.reason ?? item.summary, !note.isEmpty {
            lblNote.text = note
            lblNote.isHidden = false
            btnAddNote.isHidden = true
        } else {
            lblNote.isHidden = true
            btnAddNote.isHidden = false
        }

        // Metrics (CalmScore / HR / HRV)
        var metrics: [String] = []

        if let calm = item.metrics?.calmScore {
            metrics.append("CalmScore \(calm)")
        }
        if let hr = item.metrics?.heartRate {
            metrics.append("HR \(hr)")
        }
        if let hrv = item.metrics?.hrv {
            metrics.append("HRV \(hrv)")
        }

        if metrics.isEmpty {
            lblMetrics.isHidden = true
        } else {
            lblMetrics.text = metrics.joined(separator: "  ")
            lblMetrics.isHidden = false
        }

        // Emotion tag (only for Trade / NoTrade)
        if item.type != .Emotion, let emotion = item.emotion {
            lblEmotion.text = emotion
            lblEmotion.isHidden = false
        } else {
            lblEmotion.isHidden = true
        }
    }
}
