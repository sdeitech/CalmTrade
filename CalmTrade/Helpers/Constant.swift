//
//  Constant.swift
//  iOSArchitecture
//
//  Created by Amit Shukla on 05/07/18.
//  Copyright © 2018 smartData. All rights reserved.
//

import Foundation
import UIKit


public struct AppColor {
    
    public static let backgroundColor       =     UIColor(named: "backgroundColor")
    public static let cellBackgroundColor   =     UIColor.init("#3B3B4B")
    public static let yellowColor           =     UIColor.init("#FCDA6A")
    public static let whiteColor            =     UIColor.init("#FFFFFF")
    public static let blackColor            =     UIColor.init("#1F1F27")
    public static let grayColor             =     UIColor.init("#424242")
    
}

public struct AlertMessage {
    static let INVALID_URL       = "Invalid server url"
    static let LOST_INTERNET     = "It seems you are offline, Please check your Internet connection."
    static let INVALID_EMAIL     = "Please enter a valid email address"
    static let INVALID_PASSWORD  = "Please enter a minimum 6 character password"
 
}

public struct Constants {
    struct String {
        static let AppName  = "CalmTrade"
        static let Yes = "Yes"
        static let No = "No"
        static let Ok = "Ok"
        static let Cancel = "Cancel"
        static let Confirm = "Confirm"
        static let Enable = "Enable"
        static let Purchase = "Purchase"
        
        static let WantToLogout = "Are you sure want to logout?"
        static let EnterEmail = "Please enter email"
        static let EnterValidEmail = "Please enter valid email"
    }
    
    enum AlertButtonType {
            case OnlyOk
            case OkCancel
            case YesNo
            case ConfirmCancel
            case EnableCancel
            case CancelPurchase
        }
}
