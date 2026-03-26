//
//  ScannerHeaderView.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import UIKit

final class ScannerHeaderView: UIView {

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.distribution = .fill

        scrollView.addSubview(stack)

        let titles = ["% Change", "Symbol", "Price", "High", "Low", "Volume"]

        for title in titles {
            let label = UILabel()
            label.text = title
            label.textColor = .lightGray
            label.textAlignment = .center
            label.font = .boldSystemFont(ofSize: 13)
            label.frame.size.width = 120
            stack.addArrangedSubview(label)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.frame = bounds
        stack.frame = CGRect(x: 0, y: 0, width: 900, height: bounds.height)
        scrollView.contentSize = stack.frame.size
    }
}