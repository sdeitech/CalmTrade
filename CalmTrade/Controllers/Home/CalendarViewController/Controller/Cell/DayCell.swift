//
//  DayCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 12/11/25.
//


import UIKit

final class DayCell: UICollectionViewCell {

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var pnlLabel: UILabel!
    @IBOutlet weak var tradesLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
//        layer.cornerRadius = 10
        layer.masksToBounds = true
    }

    func configure(item: DayOrTotal) {
        switch item {
        case .day(let day):
            applyUI(
                rawDate: day.date,
                pnl: day.pnl,
                trades: day.trades
            )

        case .total(let total):
            applyUI(
                rawDate: "",
                pnl: total.pnl,
                trades: total.trades,
                isTotalRow: true
            )
        }
    }

    private func applyUI(
        rawDate: String,
        pnl: Double,
        trades: Int,
        isTotalRow: Bool = false
    ) {
        // --- DATE ---
        let formattedDay = rawDate.isEmpty ? "" : String(rawDate.suffix(2))
        dateLabel.text = formattedDay

        // --- PNL FORMAT ---
        if pnl == 0 && trades == 0 {
            pnlLabel.text = "NA"
        } else {
            pnlLabel.text = pnl >= 0
                ? "$\(String(format: "%.0f", pnl))"
                : "-$\(String(format: "%.0f", abs(pnl)))"
        }

        // --- TRADES FORMAT ---
        tradesLabel.text = trades > 0 ? "\(trades) trade\(trades > 1 ? "s" : "")" : ""

        // --- COLORS ---
        if isTotalRow {
            // Monthly total row at bottom
            backgroundColor = UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
            dateLabel.textColor = .clear
            pnlLabel.textColor = .white
            tradesLabel.textColor = .white
            return
        }

        if trades == 0 {
            // No-trade / empty day
            backgroundColor = UIColor(red: 15/255, green: 20/255, blue: 40/255, alpha: 1)
            dateLabel.textColor = UIColor(white: 0.6, alpha: 1)
            pnlLabel.textColor = .clear
            tradesLabel.textColor = .clear
            return
        }

        // Trade day → full color block
        if pnl > 0 {
            // Green (same as trades table)
            backgroundColor = UIColor(red: 0/255, green: 122/255, blue: 76/255, alpha: 1)
        } else if pnl < 0 {
            // Red (same as trades table)
            backgroundColor = UIColor(red: 150/255, green: 25/255, blue: 25/255, alpha: 1)
        } else {
            // Break-even day
            backgroundColor = UIColor(red: 50/255, green: 50/255, blue: 65/255, alpha: 1)
        }
        
        if dateLabel.text == "" {
            self.backgroundColor = .clear
            self.borderColor = .clear
            self.contentView.backgroundColor = .clear
        }

        // Everything white on colored tiles
        dateLabel.textColor = .white
        pnlLabel.textColor = .white
        tradesLabel.textColor = .white
    }
}

