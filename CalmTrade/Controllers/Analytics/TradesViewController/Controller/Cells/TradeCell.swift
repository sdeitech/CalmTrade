//
//  GridTextCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 24/11/25.
//

import UIKit

final class GridTextCell: UICollectionViewCell {

    @IBOutlet weak var label: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
//        layer.cornerRadius = 6
        layer.masksToBounds = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        label.textColor = .white
        backgroundColor = .clear
    }

    // HEADER STYLE
    func applyHeaderStyle() {
        label.font = UIFont.boldSystemFont(ofSize: 14)
        backgroundColor = UIColor(hex: "#1E232C")
    }

    // SUMMARY (TOTAL + AVERAGE)
    func applySummaryStyle() {
        label.font = UIFont.boldSystemFont(ofSize: 14)
        backgroundColor = UIColor(hex: "#1A1F27")
    }

    // REGULAR ROWS
    func applyRegularStyle(isEven: Bool) {
        label.font = UIFont.systemFont(ofSize: 14)
        backgroundColor = isEven
            ? UIColor(hex: "#14171C")
            : UIColor(hex: "#101215")
    }
}


// MARK: - Hex Color Utility
extension UIColor {
    convenience init(hex: String) {
        var hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)

        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
