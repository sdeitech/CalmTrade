
import Foundation
import UIKit

public func Log<T>(_ object: T?, filename: String = #file, line: Int = #line, funcname: String = #function) {
    #if DEBUG
        guard let object = object else { return }
        print("***** \(Date()) \(filename.components(separatedBy: "/").last ?? "") (line: \(line)) :: \(funcname) :: \(object)")
    #endif
}


extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
    
    class var className: String {
        return String(describing: self)
    }
}

extension UIViewController {
    public func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
}

// MARK: - Array average helper

extension Array where Element: BinaryFloatingPoint {
    /// Returns the arithmetic mean of all elements, or nil if the array is empty.
    func average() -> Element? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Element(count)
    }
}

extension Array where Element: BinaryInteger {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        let total = reduce(0, +)
        return Double(total) / Double(count)
    }
}
