//
//  PersistenceFactory.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/11/25.
//


import CoreData

enum PersistenceFactory {
    static func container(for userId: String?) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "CalmTrade") // your model name
        let storeFilename = (userId ?? "_anonymous") + ".sqlite"
        let storeURL = UserScope.appSupportURL.appendingPathComponent("CoreData/\(storeFilename)")
        let desc = NSPersistentStoreDescription(url: storeURL)
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error = error { assertionFailure("Core Data load error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }
}
