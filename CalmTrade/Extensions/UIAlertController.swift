//
//  UIAlertController.swift
//
//  Created by Surjeet Singh
//  Copyright © 2018 Surjeet. All rights reserved.
//

import Foundation
import UIKit

enum AlertAction:String {
    case Ok
    case Cancel
    case Delete
    case Yes
    case No
    case Setting
    
    var title:String {
        switch self {
        case .Setting:
            return "Settings"
        default:
            return self.rawValue
        }
    }
    
    var style:UIAlertAction.Style {
        switch self {
        case .Cancel:
            return .cancel
        case .Delete:
            return .destructive
        default:
            return .default
        }
    }
}

enum AlertInputType:Int {
    case normal
    case email
    case password
}

typealias AlertHandler = (_ action:AlertAction) -> Void

extension UIAlertController {
    
    class func showAlert( title: String?, message: String?) {
        self.showAlert(title: title, message: message, preferredStyle: .alert, sender: nil, target: UIApplication.topViewController(), actions: .Ok, handler: nil)
    }
    
    class func showAlert(title:String?, message:String?, preferredStyle:UIAlertController.Style, sender: AnyObject?, target:UIViewController?, actions:AlertAction..., handler:AlertHandler?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        alertController.view.tintColor = UIColor.darkGray
        for arg in actions {
            let action = UIAlertAction(title: arg.title, style: arg.style, handler: { (action) in
                handler?(arg)
            })
            alertController.addAction(action)
        }
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = target?.view;
            presenter.permittedArrowDirections = .any
            presenter.sourceRect = sender?.bounds ?? .zero
        }
        target?.present(alertController, animated: true, completion: nil)
    }
    
    class func showInputAlert(title:String?, message:String?, inputPlaceholders:[String]?, preferredStyle:UIAlertController.Style, sender: AnyObject?, target:UIViewController?, actions:AlertAction..., handler:AlertHandler?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: preferredStyle)
        alertController.view.tintColor = UIColor.darkGray
        for placeholder in inputPlaceholders ?? [] {
            alertController.addTextField(configurationHandler: { (txtField) in
                txtField.placeholder = placeholder
            })
        }
        for arg in actions {
            let action = UIAlertAction(title: arg.title, style: arg.style, handler: { (action) in
                handler?(arg)
            })
            alertController.addAction(action)
        }
        if let presenter = alertController.popoverPresentationController {
            presenter.sourceView = target?.view
            presenter.permittedArrowDirections = .any
            presenter.sourceRect =  sender?.bounds ?? .zero
        }
        target?.present(alertController, animated: true, completion: nil)
    }
    
}


