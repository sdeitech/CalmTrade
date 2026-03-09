//
//  NightlyRechargeViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/03/26.
//


import Foundation

struct NightlyRechargeUIModel {

    let status: String

    let ansTitle: String
    let ansDeviation: Double

    let sleepTitle: String
    let sleepScore: Int
    let usualSleep: Int
}

final class NightlyRechargeViewModel {

    var onDataLoaded: ((NightlyRechargeUIModel) -> Void)?

    func loadData() {

        // Dummy values for now
        let model = NightlyRechargeUIModel(
            status: "Very Good",
            ansTitle: "Above usual",
            ansDeviation: 4.7,
            sleepTitle: "Much above usual",
            sleepScore: 88,
            usualSleep: 76
        )

        onDataLoaded?(model)
    }
}
