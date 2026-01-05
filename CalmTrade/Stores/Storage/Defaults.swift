//
//  Defaults.swift
//  CalmTrade
//
//  Created by Anas Parekh on 06/11/25.
//


// Replaces direct use of UserDefaults.standard
enum Defaults {
    static func get<T>(_ key: String) -> T? { UserScope.defaults.object(forKey: key) as? T }
    static func set(_ value: Any?, for key: String) { UserScope.defaults.set(value, forKey: key) }
    static func remove(_ key: String) { UserScope.defaults.removeObject(forKey: key) }
    static func bool(_ key: String) -> Bool { UserScope.defaults.bool(forKey: key) }
    static func string(_ key: String) -> String? { UserScope.defaults.string(forKey: key) }
    // extend as needed...
}
