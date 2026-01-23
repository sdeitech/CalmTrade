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

        case .Trades:
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

        case .Trades:
            lblEntryType.text = "Trade"
            if let p = item.result {
                if let r = item.resultR {
                    lblTitle.text = item.symbol! + "+\(r)+\(p)"
                } else {
                    lblTitle.text = item.symbol! + "+\(p)"
                }
            } else {
                lblTitle.text = item.symbol
            }
            let isLoss = item.result?.contains("-") == true
            entryTypeView.backgroundColor = isLoss ? .systemRed : .systemGreen

        case .Emotion:
            lblEntryType.text = "Emotion"
            lblTitle.text = item.emotion
            entryTypeView.backgroundColor = UIColor.init(hex: item.colorCode ?? "245E2B")

        case .NoTrade:
            lblEntryType.text = "No Trade"
            lblTitle.text = "\(item.symbol ?? "") @ $\(item.entryPrice ?? 0.0)"
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
    
    @IBAction func addNoteTapped(_ sender: UIButton) {
        onAddNoteTapped?()
    }
}
