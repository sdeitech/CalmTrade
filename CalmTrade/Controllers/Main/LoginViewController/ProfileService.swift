//
//  ProfileService.swift
//  CalmTrade
//
//  Created by Anas Parekh on 19/12/25.
//

import Foundation

final class ProfileService {

    private let repo: UserRepositoryProtocol

    init(repo: UserRepositoryProtocol = UserRepository()) {
        self.repo = repo
    }

    /// Fetch profile and update global session user (single source of truth)
    func refreshProfile(accessToken: String,
                        completion: ((User?, String?) -> Void)? = nil) {

        repo.fetchProfile(accessToken: accessToken) { result in
            DispatchQueue.main.async {
                switch result {

                case .Success(let env):
                    guard let env,
                          env.success,
                          let dto = env.data else {
                        completion?(nil, env?.message ?? "Profile fetch failed")
                        return
                    }

                    let user = User(from: dto)

                    // 🔥 GLOBAL UPDATE HAPPENS HERE
                    SessionManager.shared.setCurrentUser(
                        user,
                        token: SessionManager.shared.accessToken
                    )

                    completion?(user, nil)

                case .Error(let err):
                    completion?(nil, err)
                }
            }
        }
    }
}

