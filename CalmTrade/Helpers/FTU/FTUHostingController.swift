//
//  FTUHostingController.swift
//  CalmTrade
//
//  Created by Anas Parekh on 18/12/25.
//


import SwiftUI
import PolarBleSdk

final class FTUHostingController: UIHostingController<FTUSetupView> {

    init(onSubmit: @escaping (PolarFirstTimeUseConfig) -> Void) {
        let view = FTUSetupView(onSubmit: onSubmit)
        super.init(rootView: view)
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

