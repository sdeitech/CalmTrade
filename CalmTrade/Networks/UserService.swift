//
//  LoginAPIManager.swift
//  iOSArchitecture
//
//  Created by Amit on 23/02/18.
//  Copyright © 2018 smartData. All rights reserved.
//

import Foundation
import UIKit

protocol UserServiceProtocol {
    func doLogin(email: String, password:String, completion:@escaping (Result<Any>) -> Void)
}

//public class UserService: APIService, UserServiceProtocol {
//    
//    func doLogin(email: String, password:String, completion:@escaping (Result<Any>) -> Void) {
//        
//        let param = [Keys.email:email, Keys.password : password]
//        
//        super.startService(with: .POST, path: Config.login, parameters: param, files: [], modelType: User.self) { (result) in
//            DispatchQueue.main.async {
//                switch result {
//                case .Success(let data):
//                    // Parse Here
//                    completion(.Success(data))
//                case .Error(let message):
//                    completion(.Error(message))
//                }
//            }
//        }
//    }
//}

