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
    private var currentUserId: String?

    @Published private(set) var container: NSPersistentContainer =
        PersistenceFactory.container(for: SessionManager.shared.current?.id)

    private init() {
        currentUserId = SessionManager.shared.current?.id
        cancellable = SessionManager.shared.$current.sink { [weak self] account in
            guard let self else { return }
            let nextUserId = account?.id
            guard self.currentUserId != nextUserId else { return }

            self.currentUserId = nextUserId
            self.container = PersistenceFactory.container(for: nextUserId)
        }
    }
}
