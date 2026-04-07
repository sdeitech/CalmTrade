//
//  UserStoreSwitchCoordinator.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/11/25.
//


import Foundation

/// Lightweight coordinator for user-store switching.
/// We intentionally do not block readers during a switch because the previous
/// `NSCondition`-based barrier could deadlock on the main thread during login.
/// Existing contexts remain valid against the old persistent store coordinator,
/// and new reads will pick up the new container after the swap.
final class UserStoreSwitchCoordinator {

    static let shared = UserStoreSwitchCoordinator()

    private init() {}

    // MARK: - Reader side (repositories, VMs etc.)

    func beginRead() {}

    func endRead() {}

    @discardableResult
    func withRead<R>(_ block: () throws -> R) rethrows -> R {
        return try block()
    }

    // MARK: - Switch side (userAccountDidChange handlers)

    func beginSwitch() {}

    func endSwitch() {}
}
