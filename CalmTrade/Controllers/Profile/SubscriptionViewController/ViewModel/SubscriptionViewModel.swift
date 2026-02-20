//
//  SubscriptionViewModel.swift
//  CalmTrade
//
//  Created by Anas Parekh on 11/12/25.
//  
//

import Foundation
import Combine
import KRProgressHUD

final class SubscriptionViewModel: ObservableObject {

    // MARK: - Published Outputs
    @Published var plans: [SubscriptionPlan] = []
    @Published var selectedPlanId: String? = nil
    @Published var checkoutURL: String? = nil

    @Published var currentSubscription: SubscriptionRecord? = nil
    @Published var currentFeatures: [SubscriptionFeature] = []

    private let api = APIService()

    // MARK: - API: Fetch Current Subscription
    func fetchCurrentSubscription() {
        KRProgressHUD.show()

        api.startService(
            with: .GET,
            path: "sub/my-subscriptions",
            parameters: nil,
            files: nil,
            modelType: SubscriptionDetailsResponse.self
        ) { result in

            DispatchQueue.main.async {
                KRProgressHUD.dismiss()

                switch result {

                case .Success(let res):
                    guard let sub = res?.data?.first else { return }

                    self.currentSubscription = sub
                    self.currentFeatures = sub.planDetails?.features ?? []

                case .Error(let msg):
                    print("❌ Failed to load current subscription:", msg)
                }
            }
        }
    }

    // MARK: - API: Fetch Available Plans
    func fetchPlans() {
        KRProgressHUD.show()

        api.startService(
            with: .GET,
            path: "sub/plans",
            parameters: nil,
            files: nil,
            modelType: PlanListResponse.self
        ) { result in

            DispatchQueue.main.async {
                KRProgressHUD.dismiss()

                switch result {

                case .Success(let res):
                    self.plans = res?.data ?? []

                case .Error(let msg):
                    print("❌ Failed to load plans:", msg)
                }
            }
        }
    }

    // MARK: - API: Create Checkout Session
    func createCheckoutSession(completion: @escaping (String?) -> Void) {

        guard let pid = selectedPlanId else {
            completion(nil)
            return
        }

        let params: [String: Any] = [
            "planId": pid,
            "successUrl": "https://www.google.com/",
            "cancelUrl": "https://mail.google.com/"
        ]

        KRProgressHUD.show()

        api.startService(
            with: .POST,
            path: "sub/create-checkout-session",
            parameters: params,
            files: nil,
            modelType: SubscriptionCheckoutResponse.self
        ) { result in

            DispatchQueue.main.async {
                KRProgressHUD.dismiss()

                switch result {

                case .Success(let response):
                    completion(response?.data?.url)

                case .Error(let msg):
                    print("❌ Checkout session creation failed:", msg)
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - API: Verify Payment
    func verifyPayment(completion: @escaping (Bool) -> Void) {

        KRProgressHUD.show()

        api.startService(
            with: .POST,
            path: "sub/verify-payment",
            parameters: nil,
            files: nil,
            modelType: GenericResponse.self   // use your standard success model
        ) { result in

            DispatchQueue.main.async {
                KRProgressHUD.dismiss()

                switch result {

                case .Success(let res):
                    completion(res?.success == true)

                case .Error(let msg):
                    print("❌ Payment verification failed:", msg)
                    completion(false)
                }
            }
        }
    }
}
