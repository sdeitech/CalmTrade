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
    @IBOutlet weak var lblSymbol: UILabel!
    @IBOutlet weak var lblNote: UILabel!
    @IBOutlet weak var btnAddNote: UIButton!
    @IBOutlet weak var lblMetrics: UILabel!
    @IBOutlet weak var lblEmotion: UILabel!
    
    var onAddNoteTapped: (() -> Void)?

    // MARK: - Configure
    func configure(with item: TimelineItem) {

        // Reset reusable state (important)
//        lblNote.isHidden = true
//        btnAddNote.isHidden = true
//        lblMetrics.isHidden = true
//        lblEmotion.isHidden = true

        // Time handling (authoritative)
        switch item.type {

        case .trade:
            // Prefer timestamps over backend strings
            lblTime.text = TimelineDateFormatter.timeRange(
                entry: item.entryTime,
                exit: item.exitTime
            )

        default:
            // Emotion / NoTrade / others → single timestamp
            lblTime.text = TimelineDateFormatter.time(from: item.timestamp)
        }


        // Entry type + title
        switch item.type {

        case .trade:
            lblEntryType.text = "Trade"
            lblSymbol.text = item.symbol
            if let p = item.result {
                if let r = item.resultR {
                    lblTitle.text = "\(r)+\(p)"
                } else {
                    lblTitle.text = p
                }
            }
            let isLoss = item.result?.contains("-") == true
            entryTypeView.backgroundColor = isLoss ? .systemRed : .systemGreen

        case .emotion:
            lblEntryType.text = "Emotion"
            lblSymbol.text = item.emotion
            lblTitle.isHidden = true
            entryTypeView.backgroundColor = UIColor.init(hex: item.colorCode ?? "245E2B")

        case .noTrade:
            lblEntryType.text = "No Trade"
            lblTitle.isHidden = true
            if let entryPrice = item.entryPrice {
                lblSymbol.text = "\(item.symbol ?? "") $\(entryPrice)"
            } else {
                lblSymbol.text = item.symbol
            }
            entryTypeView.backgroundColor = .systemBlue
        case .unknown(_): break
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
        if item.type != .emotion, let emotion = item.emotion {
            lblEmotion.text = emotion
            lblEmotion.isHidden = false
        } else {
            lblEmotion.isHidden = true
        }
    }
    
    @IBAction func addNoteTapped(_ sender: UIButton) {
        onAddNoteTapped?()
    }
}
