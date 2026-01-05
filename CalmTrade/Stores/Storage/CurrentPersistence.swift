//
//  CurrentPersistence.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/11/25.
//


import Combine
import CoreData

final class CurrentPersistence {
    static let shared = CurrentPersistence()
    private var cancellable: AnyCancellable?

    @Published private(set) var container: NSPersistentContainer =
        PersistenceFactory.container(for: SessionManager.shared.current?.id)

    private init() {
        cancellable = SessionManager.shared.$current.sink { [weak self] account in
            self?.container = PersistenceFactory.container(for: account?.id)
            NotificationCenter.default.post(name: .userAccountDidChange, object: account)
        }
    }
}
