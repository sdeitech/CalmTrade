//
//  NewsDrawerViewController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/03/26.
//


import UIKit

struct NewsItem {
    let title: String
    let subtitle: String
    let icon: UIImage?
    let action: (() -> Void)?
}

final class NewsDrawerViewController: UIViewController {

    // MARK: - Public
    var symbol: String = ""
    var hasNews: Bool = false

    // MARK: - UI
    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    private var items: [NewsItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        buildData()
    }
}

private extension NewsDrawerViewController {

    func setupUI() {
        view.backgroundColor = UIColor(white: 0.1, alpha: 1)

        // Title
        titleLabel.text = "\(symbol) News"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        // Table
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(NewsCell.self, forCellReuseIdentifier: NewsCell.id)

        view.addSubview(titleLabel)
        view.addSubview(tableView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

private extension NewsDrawerViewController {

    func buildData() {

        items.removeAll()

        if hasNews {
            // 👉 LIVE NEWS (mock for now)
            items.append(
                NewsItem(
                    title: "Domo Inc. Report Q4 2026 Earnings, Beats Revenue Expectations",
                    subtitle: "Benzinga • 7m ago",
                    icon: UIImage(systemName: "newspaper"),
                    action: { [weak self] in
                        self?.openURL("https://www.benzinga.com")
                    }
                )
            )
        }

        // 👉 COMMON SOURCES (always visible)
        items.append(contentsOf: [

            NewsItem(
                title: "Yahoo Finance News",
                subtitle: "Latest Headlines From Yahoo Finance",
                icon: UIImage(named: "yahoo") ?? UIImage(systemName: "y.circle"),
                action: { [weak self] in
                    self?.openURL("https://finance.yahoo.com/quote/\(self?.symbol ?? "")")
                }
            ),

            NewsItem(
                title: "Google News Search",
                subtitle: "Search Google News For \(symbol)",
                icon: UIImage(named: "google") ?? UIImage(systemName: "globe"),
                action: { [weak self] in
                    self?.openURL("https://www.google.com/search?q=\(self?.symbol ?? "")+stock")
                }
            ),

            NewsItem(
                title: "Benzinga News Feed",
                subtitle: "Latest Headlines From Benzinga",
                icon: UIImage(named: "benzinga") ?? UIImage(systemName: "bolt.fill"),
                action: { [weak self] in
                    self?.openURL("https://www.benzinga.com")
                }
            ),

            NewsItem(
                title: "SEC Filings & Reports",
                subtitle: "View Recent SEC Filing For \(symbol)",
                icon: UIImage(systemName: "doc.text"),
                action: { [weak self] in
                    self?.openURL("https://www.sec.gov/edgar/search/?q=\(self?.symbol ?? "")")
                }
            )
        ])

        tableView.reloadData()
    }
}
extension NewsDrawerViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(
            withIdentifier: NewsCell.id,
            for: indexPath
        ) as! NewsCell

        cell.configure(items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        items[indexPath.row].action?()
    }
}

private extension NewsDrawerViewController {

    func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}
