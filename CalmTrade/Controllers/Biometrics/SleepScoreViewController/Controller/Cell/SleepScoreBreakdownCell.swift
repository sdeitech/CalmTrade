//
//  SleepScoreBreakdownCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 04/03/26.
//


import UIKit

final class SleepScoreBreakdownCell: UICollectionViewCell {
    
    static let identifier = "SleepScoreBreakdownCell"
    
    private let contentStack = UIStackView()
    private let scoreCard = UIView()
    private let scoreContainerView = UIView()
    
    private let amountCard = SleepScoreMetricCardView()
    private let solidityCard = SleepScoreMetricCardView()
    private let regenerationCard = SleepScoreMetricCardView()
    private let insightCard = SleepScoreInsightCardView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        insightCard.configure(text: nil)
    }
    
    private func setup() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        scoreCard.translatesAutoresizingMaskIntoConstraints = false
        scoreCard.backgroundColor = .clear
        
        scoreContainerView.translatesAutoresizingMaskIntoConstraints = false
        scoreContainerView.backgroundColor = .clear
        
        contentView.addSubview(contentStack)
        contentStack.addArrangedSubview(scoreCard)
        contentStack.addArrangedSubview(amountCard)
        contentStack.addArrangedSubview(solidityCard)
        contentStack.addArrangedSubview(regenerationCard)
        contentStack.addArrangedSubview(insightCard)
        
        scoreCard.addSubview(scoreContainerView)
        
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            scoreCard.heightAnchor.constraint(equalToConstant: 190),
            
            scoreContainerView.centerXAnchor.constraint(equalTo: scoreCard.centerXAnchor),
            scoreContainerView.centerYAnchor.constraint(equalTo: scoreCard.centerYAnchor),
            scoreContainerView.widthAnchor.constraint(equalToConstant: 168),
            scoreContainerView.heightAnchor.constraint(equalTo: scoreContainerView.widthAnchor),
            
            amountCard.heightAnchor.constraint(equalToConstant: 102),
            solidityCard.heightAnchor.constraint(equalToConstant: 138),
            regenerationCard.heightAnchor.constraint(equalToConstant: 110),
            insightCard.heightAnchor.constraint(equalToConstant: 96)
        ])
    }
    
    func configure(model: SleepScoreDayModel) {
        SleepScoreViewModel.makeSleepScoreRing(
            in: scoreContainerView,
            score: model.score,
            segmentProgresses: [model.amount, model.solidity, model.regeneration],
            centerFontSize: 30
        )
        
        amountCard.configure(
            icon: UIImage(systemName: "bed.double.fill"),
            iconTintColor: UIColor("39D2DB"),
            iconBackgroundColor: UIColor("39D2DB").withAlphaComponent(0.16),
            title: "Sleep Amount",
            scoreText: "\(model.amountScore)/40",
            subtitle: formatMinutes(model.sleepTimeMinutes),
            rows: [
                .init(
                    title: "Sleep Time",
                    detail: formatMinutes(model.sleepTimeMinutes),
                    valueText: "\(model.amountScore)",
                    progress: model.amount,
                    gradientColors: [UIColor("173638").withAlphaComponent(0.12), UIColor("36DDE4")],
                    barStyle: .compactTrailingWide
                )
            ]
        )
        
        solidityCard.configure(
            icon: UIImage(systemName: "line.3.horizontal.decrease.circle.fill"),
            iconTintColor: UIColor("F29A3B"),
            iconBackgroundColor: UIColor("F29A3B").withAlphaComponent(0.16),
            title: "Sleep Solidity",
            scoreText: "\(model.solidityScore)/30",
            subtitle: nil,
            rows: [
                .init(
                    title: "Long interruptions",
                    detail: nil,
                    valueText: "\(model.interruptionsScore)",
                    progress: progress(for: model.interruptionsScore, max: 10),
                    gradientColors: [UIColor("2A2421").withAlphaComponent(0.12), UIColor("F29A3B")],
                    barStyle: .compactTrailing
                ),
                .init(
                    title: "Continuity",
                    detail: nil,
                    valueText: "\(model.continuityScore)",
                    progress: progress(for: model.continuityScore, max: 10),
                    gradientColors: [UIColor("2A2421").withAlphaComponent(0.12), UIColor("F29A3B")],
                    barStyle: .compactTrailing
                ),
                .init(
                    title: "Actual sleep",
                    detail: nil,
                    valueText: "\(model.sleepEfficiencyScore)",
                    progress: progress(for: model.sleepEfficiencyScore, max: 10),
                    gradientColors: [UIColor("2A2421").withAlphaComponent(0.12), UIColor("F29A3B")],
                    barStyle: .compactTrailing
                )
            ]
        )
        
        regenerationCard.configure(
            icon: UIImage(systemName: "arrow.triangle.2.circlepath.circle.fill"),
            iconTintColor: UIColor("8B39F7"),
            iconBackgroundColor: UIColor("8B39F7").withAlphaComponent(0.16),
            title: "Sleep Regeneration",
            scoreText: "\(model.regenerationScore)/30",
            subtitle: nil,
            rows: [
                .init(
                    title: "REM Sleep",
                    detail: nil,
                    valueText: "\(model.remScore)",
                    progress: model.rem,
                    gradientColors: [UIColor("26192E").withAlphaComponent(0.12), UIColor("8B39F7")],
                    barStyle: .compactTrailing
                ),
                .init(
                    title: "Deep sleep",
                    detail: nil,
                    valueText: "\(model.deepScore)",
                    progress: model.deep,
                    gradientColors: [UIColor("26192E").withAlphaComponent(0.12), UIColor("AE5BFF")],
                    barStyle: .compactTrailing
                )
            ]
        )
        
        insightCard.configure(text: makeInsightText(from: model))
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return "\(hours)h \(remainder)m"
    }
    
    private func progress(for score: Int, max: Int) -> CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(score) / CGFloat(max)
    }
    
    private func makeInsightText(from model: SleepScoreDayModel) -> String {
        if model.regenerationScore >= 22 && model.remScore >= 10 && model.deepScore >= 10 {
            return "Your REM and deep sleep were in an optimal range, supporting good recovery."
        }
        
        if model.amountScore < 28 {
            return "Your sleep duration was below the target range, so adding more time asleep may improve tomorrow's score."
        }
        
        if model.interruptionsScore <= 6 || model.continuityScore <= 6 {
            return "Sleep fragmentation reduced solidity tonight, so fewer wake periods would likely lift recovery."
        }
        
        if model.remScore < 8 {
            return "REM sleep came in a bit low, which may hold back mental recovery and next-day sharpness."
        }
        
        if model.deepScore < 8 {
            return "Deep sleep was lighter than ideal, which can limit physical recovery even when total sleep looks solid."
        }
        
        return "Your sleep profile was well balanced overall, with solid duration and recovery support across the night."
    }
}

private final class SleepScoreMetricCardView: UIView {
    
    struct Row {
        enum BarStyle {
            case track
            case compactTrailing
            case compactTrailingWide
        }
        
        let title: String
        let detail: String?
        let valueText: String
        let progress: CGFloat
        let gradientColors: [UIColor]
        let barStyle: BarStyle
        
        init(
            title: String,
            detail: String?,
            valueText: String,
            progress: CGFloat,
            gradientColors: [UIColor],
            barStyle: BarStyle = .track
        ) {
            self.title = title
            self.detail = detail
            self.valueText = valueText
            self.progress = progress
            self.gradientColors = gradientColors
            self.barStyle = barStyle
        }
    }
    
    private let headerIconBackground = UIView()
    private let headerIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let scoreLabel = UILabel()
    private let rowsStack = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor("1D1D21")
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.04).cgColor
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 10
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.spacing = 2
        titleStack.alignment = .leading
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        
        headerIconBackground.translatesAutoresizingMaskIntoConstraints = false
        headerIconBackground.layer.cornerRadius = 11
        
        headerIconView.translatesAutoresizingMaskIntoConstraints = false
        headerIconView.contentMode = .scaleAspectFit
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        
        scoreLabel.font = .systemFont(ofSize: 14, weight: .bold)
        scoreLabel.textColor = .white
        scoreLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        rowsStack.axis = .vertical
        rowsStack.spacing = 10
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(headerStack)
        addSubview(rowsStack)
        headerStack.addArrangedSubview(headerIconBackground)
        headerIconBackground.addSubview(headerIconView)
        headerStack.addArrangedSubview(titleStack)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(scoreLabel)
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            
            headerIconBackground.widthAnchor.constraint(equalToConstant: 22),
            headerIconBackground.heightAnchor.constraint(equalToConstant: 22),
            
            headerIconView.centerXAnchor.constraint(equalTo: headerIconBackground.centerXAnchor),
            headerIconView.centerYAnchor.constraint(equalTo: headerIconBackground.centerYAnchor),
            headerIconView.widthAnchor.constraint(equalToConstant: 13),
            headerIconView.heightAnchor.constraint(equalToConstant: 13),
            
            rowsStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 12),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rowsStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
    }
    
    func configure(
        icon: UIImage?,
        iconTintColor: UIColor,
        iconBackgroundColor: UIColor,
        title: String,
        scoreText: String,
        subtitle: String?,
        rows: [Row]
    ) {
        headerIconView.image = icon
        headerIconView.tintColor = iconTintColor
        headerIconBackground.backgroundColor = iconBackgroundColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        scoreLabel.text = scoreText
        
        rowsStack.arrangedSubviews.forEach {
            rowsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        
        rows.forEach { row in
            let rowView = SleepScoreMetricRowView()
            rowView.configure(
                title: row.title,
                detail: row.detail,
                valueText: row.valueText,
                progress: row.progress,
                gradientColors: row.gradientColors,
                barStyle: row.barStyle
            )
            rowsStack.addArrangedSubview(rowView)
        }
    }
}

private final class SleepScoreMetricRowView: UIView {
    
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let barTrack = UIView()
    private let barFill = GradientProgressView()
    private let valueLabel = UILabel()
    private var barTrackWidthConstraint: NSLayoutConstraint?
    private var fillWidthConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        barTrack.layer.cornerRadius = barTrack.bounds.height / 2
        barFill.layer.cornerRadius = barFill.bounds.height / 2
    }
    
    private func setup() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let labelStack = UIStackView()
        labelStack.axis = .horizontal
        labelStack.alignment = .center
        labelStack.spacing = 8
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
        detailLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        barTrack.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        
        barFill.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.font = .systemFont(ofSize: 13, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        
        addSubview(stack)
        stack.addArrangedSubview(labelStack)
        stack.addArrangedSubview(barTrack)
        stack.addArrangedSubview(valueLabel)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(detailLabel)
        barTrack.addSubview(barFill)
        
        barTrackWidthConstraint = barTrack.widthAnchor.constraint(equalToConstant: 140)
        fillWidthConstraint = barFill.widthAnchor.constraint(equalToConstant: 0)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            labelStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 104),
            barTrackWidthConstraint!,
            barTrack.heightAnchor.constraint(equalToConstant: 20),
            
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.trailingAnchor.constraint(equalTo: barTrack.trailingAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
            fillWidthConstraint!
        ])
    }
    
    func configure(
        title: String,
        detail: String?,
        valueText: String,
        progress: CGFloat,
        gradientColors: [UIColor],
        barStyle: SleepScoreMetricCardView.Row.BarStyle
    ) {
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil
        valueLabel.text = valueText
        barFill.colors = gradientColors
        
        let clampedProgress = max(0.08, min(1.0, progress))
        let trackWidth: CGFloat
        let widthMultiplier: CGFloat
        
        switch barStyle {
        case .track:
            trackWidth = 140
            widthMultiplier = clampedProgress
            barTrack.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        case .compactTrailing:
            trackWidth = 118
            widthMultiplier = 0.34 + (0.66 * clampedProgress)
            barTrack.backgroundColor = .clear
        case .compactTrailingWide:
            trackWidth = 128
            widthMultiplier = 0.48 + (0.52 * clampedProgress)
            barTrack.backgroundColor = .clear
        }
        
        barTrackWidthConstraint?.constant = trackWidth
        fillWidthConstraint?.isActive = false
        fillWidthConstraint = barFill.widthAnchor.constraint(equalTo: barTrack.widthAnchor, multiplier: widthMultiplier)
        fillWidthConstraint?.isActive = true
        
        setNeedsLayout()
    }
}

private final class SleepScoreInsightCardView: UIView {
    
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = UIColor("1D1D21")
        layer.cornerRadius = 16
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.04).cgColor
        
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = UIColor("F2C94C").withAlphaComponent(0.18)
        iconBackground.layer.cornerRadius = 10
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "lightbulb.fill")
        iconView.tintColor = UIColor("F2C94C")
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.text = "Insight"
        
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.font = .systemFont(ofSize: 14, weight: .medium)
        bodyLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        bodyLabel.numberOfLines = 0
        
        addSubview(iconBackground)
        iconBackground.addSubview(iconView)
        addSubview(titleLabel)
        addSubview(bodyLabel)
        
        NSLayoutConstraint.activate([
            iconBackground.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            iconBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconBackground.widthAnchor.constraint(equalToConstant: 20),
            iconBackground.heightAnchor.constraint(equalToConstant: 20),
            
            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 11),
            iconView.heightAnchor.constraint(equalToConstant: 11),
            
            titleLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            bodyLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
    }
    
    func configure(text: String?) {
        bodyLabel.text = text
    }
}

private final class GradientProgressView: UIView {
    
    var colors: [UIColor] = [] {
        didSet {
            gradientLayer.colors = colors.map(\.cgColor)
        }
    }
    
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.height / 2
    }
    
    private func setup() {
        layer.addSublayer(gradientLayer)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
    }
}
