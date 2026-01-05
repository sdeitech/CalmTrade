//
//  CoreDataStack.swift
//  CalmTrade
//
//  Created by Anas Parekh on 09/09/25.
//

import CoreData
import Foundation

final class CoreDataStack {

    // MARK: - Singleton
    static let shared = CoreDataStack()
    private(set) var container: NSPersistentContainer
    private let switchQueue = DispatchQueue(label: "com.calmtrade.coredatastore.switch")

    // MARK: - Init
    private init() {
        // Create initial container for current user (if logged in)
        let userId = SessionManager.shared.current?.id
        container = CoreDataStack.makeContainer(for: userId)

        // Observe user changes to dynamically swap containers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onUserChanged(_:)),
            name: .userAccountDidChange,
            object: nil
        )
    }

    // MARK: - Per-user container factory
    private static func makeContainer(for userId: String?) -> NSPersistentContainer {
        let name = "CalmTrade"
        let id = userId ?? "_anonymous"

        // Create per-user directory in Application Support
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let userDir = baseURL.appendingPathComponent("Users/\(id)/CoreData", isDirectory: true)
        try? FileManager.default.createDirectory(at: userDir, withIntermediateDirectories: true)

        let storeURL = userDir.appendingPathComponent("\(name).sqlite")

        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.shouldMigrateStoreAutomatically = true
        desc.shouldInferMappingModelAutomatically = true

        let container = NSPersistentContainer(name: name)
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, err in
            if let err = err {
                NSLog("[CoreDataStack] Load error for user=\(id): \(err)")
            } else {
                NSLog("[CoreDataStack] Store ready: \(storeURL.lastPathComponent)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }

    // MARK: - Context accessors
    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    // MARK: - Handle user switch
    @objc private func onUserChanged(_ note: Notification) {
        let userId = (note.object as? User)?.id
        NSLog("[CoreDataStack] Switching CoreData store → userId=\(userId ?? "_anonymous")")
        
        // 🔐 Block all readers and wait for them to drain
        UserStoreSwitchCoordinator.shared.beginSwitch()
        defer { UserStoreSwitchCoordinator.shared.endSwitch() }
        
        // Drain background work on old container if needed
        container.performBackgroundTask { ctx in
            ctx.performAndWait {
                // drain any work
            }
        }
        
        let oldContainer = container
        let newContainer = CoreDataStack.makeContainer(for: userId)
        container = newContainer
        
        // Tear down old viewContext
        oldContainer.viewContext.reset()
    }
}
