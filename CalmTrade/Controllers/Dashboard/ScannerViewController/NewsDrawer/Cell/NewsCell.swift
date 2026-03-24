//
//  NewsCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 19/03/26.
//

import UIKit

final class NewsCell: UITableViewCell {

    static let id = "NewsCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)

        subtitleLabel.textColor = .lightGray
        subtitleLabel.font = .systemFont(ofSize: 12)

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 2

        let container = UIStackView(arrangedSubviews: [iconView, stack])
        container.axis = .horizontal
        container.spacing = 12
        container.alignment = .center

        contentView.addSubview(container)

        container.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure(_ item: NewsItem) {
        iconView.image = item.icon
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
    }
}
