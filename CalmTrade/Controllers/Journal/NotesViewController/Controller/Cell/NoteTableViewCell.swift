//
//  NoteTableViewCell.swift
//  CalmTrade
//
//  Created by Anas Parekh on 13/01/26.
//


import UIKit

final class NoteTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    static let identifier = "NoteTableViewCell"

    func configure(with note: Note) {
        titleLabel.text = note.noteType
        descriptionLabel.text = note.content
        timeLabel.text = TimelineDateFormatter.time(from: note.timestamp)
    }
}

extension String {

    func toTimeString() -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso.date(from: self) {
            return date.format("HH:mm:ss")
        }

        // Fallback without fractional seconds
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: self) {
            return date.format("HH:mm:ss")
        }

        return ""
    }
}

extension Date {
    func format(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

