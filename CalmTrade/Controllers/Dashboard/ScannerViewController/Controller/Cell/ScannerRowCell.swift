//
//  ScannerRowCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import UIKit

final class ScannerRowCell: UITableViewCell {

    static let id = "ScannerRowCell"

    private let stack = UIStackView()
    private var labels: [UILabel] = []
    private var newsDot: UIView?

    private let columnWidths: [CGFloat] = [72, 53, 43, 41, 41, 53, 43, 56]
    
    weak var delegate: ScannerRowCellDelegate?
    private var currentItem: ScannerItem?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .black

        stack.axis = .horizontal
        stack.spacing = 0
        stack.distribution = .fill

        contentView.addSubview(stack)

        // Create labels ONCE
        for width in columnWidths {
            let label = makeLabel(width: width)
            stack.addArrangedSubview(label)
            labels.append(label)
        }

        // Create news dot ONCE (attach to symbol column)
        let dotContainer = UIView()
        dotContainer.translatesAutoresizingMaskIntoConstraints = false
        labels[1].addSubview(dotContainer)

        NSLayoutConstraint.activate([
            dotContainer.widthAnchor.constraint(equalToConstant: 24),
            dotContainer.heightAnchor.constraint(equalToConstant: 24),
            dotContainer.trailingAnchor.constraint(equalTo: labels[1].trailingAnchor),
            dotContainer.topAnchor.constraint(equalTo: labels[1].topAnchor)
        ])

        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 3

        dotContainer.addSubview(dot)

        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.trailingAnchor.constraint(equalTo: dotContainer.trailingAnchor, constant: -6),
            dot.topAnchor.constraint(equalTo: dotContainer.topAnchor, constant: 6)
        ])
        
        dotContainer.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleNewsTap))
        dotContainer.addGestureRecognizer(tap)

        newsDot = dot
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = contentView.bounds
    }

    // ❌ DO NOT REMOVE SUBVIEWS HERE
    override func prepareForReuse() {
        super.prepareForReuse()

        for label in labels {
            label.text = nil
            label.backgroundColor = .clear
        }

        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = nil

        newsDot?.backgroundColor = .gray
    }
    
    @objc private func handleNewsTap() {
        guard let item = currentItem else { return }
        delegate?.didTapNews(for: item)
    }

    func configure(with item: ScannerItem) {
        self.currentItem = item

        let values: [String] = [
            String(format: "%+.1f%%", item.pctUp),
            item.symbol,
            String(format: "%.2f", item.lastPrice),
            String(format: "%.2f", item.high),
            String(format: "%.2f", item.low),
            formatVolume(item.volume),
            item.floatShares != nil ? formatVolume(item.floatShares!) : "-",
            item.rvo != nil ? String(format: "%.2f", item.rvo!) : "-"
        ]

        for i in 0..<labels.count {
            let label = labels[i]
            label.text = values[i]

            // 🔥 MULTI HIGHLIGHT SUPPORT
//            if shouldHighlight(index: i, item: item) {
//                if let color = highlightColor(for: i, item: item) {
//                    label.backgroundColor = color
//                } else {
//                    label.backgroundColor = .clear
//                }
//            } else {
//                label.backgroundColor = .clear
//            }
            
            let isFullHighlight = isFullRowHighlight(item)

            // 🔥 FULL ROW BORDER CASE
            if isFullHighlight {

                contentView.layer.borderWidth = 1.5
                contentView.layer.borderColor = UIColor.green.cgColor
                contentView.layer.cornerRadius = 6
                contentView.layer.masksToBounds = true

                // remove individual highlights
                for label in labels {
                    label.backgroundColor = .clear
                }

            } else {

                contentView.layer.borderWidth = 0

                for i in 0..<labels.count {
                    let label = labels[i]

                    if let color = highlightColor(for: i, item: item) {
                        label.backgroundColor = color.withAlphaComponent(1.0)
                    } else {
                        label.backgroundColor = .clear
                    }
                }
            }
        }

        // News dot update
        newsDot?.backgroundColor = item.hasNews ? .systemGreen : .gray
    }
}

private extension ScannerRowCell {

    func makeLabel(width: CGFloat) -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)

        label.layer.borderWidth = 0.3
        label.layer.borderColor = UIColor.darkGray.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: width).isActive = true

        return label
    }

    func shouldHighlight(index: Int, item: ScannerItem) -> Bool {

        let h = item.highlights

        return
            (h.contains(.pctSurge) && index == 0) ||
            (h.contains(.rankSurge) && index == 1) ||
            (h.contains(.hod) && (index == 2 || index == 3))
    }
    
    func highlightColor(for index: Int, item: ScannerItem) -> UIColor? {

        let h = item.highlights

        if h.contains(.pctSurge) && index == 0 {
            return UIColor(hex: "EB2A7C")
        }

        if h.contains(.rankSurge) && index == 1 {
            return UIColor(hex: "F7921E")
        }

        if h.contains(.hod) && (index == 2 || index == 3) {
            return UIColor(hex: "6A5ACD")
        }

        return nil
    }

    func formatVolume(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value)/1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value)/1_000)
        }
        return "\(value)"
    }
    
    private func isFullRowHighlight(_ item: ScannerItem) -> Bool {
        let h = item.highlights
        return h.contains(.pctSurge) &&
               h.contains(.rankSurge) &&
               h.contains(.hod)
    }
}

protocol ScannerRowCellDelegate: AnyObject {
    func didTapNews(for item: ScannerItem)
}
