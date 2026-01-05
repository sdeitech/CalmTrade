//
//  UserStoreSwitchCoordinator.swift
//  CalmTrade
//
//  Created by Anas Parekh on 27/11/25.
//


import Foundation

/// Global barrier for coordinating Core Data access vs. user-store switching.
final class UserStoreSwitchCoordinator {

    static let shared = UserStoreSwitchCoordinator()

    private let condition = NSCondition()
    private var activeReaders = 0
    private var switching = false

    private init() {}

    // MARK: - Reader side (repositories, VMs etc.)

    func beginRead() {
        condition.lock()
        // If a switch is in progress, wait until it finishes
        while switching {
            condition.wait()
        }
        activeReaders += 1
        condition.unlock()
    }

    func endRead() {
        condition.lock()
        activeReaders -= 1
        if activeReaders == 0 {
            // Wake any switch waiting for readers to drain
            condition.signal()
        }
        condition.unlock()
    }

    @discardableResult
    func withRead<R>(_ block: () throws -> R) rethrows -> R {
        beginRead()
        defer { endRead() }
        return try block()
    }

    // MARK: - Switch side (userAccountDidChange handlers)

    /// Called by stacks when a user switch begins.
    /// Blocks new readers and waits for in-flight readers to finish.
    func beginSwitch() {
        condition.lock()
        // Block new readers
        switching = true
        // Wait until existing readers drain
        while activeReaders > 0 {
            condition.wait()
        }
        condition.unlock()
    }

    /// Called after containers are swapped.
    func endSwitch() {
        condition.lock()
        switching = false
        // Let queued readers resume
        condition.broadcast()
        condition.unlock()
    }
}
